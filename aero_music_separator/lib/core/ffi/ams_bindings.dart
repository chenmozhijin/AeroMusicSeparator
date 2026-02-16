import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

final class AmsRunConfig extends ffi.Struct {
  external ffi.Pointer<Utf8> inputPath;
  external ffi.Pointer<Utf8> preparedInputPath;
  external ffi.Pointer<Utf8> outputDir;
  external ffi.Pointer<Utf8> outputPrefix;

  @ffi.Int32()
  external int outputFormat;

  @ffi.Int32()
  external int chunkSize;

  @ffi.Int32()
  external int overlap;
}

final class AmsPrepareConfig extends ffi.Struct {
  external ffi.Pointer<Utf8> inputPath;
  external ffi.Pointer<Utf8> workDir;
  external ffi.Pointer<Utf8> outputPrefix;
}

typedef _EngineOpenNative =
    ffi.Int32 Function(
      ffi.Pointer<Utf8> modelPath,
      ffi.Int32 backendPreference,
      ffi.Pointer<ffi.Uint64> outEngine,
    );
typedef _EngineOpenDart =
    int Function(
      ffi.Pointer<Utf8> modelPath,
      int backendPreference,
      ffi.Pointer<ffi.Uint64> outEngine,
    );

typedef _EngineGetDefaultsNative =
    ffi.Int32 Function(
      ffi.Uint64 engine,
      ffi.Pointer<ffi.Int32> outChunkSize,
      ffi.Pointer<ffi.Int32> outOverlap,
      ffi.Pointer<ffi.Int32> outSampleRate,
    );
typedef _EngineGetDefaultsDart =
    int Function(
      int engine,
      ffi.Pointer<ffi.Int32> outChunkSize,
      ffi.Pointer<ffi.Int32> outOverlap,
      ffi.Pointer<ffi.Int32> outSampleRate,
    );

typedef _EngineCloseNative = ffi.Int32 Function(ffi.Uint64 engine);
typedef _EngineCloseDart = int Function(int engine);

typedef _PrepareStartNative =
    ffi.Int32 Function(
      ffi.Uint64 engine,
      ffi.Pointer<AmsPrepareConfig> config,
      ffi.Pointer<ffi.Uint64> outPrepare,
    );
typedef _PrepareStartDart =
    int Function(
      int engine,
      ffi.Pointer<AmsPrepareConfig> config,
      ffi.Pointer<ffi.Uint64> outPrepare,
    );

typedef _PreparePollNative =
    ffi.Int32 Function(
      ffi.Uint64 task,
      ffi.Pointer<ffi.Int32> outState,
      ffi.Pointer<ffi.Double> outProgress,
      ffi.Pointer<ffi.Int32> outStage,
    );
typedef _PreparePollDart =
    int Function(
      int task,
      ffi.Pointer<ffi.Int32> outState,
      ffi.Pointer<ffi.Double> outProgress,
      ffi.Pointer<ffi.Int32> outStage,
    );

typedef _PrepareCancelNative = ffi.Int32 Function(ffi.Uint64 task);
typedef _PrepareCancelDart = int Function(int task);

typedef _PrepareGetResultNative =
    ffi.Int32 Function(ffi.Uint64 task, ffi.Pointer<ffi.Pointer<Utf8>> outJson);
typedef _PrepareGetResultDart =
    int Function(int task, ffi.Pointer<ffi.Pointer<Utf8>> outJson);

typedef _PrepareDestroyNative = ffi.Int32 Function(ffi.Uint64 task);
typedef _PrepareDestroyDart = int Function(int task);

typedef _JobStartNative =
    ffi.Int32 Function(
      ffi.Uint64 engine,
      ffi.Pointer<AmsRunConfig> config,
      ffi.Pointer<ffi.Uint64> outJob,
    );
typedef _JobStartDart =
    int Function(
      int engine,
      ffi.Pointer<AmsRunConfig> config,
      ffi.Pointer<ffi.Uint64> outJob,
    );

