import 'dart:collection';

import 'package:aero_music_separator/core/audio/preview_models.dart';
import 'package:aero_music_separator/core/ffi/ams_native.dart';
import 'package:aero_music_separator/core/separation/input_prepare_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cancelled prepare completes with NativeCancelledException without reading result',
    () async {
      final native = _FakePrepareNative(
        pollSnapshots: <NativePrepareSnapshot>[
          NativePrepareSnapshot(
            state: InputPrepareTaskState.cancelled,
            stage: InputPrepareStage.decode,
            progress: 0.5,
          ),
        ],
      );
      final service = InputPrepareService(native: native);
      addTearDown(service.dispose);

      final future = service.start(
        InputPrepareRequest(inputPath: 'input.wav', workDir: '.'),
      );

      await expectLater(future, throwsA(isA<NativeCancelledException>()));
      expect(native.resultForPrepareCalls, 0);
    },
  );

  test('cancel() ignores prepare not found race errors', () async {
    final native = _FakePrepareNative(
      pollSnapshots: <NativePrepareSnapshot>[
        NativePrepareSnapshot(
          state: InputPrepareTaskState.running,
          stage: InputPrepareStage.decode,
          progress: 0.2,
        ),
        NativePrepareSnapshot(
          state: InputPrepareTaskState.cancelled,
          stage: InputPrepareStage.resample,
          progress: 0.2,
        ),
      ],
      cancelError: NativeFfiException(
        'prepare not found',
        AmsNativeStatus.notFound,
      ),
    );
    final service = InputPrepareService(native: native);
    addTearDown(service.dispose);

    final future = service.start(
      InputPrepareRequest(inputPath: 'input.wav', workDir: '.'),
    );
    expect(() => service.cancel(), returnsNormally);

    await expectLater(future, throwsA(isA<NativeCancelledException>()));
    expect(native.cancelCalls, 1);
  });
}

class _FakePrepareNative implements AmsPrepareNativeApi {
  _FakePrepareNative({
    required List<NativePrepareSnapshot> pollSnapshots,
    this.cancelError,
  }) : _pollSnapshots = Queue<NativePrepareSnapshot>.from(pollSnapshots);

  final Queue<NativePrepareSnapshot> _pollSnapshots;
  final Object? cancelError;

  int cancelCalls = 0;
  int resultForPrepareCalls = 0;
  NativePrepareSnapshot _lastSnapshot = NativePrepareSnapshot(
    state: InputPrepareTaskState.pending,
    stage: InputPrepareStage.idle,
    progress: 0.0,
  );

  @override
  void cancelPrepare(int prepareHandle) {
    cancelCalls += 1;
    final error = cancelError;
    if (error != null) {
      throw error;
    }
  }

  @override
  void destroyPrepare(int prepareHandle) {}

  @override
  NativePrepareSnapshot pollPrepare(int prepareHandle) {
    if (_pollSnapshots.isNotEmpty) {
      _lastSnapshot = _pollSnapshots.removeFirst();
    }
    return _lastSnapshot;
  }

  @override
  InputPreviewInfo resultForPrepare(int prepareHandle) {
    resultForPrepareCalls += 1;
    return InputPreviewInfo(
      canonicalPath: 'canonical.wav',
      durationMs: 1000,
      sampleRate: 44100,
      channels: 2,
    );
  }

  @override
  int startPrepare({
    required int engineHandle,
    required String inputPath,
    required String workDir,
    String outputPrefix = 'input',
  }) {
    return 1;
  }
}
