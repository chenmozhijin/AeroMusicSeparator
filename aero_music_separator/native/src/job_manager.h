#pragma once

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "ams_ffi.h"
#include "engine_manager.h"

namespace ams {

struct JobConfig {
  std::string input_path;
  std::string prepared_input_path;
  std::string output_dir;
  std::string output_prefix;
  int32_t output_format = AMS_OUTPUT_WAV;
  int32_t chunk_size = -1;
  int32_t overlap = -1;
};

struct JobContext {
  ams_job_t handle = 0;
  std::shared_ptr<EngineContext> engine;
  JobConfig config;

  std::atomic<int32_t> state{AMS_JOB_PENDING};
  std::atomic<int32_t> stage{AMS_STAGE_IDLE};
  std::atomic<double> progress{0.0};
  std::atomic<bool> cancel_requested{false};

  std::mutex data_mutex;
  std::string result_json;
  std::string error_message;

  std::thread worker;
};

class JobManager {
 public:
  static JobManager& Instance();

  ams_code_t Start(std::shared_ptr<EngineContext> engine,
                   const JobConfig& config,
                   ams_job_t* out_job);

  ams_code_t Poll(ams_job_t job,
                  int32_t* out_state,
                  double* out_progress_0_1,
                  int32_t* out_stage);

  ams_code_t Cancel(ams_job_t job);
  ams_code_t GetResultJson(ams_job_t job, std::string* out_json);
  ams_code_t Destroy(ams_job_t job);

 private:
  JobManager() = default;

  static void RunJob(const std::shared_ptr<JobContext>& job);
  static std::string JoinPath(const std::string& dir, const std::string& file_name);

  std::shared_ptr<JobContext> FindLocked(ams_job_t job);

  std::mutex mutex_;
  ams_job_t next_handle_ = 1;
  std::unordered_map<ams_job_t, std::shared_ptr<JobContext>> jobs_;
};

}  // namespace ams
