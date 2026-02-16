#include "prepare_manager.h"

#include <algorithm>
#include <exception>
#include <filesystem>
#include <utility>
#include <vector>

#include "error_store.h"
#include "ffmpeg_decode_resample.h"
#include "ffmpeg_encode.h"
#include "json_result.h"

namespace {

constexpr const char* kCancelledMessage = "cancelled";
constexpr int kCanonicalSampleRate = 44100;
constexpr int kCanonicalChannels = 2;

bool IsCancelledMessage(const std::string& message) {
  return message == kCancelledMessage;
}

}  // namespace

namespace ams {

PrepareManager& PrepareManager::Instance() {
  static PrepareManager manager;
  return manager;
}

std::string PrepareManager::JoinPath(const std::string& dir, const std::string& file_name) {
  std::filesystem::path path(dir);
  path /= file_name;
  return path.string();
}

std::shared_ptr<PrepareContext> PrepareManager::FindLocked(ams_prepare_t task) {
  auto it = tasks_.find(task);
  if (it == tasks_.end()) {
    return nullptr;
  }
  return it->second;
}

ams_code_t PrepareManager::Start(std::shared_ptr<EngineContext> engine,
                                 const PrepareConfig& config,
                                 ams_prepare_t* out_prepare) {
  if (out_prepare == nullptr || config.input_path.empty() || config.work_dir.empty()) {
    SetLastError("invalid argument: start prepare");
    return AMS_ERR_INVALID_ARG;
  }

  auto task = std::make_shared<PrepareContext>();
  task->engine = std::move(engine);
  task->config = config;

  {
    std::lock_guard<std::mutex> lock(mutex_);
    task->handle = next_handle_++;
    tasks_[task->handle] = task;
  }

  try {
    task->worker = std::thread([task]() { RunPrepare(task); });
  } catch (const std::exception& e) {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks_.erase(task->handle);
    SetLastError(std::string("failed to start prepare worker thread: ") + e.what());
    return AMS_ERR_RUNTIME;
  } catch (...) {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks_.erase(task->handle);
    SetLastError("failed to start prepare worker thread: unknown exception");
    return AMS_ERR_RUNTIME;
  }

  *out_prepare = task->handle;
  return AMS_OK;
}

void PrepareManager::RunPrepare(const std::shared_ptr<PrepareContext>& task) {
  task->state.store(AMS_JOB_RUNNING, std::memory_order_release);

  auto should_cancel = [&]() -> bool {
    return task->cancel_requested.load(std::memory_order_acquire);
  };

  auto set_progress = [&](double value, int32_t stage) {
    const double clamped = std::max(0.0, std::min(1.0, value));
    task->stage.store(stage, std::memory_order_release);
    task->progress.store(clamped, std::memory_order_release);
  };

  auto finish_with_error = [&](int32_t state, const std::string& message) {
    {
      std::lock_guard<std::mutex> lock(task->data_mutex);
      task->error_message = message;
    }
    task->state.store(state, std::memory_order_release);
  };

  try {
    std::filesystem::create_directories(task->config.work_dir);

    std::vector<float> decoded_audio;
    std::string decode_error;

    set_progress(0.0, AMS_PREPARE_STAGE_DECODE);
    const bool decoded = DecodeToStereoF32(
        task->config.input_path,
        kCanonicalSampleRate,
        &decoded_audio,
        should_cancel,
        [&](double p) { set_progress(0.75 * p, AMS_PREPARE_STAGE_DECODE); },
        &decode_error);

    if (!decoded) {
      if (should_cancel() || IsCancelledMessage(decode_error)) {
        finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      } else {
        finish_with_error(AMS_JOB_FAILED, decode_error.empty() ? "prepare decode failed" : decode_error);
      }
      return;
    }

    if (should_cancel()) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      return;
    }

    set_progress(0.75, AMS_PREPARE_STAGE_RESAMPLE);

    std::string output_prefix = task->config.output_prefix;
    if (output_prefix.empty()) {
      output_prefix = "canonical_input";
    } else {
      output_prefix += "_canonical_input";
    }
    const std::string canonical_path = JoinPath(task->config.work_dir, output_prefix + ".wav");

    std::string encode_error;
    set_progress(0.76, AMS_PREPARE_STAGE_WRITE_CANONICAL);
    const bool written = WriteCanonicalInputWavPcm16(
        canonical_path,
        decoded_audio,
        kCanonicalSampleRate,
        should_cancel,
        [&](double p) { set_progress(0.76 + 0.24 * p, AMS_PREPARE_STAGE_WRITE_CANONICAL); },
        &encode_error);

    if (!written) {
      if (should_cancel() || IsCancelledMessage(encode_error)) {
        finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      } else {
        finish_with_error(AMS_JOB_FAILED, encode_error.empty() ? "prepare write failed" : encode_error);
      }
      return;
    }

    if (should_cancel()) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      return;
    }

