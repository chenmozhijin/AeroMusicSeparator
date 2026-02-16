#include "engine_manager.h"

#include <cstdlib>
#include <exception>

#include "error_store.h"

namespace {

void SetEnvFlag(const char* key, const char* value) {
#ifdef _WIN32
  _putenv_s(key, value);
#else
  setenv(key, value, 1);
#endif
}

void UnsetEnvFlag(const char* key) {
#ifdef _WIN32
  _putenv_s(key, "");
#else
  unsetenv(key);
#endif
}

}  // namespace

namespace ams {

EngineManager& EngineManager::Instance() {
  static EngineManager manager;
  return manager;
}

void EngineManager::ApplyBackendPreference(int32_t backend_preference) {
  if (backend_preference == AMS_BACKEND_CPU) {
    SetEnvFlag("BSR_FORCE_CPU", "1");
    return;
  }

  // For non-CPU modes keep auto path by removing the force flag.
  UnsetEnvFlag("BSR_FORCE_CPU");
}

ams_code_t EngineManager::Open(const std::string& model_path,
                               int32_t backend_preference,
                               ams_engine_t* out_handle) {
  if (out_handle == nullptr || model_path.empty()) {
    SetLastError("invalid argument: model_path/out_handle");
    return AMS_ERR_INVALID_ARG;
  }

  try {
    ApplyBackendPreference(backend_preference);

    auto context = std::make_shared<EngineContext>();
    context->backend_preference = backend_preference;
    context->model_path = model_path;
    context->inference = std::make_unique<Inference>(model_path);

    std::lock_guard<std::mutex> lock(mutex_);
    context->handle = next_handle_++;
    engines_[context->handle] = context;
    *out_handle = context->handle;
    return AMS_OK;
  } catch (const std::exception& e) {
    SetLastError(std::string("failed to create engine: ") + e.what());
    return AMS_ERR_RUNTIME;
  }
}

std::shared_ptr<EngineContext> EngineManager::Find(ams_engine_t handle) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = engines_.find(handle);
  if (it == engines_.end()) {
    return nullptr;
  }
  return it->second;
}

ams_code_t EngineManager::Close(ams_engine_t handle) {
  if (handle == 0) {
    SetLastError("invalid argument: engine handle");
    return AMS_ERR_INVALID_ARG;
  }

  std::lock_guard<std::mutex> lock(mutex_);
  auto it = engines_.find(handle);
  if (it == engines_.end()) {
    SetLastError("engine not found");
    return AMS_ERR_NOT_FOUND;
  }
  engines_.erase(it);
  return AMS_OK;
}

}  // namespace ams
