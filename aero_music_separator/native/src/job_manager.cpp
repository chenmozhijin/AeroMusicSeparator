#include "job_manager.h"

#include <algorithm>
#include <chrono>
#include <exception>
#include <filesystem>
#include <sstream>
#include <utility>
#include <vector>

#include "error_store.h"
#include "ffmpeg_decode_resample.h"
#include "ffmpeg_encode.h"
#include "json_result.h"

namespace {

constexpr const char* kCancelledMessage = "cancelled";

bool IsCancelledMessage(const std::string& message) {
  return message == kCancelledMessage || message == "Inference cancelled";
}

}  // namespace

namespace ams {

JobManager& JobManager::Instance() {
  static JobManager manager;
  return manager;
}

std::string JobManager::JoinPath(const std::string& dir, const std::string& file_name) {
  std::filesystem::path path(dir);
  path /= file_name;
  return path.string();
}

std::shared_ptr<JobContext> JobManager::FindLocked(ams_job_t job) {
  auto it = jobs_.find(job);
  if (it == jobs_.end()) {
    return nullptr;
  }
  return it->second;
}

ams_code_t JobManager::Start(std::shared_ptr<EngineContext> engine,
                             const JobConfig& config,
                             ams_job_t* out_job) {
  const bool has_source_input = !config.input_path.empty();
  const bool has_prepared_input = !config.prepared_input_path.empty();
  if (engine == nullptr || out_job == nullptr || (!has_source_input && !has_prepared_input) ||
      config.output_dir.empty()) {
    SetLastError("invalid argument: start job");
    return AMS_ERR_INVALID_ARG;
  }

  auto job = std::make_shared<JobContext>();
  job->engine = std::move(engine);
  job->config = config;

  {
    std::lock_guard<std::mutex> lock(mutex_);
    job->handle = next_handle_++;
    jobs_[job->handle] = job;
  }

  try {
    job->worker = std::thread([job]() { RunJob(job); });
  } catch (const std::exception& e) {
    std::lock_guard<std::mutex> lock(mutex_);
    jobs_.erase(job->handle);
    SetLastError(std::string("failed to start job worker thread: ") + e.what());
    return AMS_ERR_RUNTIME;
  } catch (...) {
    std::lock_guard<std::mutex> lock(mutex_);
    jobs_.erase(job->handle);
    SetLastError("failed to start job worker thread: unknown exception");
    return AMS_ERR_RUNTIME;
  }

  *out_job = job->handle;
  return AMS_OK;
}

void JobManager::RunJob(const std::shared_ptr<JobContext>& job) {
  job->state.store(AMS_JOB_RUNNING, std::memory_order_release);

  auto should_cancel = [&]() -> bool {
    return job->cancel_requested.load(std::memory_order_acquire);
  };

  auto set_progress = [&](double value, int32_t stage) {
    const double clamped = std::max(0.0, std::min(1.0, value));
    job->stage.store(stage, std::memory_order_release);
    job->progress.store(clamped, std::memory_order_release);
  };

  auto finish_with_error = [&](int32_t state, const std::string& message) {
    {
      std::lock_guard<std::mutex> lock(job->data_mutex);
      job->error_message = message;
    }
    job->state.store(state, std::memory_order_release);
  };

  try {
    std::filesystem::create_directories(job->config.output_dir);

    const int sample_rate = job->engine->inference->GetSampleRate();
    const std::string model_input_path = job->config.prepared_input_path.empty()
                                             ? job->config.input_path
                                             : job->config.prepared_input_path;
    std::vector<float> input_audio;
    std::string ffmpeg_error;

    set_progress(0.0, AMS_STAGE_DECODE);
    const bool decoded = DecodeToStereoF32(
        model_input_path,
        sample_rate,
        &input_audio,
        should_cancel,
        [&](double p) { set_progress(0.15 * p, AMS_STAGE_DECODE); },
        &ffmpeg_error);

    if (!decoded) {
      if (should_cancel() || IsCancelledMessage(ffmpeg_error)) {
        finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      } else {
        finish_with_error(AMS_JOB_FAILED, ffmpeg_error.empty() ? "decode failed" : ffmpeg_error);
      }
      return;
    }

    if (should_cancel()) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      return;
    }

    int chunk_size = job->config.chunk_size;
    int overlap = job->config.overlap;
    if (chunk_size <= 0) {
      chunk_size = job->engine->inference->GetDefaultChunkSize();
    }
    if (overlap <= 0) {
      overlap = job->engine->inference->GetDefaultNumOverlap();
    }

    set_progress(0.15, AMS_STAGE_INFER);
    const auto inference_begin = std::chrono::steady_clock::now();
    const auto stems = job->engine->inference->Process(
        input_audio,
        chunk_size,
        overlap,
        [&](float p) { set_progress(0.15 + 0.75 * p, AMS_STAGE_INFER); },
        should_cancel);
    const auto inference_end = std::chrono::steady_clock::now();
    const int64_t inference_elapsed_ms =
        std::chrono::duration_cast<std::chrono::milliseconds>(inference_end - inference_begin)
            .count();

    if (should_cancel()) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
      return;
    }

