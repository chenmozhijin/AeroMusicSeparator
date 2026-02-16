#pragma once

#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

#include "ams_ffi.h"
#include "bs_roformer/inference.h"

namespace ams {

struct EngineContext {
  ams_engine_t handle = 0;
  int32_t backend_preference = AMS_BACKEND_AUTO;
  std::string model_path;
  std::unique_ptr<Inference> inference;
};

class EngineManager {
 public:
  static EngineManager& Instance();

  ams_code_t Open(const std::string& model_path,
                  int32_t backend_preference,
                  ams_engine_t* out_handle);

  std::shared_ptr<EngineContext> Find(ams_engine_t handle);
  ams_code_t Close(ams_engine_t handle);

 private:
  EngineManager() = default;

  void ApplyBackendPreference(int32_t backend_preference);

  std::mutex mutex_;
  ams_engine_t next_handle_ = 1;
  std::unordered_map<ams_engine_t, std::shared_ptr<EngineContext>> engines_;
};

}  // namespace ams
