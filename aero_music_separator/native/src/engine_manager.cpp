#include "engine_manager.h"

#include <cstdlib>
#include <exception>
#include <iostream>

#if defined(__ANDROID__)
#include <android/log.h>
#endif

#include "error_store.h"

namespace {
constexpr const char* kGgmlDisableVulkan = "GGML_DISABLE_VULKAN";

const char* BackendPreferenceName(int32_t backend_preference) {
  switch (backend_preference) {
    case AMS_BACKEND_CPU:
      return "CPU";
    case AMS_BACKEND_AUTO:
      return "Auto";
    case AMS_BACKEND_VULKAN:
      return "Vulkan";
    case AMS_BACKEND_CUDA:
      return "CUDA";
    case AMS_BACKEND_METAL:
      return "Metal";
    default:
      return "Unknown";
  }
}

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

void LogBackendPolicy(const char* policy) {
#if defined(__ANDROID__)
  __android_log_print(
      ANDROID_LOG_INFO, "AeroSeparatorFFI", "backend policy: %s", policy);
#else
  std::cout << "[AeroSeparatorFFI] backend policy: " << policy << std::endl;
#endif
}

}  // namespace

namespace ams {

EngineManager& EngineManager::Instance() {
  static EngineManager manager;
  return manager;
}

void EngineManager::ApplyBackendPreference(int32_t backend_preference) {
#if defined(__ANDROID__)
  SetEnvFlag("BSR_FORCE_CPU", "1");
  SetEnvFlag(kGgmlDisableVulkan, "1");
  const std::string policy =
      std::string("AndroidCPUOnly(request=") +
      BackendPreferenceName(backend_preference) + ")";
  LogBackendPolicy(policy.c_str());
#else

  const bool force_cpu = backend_preference == AMS_BACKEND_CPU;
  if (force_cpu) {
    SetEnvFlag("BSR_FORCE_CPU", "1");
  } else {
    // For non-CPU modes keep auto path by removing the force flag.
    UnsetEnvFlag("BSR_FORCE_CPU");
  }

  const char* policy = "Auto";
  switch (backend_preference) {
    case AMS_BACKEND_CPU:
      policy = "CPU";
      break;
    case AMS_BACKEND_AUTO:
      policy = "Auto";
      break;
    case AMS_BACKEND_VULKAN:
      policy = "Vulkan";
      break;
    case AMS_BACKEND_CUDA:
      policy = "CUDA";
      break;
    case AMS_BACKEND_METAL:
      policy = "Metal";
      break;
    default:
      policy = "Auto";
      break;
  }
  LogBackendPolicy(policy);
#endif
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
