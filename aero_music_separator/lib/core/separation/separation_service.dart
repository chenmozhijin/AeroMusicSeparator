import 'dart:async';

import '../ffi/ams_native.dart';
import 'separation_models.dart';

class SeparationTaskController {
  SeparationTaskController({AmsSeparationNativeApi? native}) : _native = native;

  AmsSeparationNativeApi? _native;
  final StreamController<SeparationProgress> _progressController =
      StreamController<SeparationProgress>.broadcast();

  Timer? _pollTimer;
  Completer<SeparationResult>? _resultCompleter;
  int? _engineHandle;
  int? _jobHandle;

  Stream<SeparationProgress> get progress => _progressController.stream;

  bool get isRunning =>
      _resultCompleter != null && !_resultCompleter!.isCompleted;

  AmsSeparationNativeApi get _ffi => _native ??= AmsNative.instance;

  Future<SeparationResult> start(SeparationRequest request) async {
    if (isRunning) {
      throw StateError('A separation task is already running');
    }

    final completer = Completer<SeparationResult>();
    _resultCompleter = completer;

    try {
      _engineHandle = _ffi.openEngine(request.modelPath, request.backend);

      final defaults = _ffi.getDefaults(_engineHandle!);
      final actualRequest = SeparationRequest(
        modelPath: request.modelPath,
        inputPath: request.inputPath,
        preparedInputPath: request.preparedInputPath,
        outputDir: request.outputDir,
        outputPrefix: request.outputPrefix,
        outputFormat: request.outputFormat,
        chunkSize: request.chunkSize > 0
            ? request.chunkSize
            : defaults.chunkSize,
        overlap: request.overlap > 0 ? request.overlap : defaults.overlap,
        backend: request.backend,
      );

      _jobHandle = _ffi.startJob(_engineHandle!, actualRequest);

      _publishProgress(
        SeparationProgress(
          state: SeparationJobState.running,
          stage: SeparationStage.decode,
          progress: 0.0,
          message: 'Task started',
        ),
      );

      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _pollTick(),
      );
      return completer.future;
    } catch (_) {
      _cleanupAfterJob();
      rethrow;
    }
  }

  void cancel() {
    final jobHandle = _jobHandle;
    if (jobHandle == null) {
      return;
    }
    try {
      _ffi.cancelJob(jobHandle);
    } on NativeFfiException catch (e) {
      if (e.code == AmsNativeStatus.cancelled ||
          e.code == AmsNativeStatus.notFound) {
        return;
      }
      rethrow;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final jobHandle = _jobHandle;
    _jobHandle = null;
    if (jobHandle != null) {
      try {
        _ffi.destroyJob(jobHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    final engineHandle = _engineHandle;
    _engineHandle = null;
    if (engineHandle != null) {
      try {
        _ffi.closeEngine(engineHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    _progressController.close();
    _resultCompleter = null;
  }

  void _pollTick() {
    final completer = _resultCompleter;
    final jobHandle = _jobHandle;
    if (completer == null || completer.isCompleted || jobHandle == null) {
      return;
    }

    try {
      final snapshot = _ffi.pollJob(jobHandle);
      _publishProgress(
        SeparationProgress(
          state: snapshot.state,
          stage: snapshot.stage,
          progress: snapshot.progress,
          message: _messageFor(snapshot.state, snapshot.stage),
        ),
      );

      if (snapshot.state == SeparationJobState.succeeded) {
        final result = _ffi.resultForJob(jobHandle);
        completer.complete(result);
        _cleanupAfterJob();
        return;
      }

      if (snapshot.state == SeparationJobState.failed) {
        try {
          _ffi.resultForJob(jobHandle);
          completer.completeError(StateError('Native separation failed'));
        } catch (e) {
          completer.completeError(e);
        }
        _cleanupAfterJob();
        return;
      }

      if (snapshot.state == SeparationJobState.cancelled) {
        completer.completeError(
          NativeCancelledException('Native separation cancelled'),
        );
        _cleanupAfterJob();
        return;
      }
    } catch (e) {
      completer.completeError(e);
      _cleanupAfterJob();
    }
  }

  void _cleanupAfterJob() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final jobHandle = _jobHandle;
    _jobHandle = null;
    if (jobHandle != null) {
      try {
        _ffi.destroyJob(jobHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    final engineHandle = _engineHandle;
    _engineHandle = null;
    if (engineHandle != null) {
      try {
        _ffi.closeEngine(engineHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    _resultCompleter = null;
  }

  void _publishProgress(SeparationProgress progressEvent) {
    if (!_progressController.isClosed) {
      _progressController.add(progressEvent);
    }
  }

  String _messageFor(SeparationJobState state, SeparationStage stage) {
    if (state == SeparationJobState.cancelled) {
      return 'Cancelled';
    }
    if (state == SeparationJobState.failed) {
      return 'Failed';
    }
    if (state == SeparationJobState.succeeded) {
      return 'Completed';
    }

    switch (stage) {
      case SeparationStage.decode:
        return 'Decoding and resampling audio';
      case SeparationStage.infer:
        return 'Running model inference';
      case SeparationStage.encode:
        return 'Encoding output stems';
      case SeparationStage.done:
        return 'Done';
      case SeparationStage.idle:
        return 'Preparing';
    }
  }
}
