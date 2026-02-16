#ifndef AMS_FFI_H_
#define AMS_FFI_H_

#include <stdint.h>

#ifdef _WIN32
#define AMS_EXPORT __declspec(dllexport)
#else
#define AMS_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef uint64_t ams_engine_t;
typedef uint64_t ams_job_t;
typedef uint64_t ams_prepare_t;

typedef enum ams_code_e {
  AMS_OK = 0,
  AMS_ERR_INVALID_ARG = 1,
  AMS_ERR_NOT_FOUND = 2,
  AMS_ERR_RUNTIME = 3,
  AMS_ERR_UNSUPPORTED = 4,
  AMS_ERR_CANCELLED = 5,
} ams_code_t;

typedef enum ams_backend_e {
  AMS_BACKEND_AUTO = 0,
  AMS_BACKEND_CPU = 1,
  AMS_BACKEND_VULKAN = 2,
  AMS_BACKEND_CUDA = 3,
  AMS_BACKEND_METAL = 4,
} ams_backend_t;

typedef enum ams_output_fmt_e {
  AMS_OUTPUT_WAV = 0,
  AMS_OUTPUT_FLAC = 1,
  AMS_OUTPUT_MP3 = 2,
} ams_output_fmt_t;

typedef enum ams_job_state_e {
  AMS_JOB_PENDING = 0,
  AMS_JOB_RUNNING = 1,
  AMS_JOB_SUCCEEDED = 2,
  AMS_JOB_FAILED = 3,
  AMS_JOB_CANCELLED = 4,
} ams_job_state_t;

typedef enum ams_job_stage_e {
  AMS_STAGE_IDLE = 0,
  AMS_STAGE_DECODE = 1,
  AMS_STAGE_INFER = 2,
  AMS_STAGE_ENCODE = 3,
  AMS_STAGE_DONE = 4,
} ams_job_stage_t;

typedef enum ams_prepare_stage_e {
  AMS_PREPARE_STAGE_IDLE = 0,
  AMS_PREPARE_STAGE_DECODE = 1,
  AMS_PREPARE_STAGE_RESAMPLE = 2,
  AMS_PREPARE_STAGE_WRITE_CANONICAL = 3,
  AMS_PREPARE_STAGE_DONE = 4,
} ams_prepare_stage_t;

typedef struct ams_run_config_s {
  const char* input_path;
  const char* prepared_input_path;
  const char* output_dir;
  const char* output_prefix;
  int32_t output_format;
  int32_t chunk_size;
  int32_t overlap;
} ams_run_config_t;

typedef struct ams_prepare_config_s {
  const char* input_path;
  const char* work_dir;
  const char* output_prefix;
} ams_prepare_config_t;

AMS_EXPORT ams_code_t ams_engine_open(const char* model_path,
                                      int32_t backend_preference,
                                      ams_engine_t* out_engine);

AMS_EXPORT ams_code_t ams_engine_get_defaults(ams_engine_t engine,
                                              int32_t* out_chunk_size,
                                              int32_t* out_overlap,
                                              int32_t* out_sample_rate);

AMS_EXPORT ams_code_t ams_engine_close(ams_engine_t engine);

AMS_EXPORT ams_code_t ams_prepare_start(ams_engine_t engine,
                                        const ams_prepare_config_t* config,
                                        ams_prepare_t* out_prepare);

AMS_EXPORT ams_code_t ams_prepare_poll(ams_prepare_t task,
                                       int32_t* out_state,
                                       double* out_progress_0_1,
                                       int32_t* out_stage);

AMS_EXPORT ams_code_t ams_prepare_cancel(ams_prepare_t task);

AMS_EXPORT ams_code_t ams_prepare_get_result_json(ams_prepare_t task,
                                                  const char** out_json_utf8);

AMS_EXPORT ams_code_t ams_prepare_destroy(ams_prepare_t task);

AMS_EXPORT ams_code_t ams_job_start(ams_engine_t engine,
                                    const ams_run_config_t* config,
                                    ams_job_t* out_job);

AMS_EXPORT ams_code_t ams_job_poll(ams_job_t job,
                                   int32_t* out_state,
                                   double* out_progress_0_1,
                                   int32_t* out_stage);

AMS_EXPORT ams_code_t ams_job_cancel(ams_job_t job);

AMS_EXPORT ams_code_t ams_job_get_result_json(ams_job_t job,
                                              const char** out_json_utf8);

AMS_EXPORT ams_code_t ams_job_destroy(ams_job_t job);

AMS_EXPORT const char* ams_last_error(void);

AMS_EXPORT void ams_string_free(const char* ptr);

AMS_EXPORT ams_code_t ams_runtime_set_env(const char* key, const char* value);

AMS_EXPORT ams_code_t ams_runtime_unset_env(const char* key);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // AMS_FFI_H_