typedef _JobPollNative =
    ffi.Int32 Function(
      ffi.Uint64 job,
      ffi.Pointer<ffi.Int32> outState,
      ffi.Pointer<ffi.Double> outProgress,
      ffi.Pointer<ffi.Int32> outStage,
    );
typedef _JobPollDart =
    int Function(
      int job,
      ffi.Pointer<ffi.Int32> outState,
      ffi.Pointer<ffi.Double> outProgress,
      ffi.Pointer<ffi.Int32> outStage,
    );

typedef _JobCancelNative = ffi.Int32 Function(ffi.Uint64 job);
typedef _JobCancelDart = int Function(int job);

typedef _JobGetResultNative =
    ffi.Int32 Function(ffi.Uint64 job, ffi.Pointer<ffi.Pointer<Utf8>> outJson);
typedef _JobGetResultDart =
    int Function(int job, ffi.Pointer<ffi.Pointer<Utf8>> outJson);

typedef _JobDestroyNative = ffi.Int32 Function(ffi.Uint64 job);
typedef _JobDestroyDart = int Function(int job);

typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _LastErrorDart = ffi.Pointer<Utf8> Function();

typedef _StringFreeNative = ffi.Void Function(ffi.Pointer<Utf8> value);
typedef _StringFreeDart = void Function(ffi.Pointer<Utf8> value);

typedef _RuntimeSetEnvNative =
    ffi.Int32 Function(ffi.Pointer<Utf8> key, ffi.Pointer<Utf8> value);
typedef _RuntimeSetEnvDart =
    int Function(ffi.Pointer<Utf8> key, ffi.Pointer<Utf8> value);

typedef _RuntimeUnsetEnvNative = ffi.Int32 Function(ffi.Pointer<Utf8> key);
typedef _RuntimeUnsetEnvDart = int Function(ffi.Pointer<Utf8> key);

