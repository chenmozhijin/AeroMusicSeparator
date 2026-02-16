import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../audio/preview_models.dart';
import '../separation/separation_models.dart';
import 'ams_bindings.dart';

abstract final class AmsNativeStatus {
  static const int ok = 0;
  static const int invalidArg = 1;
  static const int notFound = 2;
  static const int runtime = 3;
  static const int unsupported = 4;
  static const int cancelled = 5;
}

class NativeFfiException implements Exception {
  NativeFfiException(this.message, this.code);

  final String message;
  final int code;

  @override
  String toString() => 'NativeFfiException(code=$code, message=$message)';
}

class NativeCancelledException extends NativeFfiException {
  NativeCancelledException(
    super.message, [
    super.code = AmsNativeStatus.cancelled,
  ]);
}

class EngineDefaults {
  EngineDefaults({
    required this.chunkSize,
    required this.overlap,
    required this.sampleRate,
  });

  final int chunkSize;
  final int overlap;
  final int sampleRate;
}

class NativePrepareSnapshot {
  NativePrepareSnapshot({
    required this.state,
    required this.stage,
    required this.progress,
  });

  final InputPrepareTaskState state;
  final InputPrepareStage stage;
  final double progress;
}

class NativeJobSnapshot {
  NativeJobSnapshot({
    required this.state,
    required this.stage,
    required this.progress,
  });

  final SeparationJobState state;
  final SeparationStage stage;
  final double progress;
}

abstract interface class AmsPrepareNativeApi {
  int startPrepare({
    required int engineHandle,
    required String inputPath,
    required String workDir,
    String outputPrefix = 'input',
  });

  NativePrepareSnapshot pollPrepare(int prepareHandle);

  void cancelPrepare(int prepareHandle);

  InputPreviewInfo resultForPrepare(int prepareHandle);

  void destroyPrepare(int prepareHandle);
}

abstract interface class AmsSeparationNativeApi {
  int openEngine(String modelPath, AmsBackend backend);

  EngineDefaults getDefaults(int engineHandle);

  void closeEngine(int engineHandle);

  int startJob(int engineHandle, SeparationRequest request);

  NativeJobSnapshot pollJob(int jobHandle);

  void cancelJob(int jobHandle);

  SeparationResult resultForJob(int jobHandle);

  void destroyJob(int jobHandle);
}

class AmsNative implements AmsPrepareNativeApi, AmsSeparationNativeApi {
  AmsNative._() : _bindings = AmsBindings(_openLibrary());

  static final AmsNative instance = AmsNative._();

  static bool get isRuntimeSupportedPlatform =>
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isIOS;

