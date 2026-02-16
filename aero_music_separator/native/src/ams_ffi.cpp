#include "ams_ffi.h"

#include <cstdlib>
#include <exception>
#include <string>

#include "engine_manager.h"
#include "error_store.h"
#include "job_manager.h"
#include "prepare_manager.h"

namespace {

template <typename Fn>
ams_code_t WrapCapi(Fn&& fn) {
  try {
    return fn();
  } catch (const std::exception& e) {
    ams::SetLastError(std::string("native exception: ") + e.what());
    return AMS_ERR_RUNTIME;
  } catch (...) {
    ams::SetLastError("native exception: unknown");
    return AMS_ERR_RUNTIME;
  }
}

void SetEnvValue(const char* key, const char* value) {
#ifdef _WIN32
  _putenv_s(key, value);
#else
  setenv(key, value, 1);
#endif
}

void UnsetEnvValue(const char* key) {
#ifdef _WIN32
  _putenv_s(key, "");
#else
  unsetenv(key);
#endif
}

}  // namespace

extern "C" {

ams_code_t ams_engine_open(const char* model_path,
                           int32_t backend_preference,
                           ams_engine_t* out_engine) {
  return WrapCapi([&]() {
    if (model_path == nullptr) {
      ams::SetLastError("invalid argument: model_path");
      return AMS_ERR_INVALID_ARG;
    }
    return ams::EngineManager::Instance().Open(model_path, backend_preference, out_engine);
  });
}

ams_code_t ams_engine_get_defaults(ams_engine_t engine,
                                   int32_t* out_chunk_size,
                                   int32_t* out_overlap,
                                   int32_t* out_sample_rate) {
  return WrapCapi([&]() {
    if (out_chunk_size == nullptr || out_overlap == nullptr || out_sample_rate == nullptr) {
      ams::SetLastError("invalid argument: defaults output");
      return AMS_ERR_INVALID_ARG;
    }

    auto engine_ctx = ams::EngineManager::Instance().Find(engine);
    if (engine_ctx == nullptr) {
      ams::SetLastError("engine not found");
      return AMS_ERR_NOT_FOUND;
    }

    *out_chunk_size = engine_ctx->inference->GetDefaultChunkSize();
    *out_overlap = engine_ctx->inference->GetDefaultNumOverlap();
    *out_sample_rate = engine_ctx->inference->GetSampleRate();
    return AMS_OK;
  });
}

ams_code_t ams_engine_close(ams_engine_t engine) {
  return WrapCapi([&]() { return ams::EngineManager::Instance().Close(engine); });
}

ams_code_t ams_prepare_start(ams_engine_t engine,
                             const ams_prepare_config_t* config,
                             ams_prepare_t* out_prepare) {
  return WrapCapi([&]() {
    if (config == nullptr || out_prepare == nullptr || config->input_path == nullptr ||
        config->work_dir == nullptr) {
      ams::SetLastError("invalid argument: prepare start config");
      return AMS_ERR_INVALID_ARG;
    }

    std::shared_ptr<ams::EngineContext> engine_ctx;
    if (engine != 0) {
      engine_ctx = ams::EngineManager::Instance().Find(engine);
      if (engine_ctx == nullptr) {
        ams::SetLastError("engine not found");
        return AMS_ERR_NOT_FOUND;
      }
    }

    ams::PrepareConfig prepare_config;
    prepare_config.input_path = config->input_path;
    prepare_config.work_dir = config->work_dir;
    prepare_config.output_prefix =
        config->output_prefix != nullptr ? config->output_prefix : "input";
    return ams::PrepareManager::Instance().Start(engine_ctx, prepare_config, out_prepare);
  });
}

ams_code_t ams_prepare_poll(ams_prepare_t task,
                            int32_t* out_state,
                            double* out_progress_0_1,
                            int32_t* out_stage) {
  return WrapCapi([&]() {
    return ams::PrepareManager::Instance().Poll(task, out_state, out_progress_0_1, out_stage);
  });
}

ams_code_t ams_prepare_cancel(ams_prepare_t task) {
  return WrapCapi([&]() { return ams::PrepareManager::Instance().Cancel(task); });
}

ams_code_t ams_prepare_get_result_json(ams_prepare_t task, const char** out_json_utf8) {
  return WrapCapi([&]() {
    if (out_json_utf8 == nullptr) {
      ams::SetLastError("invalid argument: prepare result output");
      return AMS_ERR_INVALID_ARG;
    }

    std::string result;
    const ams_code_t code = ams::PrepareManager::Instance().GetResultJson(task, &result);
    if (code != AMS_OK) {
      return code;
    }

    char* c_str = ams::AllocCString(result);
    if (c_str == nullptr) {
      ams::SetLastError("memory allocation failed");
      return AMS_ERR_RUNTIME;
    }

    *out_json_utf8 = c_str;
    return AMS_OK;
  });
}

ams_code_t ams_prepare_destroy(ams_prepare_t task) {
  return WrapCapi([&]() { return ams::PrepareManager::Instance().Destroy(task); });
}

ams_code_t ams_job_start(ams_engine_t engine,
                         const ams_run_config_t* config,
                         ams_job_t* out_job) {
  return WrapCapi([&]() {
    if (config == nullptr || out_job == nullptr || config->output_dir == nullptr) {
      ams::SetLastError("invalid argument: job start config");
      return AMS_ERR_INVALID_ARG;
    }

    auto engine_ctx = ams::EngineManager::Instance().Find(engine);
    if (engine_ctx == nullptr) {
      ams::SetLastError("engine not found");
      return AMS_ERR_NOT_FOUND;
    }

    ams::JobConfig job_config;
    job_config.input_path = config->input_path != nullptr ? config->input_path : "";
    job_config.prepared_input_path =
        config->prepared_input_path != nullptr ? config->prepared_input_path : "";
    job_config.output_dir = config->output_dir;
    job_config.output_prefix = config->output_prefix != nullptr ? config->output_prefix : "separated";
    job_config.output_format = config->output_format;
    job_config.chunk_size = config->chunk_size;
    job_config.overlap = config->overlap;

    return ams::JobManager::Instance().Start(engine_ctx, job_config, out_job);
  });
}

ams_code_t ams_job_poll(ams_job_t job,
                        int32_t* out_state,
                        double* out_progress_0_1,
                        int32_t* out_stage) {
  return WrapCapi([&]() {
    return ams::JobManager::Instance().Poll(job, out_state, out_progress_0_1, out_stage);
  });
}

ams_code_t ams_job_cancel(ams_job_t job) {
  return WrapCapi([&]() { return ams::JobManager::Instance().Cancel(job); });
}

ams_code_t ams_job_get_result_json(ams_job_t job, const char** out_json_utf8) {
  return WrapCapi([&]() {
    if (out_json_utf8 == nullptr) {
      ams::SetLastError("invalid argument: result output");
      return AMS_ERR_INVALID_ARG;
    }

    std::string result;
    const ams_code_t code = ams::JobManager::Instance().GetResultJson(job, &result);
    if (code != AMS_OK) {
      return code;
    }

    char* c_str = ams::AllocCString(result);
    if (c_str == nullptr) {
      ams::SetLastError("memory allocation failed");
      return AMS_ERR_RUNTIME;
    }

    *out_json_utf8 = c_str;
    return AMS_OK;
  });
}

ams_code_t ams_job_destroy(ams_job_t job) {
  return WrapCapi([&]() { return ams::JobManager::Instance().Destroy(job); });
}

const char* ams_last_error(void) {
  return ams::GetLastError();
}

void ams_string_free(const char* ptr) {
  delete[] ptr;
}

ams_code_t ams_runtime_set_env(const char* key, const char* value) {
  return WrapCapi([&]() {
    if (key == nullptr || value == nullptr || key[0] == '\0') {
      ams::SetLastError("invalid argument: runtime set env");
      return AMS_ERR_INVALID_ARG;
    }
    SetEnvValue(key, value);
    return AMS_OK;
  });
}

ams_code_t ams_runtime_unset_env(const char* key) {
  return WrapCapi([&]() {
    if (key == nullptr || key[0] == '\0') {
      ams::SetLastError("invalid argument: runtime unset env");
      return AMS_ERR_INVALID_ARG;
    }
    UnsetEnvValue(key);
    return AMS_OK;
  });
}

}  // extern "C"
