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

struct PrepareConfig {
  std::string input_path;
  std::string work_dir;
  std::string output_prefix;
};

struct PrepareContext {
  ams_prepare_t handle = 0;
  std::shared_ptr<EngineContext> engine;
  PrepareConfig config;

  std::atomic<int32_t> state{AMS_JOB_PENDING};
  std::atomic<int32_t> stage{AMS_PREPARE_STAGE_IDLE};
  std::atomic<double> progress{0.0};
  std::atomic<bool> cancel_requested{false};

  std::mutex data_mutex;
  std::string result_json;
  std::string error_message;

  std::thread worker;
};

class PrepareManager {
 public:
  static PrepareManager& Instance();

  ams_code_t Start(std::shared_ptr<EngineContext> engine,
                   const PrepareConfig& config,
                   ams_prepare_t* out_prepare);

  ams_code_t Poll(ams_prepare_t task,
                  int32_t* out_state,
                  double* out_progress_0_1,
                  int32_t* out_stage);

  ams_code_t Cancel(ams_prepare_t task);
  ams_code_t GetResultJson(ams_prepare_t task, std::string* out_json);
  ams_code_t Destroy(ams_prepare_t task);

 private:
  PrepareManager() = default;

  static void RunPrepare(const std::shared_ptr<PrepareContext>& task);
  static std::string JoinPath(const std::string& dir, const std::string& file_name);

  std::shared_ptr<PrepareContext> FindLocked(ams_prepare_t task);

  std::mutex mutex_;
  ams_prepare_t next_handle_ = 1;
  std::unordered_map<ams_prepare_t, std::shared_ptr<PrepareContext>> tasks_;
};

}  // namespace ams