class AmsBindings {
  AmsBindings(this.library)
    : _engineOpen = library.lookupFunction<_EngineOpenNative, _EngineOpenDart>(
        'ams_engine_open',
      ),
      _engineGetDefaults = library
          .lookupFunction<_EngineGetDefaultsNative, _EngineGetDefaultsDart>(
            'ams_engine_get_defaults',
          ),
      _engineClose = library
          .lookupFunction<_EngineCloseNative, _EngineCloseDart>(
            'ams_engine_close',
          ),
      _prepareStart = library
          .lookupFunction<_PrepareStartNative, _PrepareStartDart>(
            'ams_prepare_start',
          ),
      _preparePoll = library
          .lookupFunction<_PreparePollNative, _PreparePollDart>(
            'ams_prepare_poll',
          ),
      _prepareCancel = library
          .lookupFunction<_PrepareCancelNative, _PrepareCancelDart>(
            'ams_prepare_cancel',
          ),
      _prepareGetResult = library
          .lookupFunction<_PrepareGetResultNative, _PrepareGetResultDart>(
            'ams_prepare_get_result_json',
          ),
      _prepareDestroy = library
          .lookupFunction<_PrepareDestroyNative, _PrepareDestroyDart>(
            'ams_prepare_destroy',
          ),
      _jobStart = library.lookupFunction<_JobStartNative, _JobStartDart>(
        'ams_job_start',
      ),
      _jobPoll = library.lookupFunction<_JobPollNative, _JobPollDart>(
        'ams_job_poll',
      ),
      _jobCancel = library.lookupFunction<_JobCancelNative, _JobCancelDart>(
        'ams_job_cancel',
      ),
      _jobGetResult = library
          .lookupFunction<_JobGetResultNative, _JobGetResultDart>(
            'ams_job_get_result_json',
          ),
      _jobDestroy = library.lookupFunction<_JobDestroyNative, _JobDestroyDart>(
        'ams_job_destroy',
      ),
      _lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'ams_last_error',
      ),
      _stringFree = library.lookupFunction<_StringFreeNative, _StringFreeDart>(
        'ams_string_free',
      ),
      _runtimeSetEnv = library
          .lookupFunction<_RuntimeSetEnvNative, _RuntimeSetEnvDart>(
            'ams_runtime_set_env',
          ),
      _runtimeUnsetEnv = library
          .lookupFunction<_RuntimeUnsetEnvNative, _RuntimeUnsetEnvDart>(
            'ams_runtime_unset_env',
      );

  final ffi.DynamicLibrary library;

  final _EngineOpenDart _engineOpen;
  final _EngineGetDefaultsDart _engineGetDefaults;
  final _EngineCloseDart _engineClose;
  final _PrepareStartDart _prepareStart;
  final _PreparePollDart _preparePoll;
  final _PrepareCancelDart _prepareCancel;
  final _PrepareGetResultDart _prepareGetResult;
  final _PrepareDestroyDart _prepareDestroy;
  final _JobStartDart _jobStart;
  final _JobPollDart _jobPoll;
  final _JobCancelDart _jobCancel;
  final _JobGetResultDart _jobGetResult;
  final _JobDestroyDart _jobDestroy;
  final _LastErrorDart _lastError;
  final _StringFreeDart _stringFree;
  final _RuntimeSetEnvDart _runtimeSetEnv;
  final _RuntimeUnsetEnvDart _runtimeUnsetEnv;

  int engineOpen(
    ffi.Pointer<Utf8> modelPath,
    int backendPreference,
    ffi.Pointer<ffi.Uint64> outEngine,
  ) => _engineOpen(modelPath, backendPreference, outEngine);

  int engineGetDefaults(
    int engine,
    ffi.Pointer<ffi.Int32> outChunkSize,
    ffi.Pointer<ffi.Int32> outOverlap,
    ffi.Pointer<ffi.Int32> outSampleRate,
  ) => _engineGetDefaults(engine, outChunkSize, outOverlap, outSampleRate);

  int engineClose(int engine) => _engineClose(engine);

  int prepareStart(
    int engine,
    ffi.Pointer<AmsPrepareConfig> config,
    ffi.Pointer<ffi.Uint64> outPrepare,
  ) => _prepareStart(engine, config, outPrepare);

  int preparePoll(
    int task,
    ffi.Pointer<ffi.Int32> outState,
    ffi.Pointer<ffi.Double> outProgress,
    ffi.Pointer<ffi.Int32> outStage,
  ) => _preparePoll(task, outState, outProgress, outStage);

  int prepareCancel(int task) => _prepareCancel(task);

  int prepareGetResult(int task, ffi.Pointer<ffi.Pointer<Utf8>> outJson) =>
      _prepareGetResult(task, outJson);

  int prepareDestroy(int task) => _prepareDestroy(task);

  int jobStart(
    int engine,
    ffi.Pointer<AmsRunConfig> config,
    ffi.Pointer<ffi.Uint64> outJob,
  ) => _jobStart(engine, config, outJob);

  int jobPoll(
    int job,
    ffi.Pointer<ffi.Int32> outState,
    ffi.Pointer<ffi.Double> outProgress,
    ffi.Pointer<ffi.Int32> outStage,
  ) => _jobPoll(job, outState, outProgress, outStage);

  int jobCancel(int job) => _jobCancel(job);

  int jobGetResult(int job, ffi.Pointer<ffi.Pointer<Utf8>> outJson) =>
      _jobGetResult(job, outJson);

  int jobDestroy(int job) => _jobDestroy(job);

  ffi.Pointer<Utf8> lastError() => _lastError();

  void stringFree(ffi.Pointer<Utf8> value) => _stringFree(value);

  int runtimeSetEnv(ffi.Pointer<Utf8> key, ffi.Pointer<Utf8> value) =>
      _runtimeSetEnv(key, value);

  int runtimeUnsetEnv(ffi.Pointer<Utf8> key) => _runtimeUnsetEnv(key);
}