    const int64_t frames = static_cast<int64_t>(decoded_audio.size() / kCanonicalChannels);
    const int64_t duration_ms = frames * 1000 / kCanonicalSampleRate;

    {
      std::lock_guard<std::mutex> lock(task->data_mutex);
      task->result_json = BuildPrepareResultJson(
          canonical_path,
          kCanonicalSampleRate,
          kCanonicalChannels,
          duration_ms);
      task->error_message.clear();
    }

    set_progress(1.0, AMS_PREPARE_STAGE_DONE);
    task->state.store(AMS_JOB_SUCCEEDED, std::memory_order_release);
  } catch (const std::exception& e) {
    if (should_cancel() || IsCancelledMessage(e.what())) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
    } else {
      finish_with_error(AMS_JOB_FAILED, std::string("prepare exception: ") + e.what());
    }
  }
}

ams_code_t PrepareManager::Poll(ams_prepare_t task,
                                int32_t* out_state,
                                double* out_progress_0_1,
                                int32_t* out_stage) {
  if (out_state == nullptr || out_progress_0_1 == nullptr || out_stage == nullptr) {
    SetLastError("invalid argument: prepare poll");
    return AMS_ERR_INVALID_ARG;
  }

  std::shared_ptr<PrepareContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(task);
  }
  if (ctx == nullptr) {
    SetLastError("prepare task not found");
    return AMS_ERR_NOT_FOUND;
  }

  *out_state = ctx->state.load(std::memory_order_acquire);
  *out_progress_0_1 = ctx->progress.load(std::memory_order_acquire);
  *out_stage = ctx->stage.load(std::memory_order_acquire);
  return AMS_OK;
}

ams_code_t PrepareManager::Cancel(ams_prepare_t task) {
  std::shared_ptr<PrepareContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(task);
  }
  if (ctx == nullptr) {
    SetLastError("prepare task not found");
    return AMS_ERR_NOT_FOUND;
  }

  ctx->cancel_requested.store(true, std::memory_order_release);
  return AMS_OK;
}

ams_code_t PrepareManager::GetResultJson(ams_prepare_t task, std::string* out_json) {
  if (out_json == nullptr) {
    SetLastError("invalid argument: prepare result output");
    return AMS_ERR_INVALID_ARG;
  }

  std::shared_ptr<PrepareContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(task);
  }
  if (ctx == nullptr) {
    SetLastError("prepare task not found");
    return AMS_ERR_NOT_FOUND;
  }

  const int32_t state = ctx->state.load(std::memory_order_acquire);
  std::lock_guard<std::mutex> lock(ctx->data_mutex);

  if (state == AMS_JOB_SUCCEEDED) {
    *out_json = ctx->result_json;
    return AMS_OK;
  }
  if (state == AMS_JOB_CANCELLED) {
    SetLastError(ctx->error_message.empty() ? kCancelledMessage : ctx->error_message);
    return AMS_ERR_CANCELLED;
  }
  if (state == AMS_JOB_FAILED) {
    SetLastError(ctx->error_message.empty() ? "prepare failed" : ctx->error_message);
    return AMS_ERR_RUNTIME;
  }

  SetLastError("prepare task is not completed yet");
  return AMS_ERR_RUNTIME;
}

ams_code_t PrepareManager::Destroy(ams_prepare_t task) {
  std::shared_ptr<PrepareContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = tasks_.find(task);
    if (it == tasks_.end()) {
      SetLastError("prepare task not found");
      return AMS_ERR_NOT_FOUND;
    }
    ctx = it->second;
    tasks_.erase(it);
  }

  ctx->cancel_requested.store(true, std::memory_order_release);
  if (ctx->worker.joinable()) {
    ctx->worker.join();
  }
  return AMS_OK;
}

}  // namespace ams