    if (stems.empty()) {
      finish_with_error(AMS_JOB_FAILED, "inference produced no stems");
      return;
    }

    set_progress(0.90, AMS_STAGE_ENCODE);
    const std::string prefix = job->config.output_prefix.empty() ? "separated" : job->config.output_prefix;
    const char* extension = OutputFormatExtension(job->config.output_format);

    std::vector<std::string> output_files;
    output_files.reserve(stems.size());

    for (size_t i = 0; i < stems.size(); ++i) {
      if (should_cancel()) {
        finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
        return;
      }

      std::ostringstream filename;
      filename << prefix << "_stem_" << i << "." << extension;
      const std::string output_path = JoinPath(job->config.output_dir, filename.str());

      std::string encode_error;
      const double segment_begin = 0.90 + (0.10 * static_cast<double>(i) / stems.size());
      const double segment_size = 0.10 / stems.size();

      const bool encoded = EncodeFromStereoF32(
          output_path,
          stems[i],
          sample_rate,
          job->config.output_format,
          should_cancel,
          [&](double p) { set_progress(segment_begin + segment_size * p, AMS_STAGE_ENCODE); },
          &encode_error);

      if (!encoded) {
        if (should_cancel() || IsCancelledMessage(encode_error)) {
          finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
        } else {
          finish_with_error(AMS_JOB_FAILED, encode_error.empty() ? "encode failed" : encode_error);
        }
        return;
      }

      output_files.push_back(output_path);
    }

    {
      std::lock_guard<std::mutex> lock(job->data_mutex);
      const std::string canonical_input_file = job->config.prepared_input_path.empty()
                                                   ? std::string()
                                                   : job->config.prepared_input_path;
      job->result_json = BuildJobResultJson(
          output_files, model_input_path, canonical_input_file, inference_elapsed_ms);
      job->error_message.clear();
    }

    set_progress(1.0, AMS_STAGE_DONE);
    job->state.store(AMS_JOB_SUCCEEDED, std::memory_order_release);
  } catch (const std::exception& e) {
    if (should_cancel() || IsCancelledMessage(e.what())) {
      finish_with_error(AMS_JOB_CANCELLED, kCancelledMessage);
    } else {
      finish_with_error(AMS_JOB_FAILED, std::string("job exception: ") + e.what());
    }
  }
}

ams_code_t JobManager::Poll(ams_job_t job,
                            int32_t* out_state,
                            double* out_progress_0_1,
                            int32_t* out_stage) {
  if (out_state == nullptr || out_progress_0_1 == nullptr || out_stage == nullptr) {
    SetLastError("invalid argument: poll");
    return AMS_ERR_INVALID_ARG;
  }

  std::shared_ptr<JobContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(job);
  }
  if (ctx == nullptr) {
    SetLastError("job not found");
    return AMS_ERR_NOT_FOUND;
  }

  *out_state = ctx->state.load(std::memory_order_acquire);
  *out_progress_0_1 = ctx->progress.load(std::memory_order_acquire);
  *out_stage = ctx->stage.load(std::memory_order_acquire);
  return AMS_OK;
}

ams_code_t JobManager::Cancel(ams_job_t job) {
  std::shared_ptr<JobContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(job);
  }
  if (ctx == nullptr) {
    SetLastError("job not found");
    return AMS_ERR_NOT_FOUND;
  }

  ctx->cancel_requested.store(true, std::memory_order_release);
  return AMS_OK;
}

ams_code_t JobManager::GetResultJson(ams_job_t job, std::string* out_json) {
  if (out_json == nullptr) {
    SetLastError("invalid argument: result output");
    return AMS_ERR_INVALID_ARG;
  }

  std::shared_ptr<JobContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ctx = FindLocked(job);
  }
  if (ctx == nullptr) {
    SetLastError("job not found");
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
    SetLastError(ctx->error_message.empty() ? "job failed" : ctx->error_message);
    return AMS_ERR_RUNTIME;
  }

  SetLastError("job is not completed yet");
  return AMS_ERR_RUNTIME;
}

ams_code_t JobManager::Destroy(ams_job_t job) {
  std::shared_ptr<JobContext> ctx;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = jobs_.find(job);
    if (it == jobs_.end()) {
      SetLastError("job not found");
      return AMS_ERR_NOT_FOUND;
    }
    ctx = it->second;
    jobs_.erase(it);
  }

  ctx->cancel_requested.store(true, std::memory_order_release);
  if (ctx->worker.joinable()) {
    ctx->worker.join();
  }
  return AMS_OK;
}

}  // namespace ams