  final AmsBindings _bindings;

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('aero_separator_ffi.dll');
    }
    if (Platform.isMacOS) {
      return ffi.DynamicLibrary.open('libaero_separator_ffi.dylib');
    }
    if (Platform.isIOS) {
      // iOS links native symbols into process images (static/XCFramework flow).
      return ffi.DynamicLibrary.process();
    }
    if (Platform.isLinux || Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libaero_separator_ffi.so');
    }
    throw UnsupportedError(
      'Native FFI is currently supported on Windows, Linux, Android, macOS, and iOS.',
    );
  }

  String _lastError() {
    final ptr = _bindings.lastError();
    if (ptr == ffi.nullptr) {
      return 'unknown native error';
    }
    return ptr.toDartString();
  }

  void _ensureOk(int code, {String? prefix}) {
    if (code == AmsNativeStatus.ok) {
      return;
    }
    final message = _lastError();
    final resolvedMessage = prefix == null ? message : '$prefix: $message';
    if (code == AmsNativeStatus.cancelled) {
      throw NativeCancelledException(resolvedMessage, code);
    }
    throw NativeFfiException(resolvedMessage, code);
  }

  @override
  int openEngine(String modelPath, AmsBackend backend) {
    final modelPathPtr = modelPath.toNativeUtf8();
    final outEngine = calloc<ffi.Uint64>();
    try {
      final code = _bindings.engineOpen(modelPathPtr, backend.value, outEngine);
      _ensureOk(code, prefix: 'engine open failed');
      return outEngine.value;
    } finally {
      calloc.free(modelPathPtr);
      calloc.free(outEngine);
    }
  }

  @override
  EngineDefaults getDefaults(int engineHandle) {
    final outChunk = calloc<ffi.Int32>();
    final outOverlap = calloc<ffi.Int32>();
    final outRate = calloc<ffi.Int32>();
    try {
      final code = _bindings.engineGetDefaults(
        engineHandle,
        outChunk,
        outOverlap,
        outRate,
      );
      _ensureOk(code, prefix: 'engine defaults failed');
      return EngineDefaults(
        chunkSize: outChunk.value,
        overlap: outOverlap.value,
        sampleRate: outRate.value,
      );
    } finally {
      calloc.free(outChunk);
      calloc.free(outOverlap);
      calloc.free(outRate);
    }
  }

  @override
  void closeEngine(int engineHandle) {
    final code = _bindings.engineClose(engineHandle);
    _ensureOk(code, prefix: 'engine close failed');
  }

  @override
  int startPrepare({
    required int engineHandle,
    required String inputPath,
    required String workDir,
    String outputPrefix = 'input',
  }) {
    final inputPathPtr = inputPath.toNativeUtf8();
    final workDirPtr = workDir.toNativeUtf8();
    final outputPrefixPtr = outputPrefix.toNativeUtf8();

    final config = calloc<AmsPrepareConfig>();
    final outPrepare = calloc<ffi.Uint64>();
    try {
      config.ref
        ..inputPath = inputPathPtr
        ..workDir = workDirPtr
        ..outputPrefix = outputPrefixPtr;

      final code = _bindings.prepareStart(engineHandle, config, outPrepare);
      _ensureOk(code, prefix: 'prepare start failed');
      return outPrepare.value;
    } finally {
      calloc.free(inputPathPtr);
      calloc.free(workDirPtr);
      calloc.free(outputPrefixPtr);
      calloc.free(config);
      calloc.free(outPrepare);
    }
  }

  @override
  NativePrepareSnapshot pollPrepare(int prepareHandle) {
    final outState = calloc<ffi.Int32>();
    final outProgress = calloc<ffi.Double>();
    final outStage = calloc<ffi.Int32>();
    try {
      final code = _bindings.preparePoll(
        prepareHandle,
        outState,
        outProgress,
        outStage,
      );
      _ensureOk(code, prefix: 'prepare poll failed');
      return NativePrepareSnapshot(
        state: InputPrepareTaskState.fromValue(outState.value),
        stage: InputPrepareStage.fromValue(outStage.value),
        progress: outProgress.value.clamp(0.0, 1.0),
      );
    } finally {
      calloc.free(outState);
      calloc.free(outProgress);
      calloc.free(outStage);
    }
  }

  @override
  void cancelPrepare(int prepareHandle) {
    final code = _bindings.prepareCancel(prepareHandle);
    _ensureOk(code, prefix: 'prepare cancel failed');
  }

  @override
  InputPreviewInfo resultForPrepare(int prepareHandle) {
    final outResult = calloc<ffi.Pointer<Utf8>>();
    try {
      final code = _bindings.prepareGetResult(prepareHandle, outResult);
      _ensureOk(code, prefix: 'prepare result failed');

      final ptr = outResult.value;
      if (ptr == ffi.nullptr) {
        throw NativeFfiException('prepare result pointer is null', code);
      }

      final json = ptr.toDartString();
      _bindings.stringFree(ptr);
      return InputPreviewInfo.fromJson(json);
    } finally {
      calloc.free(outResult);
    }
  }

  @override
  void destroyPrepare(int prepareHandle) {
    final code = _bindings.prepareDestroy(prepareHandle);
    _ensureOk(code, prefix: 'prepare destroy failed');
  }

  @override
  int startJob(int engineHandle, SeparationRequest request) {
    final inputPath = request.inputPath.toNativeUtf8();
    final outputDir = request.outputDir.toNativeUtf8();
    final outputPrefix = request.outputPrefix.toNativeUtf8();
    final preparedInputPathPtr = request.preparedInputPath?.toNativeUtf8();

    final config = calloc<AmsRunConfig>();
    final outJob = calloc<ffi.Uint64>();
    try {
      config.ref
        ..inputPath = inputPath
        ..preparedInputPath = preparedInputPathPtr ?? ffi.nullptr
        ..outputDir = outputDir
        ..outputPrefix = outputPrefix
        ..outputFormat = request.outputFormat.value
        ..chunkSize = request.chunkSize
        ..overlap = request.overlap;

      final code = _bindings.jobStart(engineHandle, config, outJob);
      _ensureOk(code, prefix: 'job start failed');
      return outJob.value;
    } finally {
      calloc.free(inputPath);
      calloc.free(outputDir);
      calloc.free(outputPrefix);
      if (preparedInputPathPtr != null) {
        calloc.free(preparedInputPathPtr);
      }
      calloc.free(config);
      calloc.free(outJob);
    }
  }

  @override
  NativeJobSnapshot pollJob(int jobHandle) {
    final outState = calloc<ffi.Int32>();
    final outProgress = calloc<ffi.Double>();
    final outStage = calloc<ffi.Int32>();
    try {
      final code = _bindings.jobPoll(
        jobHandle,
        outState,
        outProgress,
        outStage,
      );
      _ensureOk(code, prefix: 'job poll failed');
      return NativeJobSnapshot(
        state: SeparationJobState.fromValue(outState.value),
        stage: SeparationStage.fromValue(outStage.value),
        progress: outProgress.value.clamp(0.0, 1.0),
      );
    } finally {
      calloc.free(outState);
      calloc.free(outProgress);
      calloc.free(outStage);
    }
  }

  @override
  void cancelJob(int jobHandle) {
    final code = _bindings.jobCancel(jobHandle);
    _ensureOk(code, prefix: 'job cancel failed');
  }

  @override
  SeparationResult resultForJob(int jobHandle) {
    final outResult = calloc<ffi.Pointer<Utf8>>();
    try {
      final code = _bindings.jobGetResult(jobHandle, outResult);
      _ensureOk(code, prefix: 'job result failed');

      final ptr = outResult.value;
      if (ptr == ffi.nullptr) {
        throw NativeFfiException('job result pointer is null', code);
      }

      final json = ptr.toDartString();
      _bindings.stringFree(ptr);
      return SeparationResult.fromJson(json);
    } finally {
      calloc.free(outResult);
    }
  }

  @override
  void destroyJob(int jobHandle) {
    final code = _bindings.jobDestroy(jobHandle);
    _ensureOk(code, prefix: 'job destroy failed');
  }

  void runtimeSetEnv(String key, String value) {
    final keyPtr = key.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      final code = _bindings.runtimeSetEnv(keyPtr, valuePtr);
      _ensureOk(code, prefix: 'runtime set env failed');
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  void runtimeUnsetEnv(String key) {
    final keyPtr = key.toNativeUtf8();
    try {
      final code = _bindings.runtimeUnsetEnv(keyPtr);
      _ensureOk(code, prefix: 'runtime unset env failed');
    } finally {
      calloc.free(keyPtr);
    }
  }
}
