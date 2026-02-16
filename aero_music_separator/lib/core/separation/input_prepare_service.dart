import 'dart:async';

import '../audio/preview_models.dart';
import '../ffi/ams_native.dart';

class InputPrepareRequest {
  InputPrepareRequest({
    required this.inputPath,
    required this.workDir,
    this.outputPrefix = 'input',
  });

  final String inputPath;
  final String workDir;
  final String outputPrefix;
}

class InputPrepareService {
  InputPrepareService({AmsPrepareNativeApi? native}) : _native = native;

  AmsPrepareNativeApi? _native;
  final StreamController<InputPrepareProgress> _progressController =
      StreamController<InputPrepareProgress>.broadcast();

  Timer? _pollTimer;
  Completer<InputPreviewInfo>? _resultCompleter;
  int? _prepareHandle;

  Stream<InputPrepareProgress> get progress => _progressController.stream;

  bool get isRunning =>
      _resultCompleter != null && !_resultCompleter!.isCompleted;

  AmsPrepareNativeApi get _ffi => _native ??= AmsNative.instance;

  Future<InputPreviewInfo> start(InputPrepareRequest request) async {
    if (isRunning) {
      throw StateError('An input prepare task is already running');
    }

    final completer = Completer<InputPreviewInfo>();
    _resultCompleter = completer;

    try {
      _prepareHandle = _ffi.startPrepare(
        engineHandle: 0,
        inputPath: request.inputPath,
        workDir: request.workDir,
        outputPrefix: request.outputPrefix,
      );

      _publishProgress(
        InputPrepareProgress(
          state: InputPrepareTaskState.running,
          stage: InputPrepareStage.decode,
          progress: 0.0,
          message: 'Loading input audio',
        ),
      );

      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _pollTick(),
      );
      return completer.future;
    } catch (_) {
      _cleanupAfterPrepare();
      rethrow;
    }
  }

  void cancel() {
    final prepareHandle = _prepareHandle;
    if (prepareHandle == null) {
      return;
    }
    try {
      _ffi.cancelPrepare(prepareHandle);
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

    final prepareHandle = _prepareHandle;
    _prepareHandle = null;
    if (prepareHandle != null) {
      try {
        _ffi.destroyPrepare(prepareHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    _progressController.close();
    _resultCompleter = null;
  }

  void _pollTick() {
    final completer = _resultCompleter;
    final prepareHandle = _prepareHandle;
    if (completer == null || completer.isCompleted || prepareHandle == null) {
      return;
    }

    try {
      final snapshot = _ffi.pollPrepare(prepareHandle);
      _publishProgress(
        InputPrepareProgress(
          state: snapshot.state,
          stage: snapshot.stage,
          progress: snapshot.progress,
          message: _messageFor(snapshot.state, snapshot.stage),
        ),
      );

      if (snapshot.state == InputPrepareTaskState.succeeded) {
        final result = _ffi.resultForPrepare(prepareHandle);
        completer.complete(result);
        _cleanupAfterPrepare();
        return;
      }

      if (snapshot.state == InputPrepareTaskState.failed) {
        try {
          _ffi.resultForPrepare(prepareHandle);
          completer.completeError(StateError('Native prepare failed'));
        } catch (e) {
          completer.completeError(e);
        }
        _cleanupAfterPrepare();
        return;
      }

      if (snapshot.state == InputPrepareTaskState.cancelled) {
        completer.completeError(
          NativeCancelledException('Native prepare cancelled'),
        );
        _cleanupAfterPrepare();
        return;
      }
    } catch (e) {
      completer.completeError(e);
      _cleanupAfterPrepare();
    }
  }

  void _cleanupAfterPrepare() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final prepareHandle = _prepareHandle;
    _prepareHandle = null;
    if (prepareHandle != null) {
      try {
        _ffi.destroyPrepare(prepareHandle);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    _resultCompleter = null;
  }

  void _publishProgress(InputPrepareProgress progressEvent) {
    if (!_progressController.isClosed) {
      _progressController.add(progressEvent);
    }
  }

  String _messageFor(InputPrepareTaskState state, InputPrepareStage stage) {
    if (state == InputPrepareTaskState.cancelled) {
      return 'Cancelled';
    }
    if (state == InputPrepareTaskState.failed) {
      return 'Failed';
    }
    if (state == InputPrepareTaskState.succeeded) {
      return 'Ready for preview';
    }

    switch (stage) {
      case InputPrepareStage.decode:
        return 'Decoding input audio';
      case InputPrepareStage.resample:
        return 'Normalizing sample rate and channels';
      case InputPrepareStage.writeCanonical:
        return 'Writing canonical preview file';
      case InputPrepareStage.done:
        return 'Done';
      case InputPrepareStage.idle:
        return 'Preparing';
    }
  }
}
