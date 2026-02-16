import 'dart:collection';

import 'package:aero_music_separator/core/ffi/ams_native.dart';
import 'package:aero_music_separator/core/separation/separation_models.dart';
import 'package:aero_music_separator/core/separation/separation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cancelled state completes with NativeCancelledException without reading result',
    () async {
      final native = _FakeSeparationNative(
        pollSnapshots: <NativeJobSnapshot>[
          NativeJobSnapshot(
            state: SeparationJobState.cancelled,
            stage: SeparationStage.infer,
            progress: 0.42,
          ),
        ],
      );
      final controller = SeparationTaskController(native: native);
      addTearDown(controller.dispose);

      final future = controller.start(_request());

      await expectLater(future, throwsA(isA<NativeCancelledException>()));
      expect(native.resultForJobCalls, 0);
    },
  );

  test('cancel() ignores not found race errors', () async {
    final native = _FakeSeparationNative(
      pollSnapshots: <NativeJobSnapshot>[
        NativeJobSnapshot(
          state: SeparationJobState.running,
          stage: SeparationStage.decode,
          progress: 0.2,
        ),
        NativeJobSnapshot(
          state: SeparationJobState.cancelled,
          stage: SeparationStage.infer,
          progress: 0.2,
        ),
      ],
      cancelError: NativeFfiException(
        'job not found',
        AmsNativeStatus.notFound,
      ),
    );
    final controller = SeparationTaskController(native: native);
    addTearDown(controller.dispose);

    final future = controller.start(_request());
    expect(() => controller.cancel(), returnsNormally);

    await expectLater(future, throwsA(isA<NativeCancelledException>()));
    expect(native.cancelCalls, 1);
  });
}

SeparationRequest _request() {
  return SeparationRequest(
    modelPath: 'model.gguf',
    inputPath: 'input.wav',
    outputDir: 'out',
    outputPrefix: 'test',
    outputFormat: AmsOutputFormat.wav,
    chunkSize: -1,
    overlap: -1,
    backend: AmsBackend.auto,
  );
}

class _FakeSeparationNative implements AmsSeparationNativeApi {
  _FakeSeparationNative({
    required List<NativeJobSnapshot> pollSnapshots,
    this.cancelError,
  }) : _pollSnapshots = Queue<NativeJobSnapshot>.from(pollSnapshots);

  final Queue<NativeJobSnapshot> _pollSnapshots;
  final Object? cancelError;

  int cancelCalls = 0;
  int resultForJobCalls = 0;
  NativeJobSnapshot _lastSnapshot = NativeJobSnapshot(
    state: SeparationJobState.pending,
    stage: SeparationStage.idle,
    progress: 0.0,
  );

  @override
  void cancelJob(int jobHandle) {
    cancelCalls += 1;
    final error = cancelError;
    if (error != null) {
      throw error;
    }
  }

  @override
  void closeEngine(int engineHandle) {}

  @override
  void destroyJob(int jobHandle) {}

  @override
  EngineDefaults getDefaults(int engineHandle) {
    return EngineDefaults(chunkSize: 352800, overlap: 2, sampleRate: 44100);
  }

  @override
  int openEngine(String modelPath, AmsBackend backend) => 1;

  @override
  NativeJobSnapshot pollJob(int jobHandle) {
    if (_pollSnapshots.isNotEmpty) {
      _lastSnapshot = _pollSnapshots.removeFirst();
    }
    return _lastSnapshot;
  }

  @override
  SeparationResult resultForJob(int jobHandle) {
    resultForJobCalls += 1;
    return SeparationResult(
      outputFiles: const <String>[],
      modelInputFile: null,
      canonicalInputFile: null,
      inferenceElapsedMs: null,
    );
  }

  @override
  int startJob(int engineHandle, SeparationRequest request) => 10;
}
