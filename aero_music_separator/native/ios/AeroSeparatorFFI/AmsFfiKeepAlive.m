#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
extern int ams_engine_open(const char* model_path, int backend_preference, unsigned long long* out_engine);
extern int ams_engine_get_defaults(unsigned long long engine, int* out_chunk_size, int* out_overlap, int* out_sample_rate);
extern int ams_engine_close(unsigned long long engine);
extern int ams_prepare_start(unsigned long long engine, const void* config, unsigned long long* out_prepare);
extern int ams_prepare_poll(unsigned long long task, int* out_state, double* out_progress_0_1, int* out_stage);
extern int ams_prepare_cancel(unsigned long long task);
extern int ams_prepare_get_result_json(unsigned long long task, const char** out_json_utf8);
extern int ams_prepare_destroy(unsigned long long task);
extern int ams_job_start(unsigned long long engine, const void* config, unsigned long long* out_job);
extern int ams_job_poll(unsigned long long job, int* out_state, double* out_progress_0_1, int* out_stage);
extern int ams_job_cancel(unsigned long long job);
extern int ams_job_get_result_json(unsigned long long job, const char** out_json_utf8);
extern int ams_job_destroy(unsigned long long job);
extern const char* ams_last_error(void);
extern void ams_string_free(const char* ptr);
extern int ams_runtime_set_env(const char* key, const char* value);
extern int ams_runtime_unset_env(const char* key);
#ifdef __cplusplus
}
#endif

__attribute__((used))
static void* const kAmsFfiKeepAlive[] = {
    (void*)&ams_engine_open,
    (void*)&ams_engine_get_defaults,
    (void*)&ams_engine_close,
    (void*)&ams_prepare_start,
    (void*)&ams_prepare_poll,
    (void*)&ams_prepare_cancel,
    (void*)&ams_prepare_get_result_json,
    (void*)&ams_prepare_destroy,
    (void*)&ams_job_start,
    (void*)&ams_job_poll,
    (void*)&ams_job_cancel,
    (void*)&ams_job_get_result_json,
    (void*)&ams_job_destroy,
    (void*)&ams_last_error,
    (void*)&ams_string_free,
    (void*)&ams_runtime_set_env,
    (void*)&ams_runtime_unset_env,
};
