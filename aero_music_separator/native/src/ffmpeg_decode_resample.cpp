#include "ffmpeg_decode_resample.h"

#include <algorithm>
#include <climits>
#include <cstdint>
#include <string>
#include <vector>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libswresample/swresample.h>
}

namespace {

struct InterruptContext {
  std::function<bool()>* cancel = nullptr;
};

int InterruptCallback(void* opaque) {
  auto* ctx = static_cast<InterruptContext*>(opaque);
  if (ctx == nullptr || ctx->cancel == nullptr) {
    return 0;
  }
  return (*ctx->cancel)() ? 1 : 0;
}

std::string AvErrToString(int errnum) {
  char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
  av_strerror(errnum, buffer, sizeof(buffer));
  return std::string(buffer);
}

void InitInputLayout(const AVCodecContext* codec_ctx, AVChannelLayout* in_layout) {
  if (codec_ctx != nullptr && codec_ctx->ch_layout.nb_channels > 0) {
    av_channel_layout_copy(in_layout, &codec_ctx->ch_layout);
    return;
  }
  av_channel_layout_default(in_layout, 2);
}

bool ConvertFrame(SwrContext* swr,
                  AVFrame* frame,
                  int output_sample_rate,
                  std::vector<float>* out_interleaved,
                  std::string* error_message) {
  const int out_channels = 2;
  const int64_t out_samples64 = av_rescale_rnd(
      swr_get_delay(swr, frame->sample_rate) + frame->nb_samples,
      output_sample_rate,
      frame->sample_rate,
      AV_ROUND_UP);
  const int out_samples = static_cast<int>(std::min<int64_t>(out_samples64, INT_MAX));

  if (out_samples <= 0) {
    return true;
  }

  std::vector<float> converted(static_cast<size_t>(out_samples) * out_channels);
  uint8_t* out_data[1] = {
      reinterpret_cast<uint8_t*>(converted.data()),
  };

  int converted_samples = swr_convert(
      swr,
      out_data,
      out_samples,
      const_cast<const uint8_t**>(frame->extended_data),
      frame->nb_samples);

  if (converted_samples < 0) {
    if (error_message != nullptr) {
      *error_message = "swr_convert failed: " + AvErrToString(converted_samples);
    }
    return false;
  }

  converted.resize(static_cast<size_t>(converted_samples) * out_channels);
  out_interleaved->insert(out_interleaved->end(), converted.begin(), converted.end());
  return true;
}

}  // namespace

namespace ams {

bool DecodeToStereoF32(const std::string& input_path,
                       int target_sample_rate,
                       std::vector<float>* out_interleaved,
                       std::function<bool()> cancel_requested,
                       std::function<void(double)> progress,
                       std::string* error_message) {
  if (out_interleaved == nullptr || input_path.empty() || target_sample_rate <= 0) {
    if (error_message != nullptr) {
      *error_message = "invalid decode arguments";
    }
    return false;
  }

  out_interleaved->clear();

  AVFormatContext* format_ctx = nullptr;
  AVCodecContext* codec_ctx = nullptr;
  SwrContext* swr_ctx = nullptr;
  AVPacket* packet = nullptr;
  AVFrame* frame = nullptr;
  AVChannelLayout in_layout = AV_CHANNEL_LAYOUT_STEREO;
  AVChannelLayout out_layout = AV_CHANNEL_LAYOUT_STEREO;

  int audio_stream_index = -1;
  bool ok = false;

  InterruptContext interrupt{&cancel_requested};

  do {
    format_ctx = avformat_alloc_context();
    if (format_ctx == nullptr) {
      if (error_message != nullptr) {
        *error_message = "avformat_alloc_context failed";
      }
      break;
    }

    format_ctx->interrupt_callback.callback = InterruptCallback;
    format_ctx->interrupt_callback.opaque = &interrupt;

    int ret = avformat_open_input(&format_ctx, input_path.c_str(), nullptr, nullptr);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avformat_open_input failed: " + AvErrToString(ret);
      }
      break;
    }

    ret = avformat_find_stream_info(format_ctx, nullptr);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avformat_find_stream_info failed: " + AvErrToString(ret);
      }
      break;
    }

    audio_stream_index = av_find_best_stream(format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_index < 0) {
      if (error_message != nullptr) {
        *error_message = "no audio stream found";
      }
      break;
    }

    AVStream* stream = format_ctx->streams[audio_stream_index];
    const AVCodecID codec_id = stream->codecpar->codec_id;
    const AVCodec* decoder = avcodec_find_decoder(codec_id);
    if (decoder == nullptr) {
      if (error_message != nullptr) {
        const char* codec_name = avcodec_get_name(codec_id);
        *error_message = "audio decoder not found for codec_id=" +
            std::to_string(static_cast<int>(codec_id)) + ", codec_name=" +
            (codec_name != nullptr ? std::string(codec_name) : "unknown");
      }
      break;
    }

    codec_ctx = avcodec_alloc_context3(decoder);
    if (codec_ctx == nullptr) {
      if (error_message != nullptr) {
        *error_message = "avcodec_alloc_context3 failed";
      }
      break;
    }

    ret = avcodec_parameters_to_context(codec_ctx, stream->codecpar);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avcodec_parameters_to_context failed: " + AvErrToString(ret);
      }
      break;
    }

    ret = avcodec_open2(codec_ctx, decoder, nullptr);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avcodec_open2 failed: " + AvErrToString(ret);
      }
      break;
    }

    InitInputLayout(codec_ctx, &in_layout);
    av_channel_layout_default(&out_layout, 2);

    ret = swr_alloc_set_opts2(
        &swr_ctx,
        &out_layout,
        AV_SAMPLE_FMT_FLT,
        target_sample_rate,
        &in_layout,
        codec_ctx->sample_fmt,
        codec_ctx->sample_rate,
        0,
        nullptr);
    if (ret < 0 || swr_ctx == nullptr) {
      if (error_message != nullptr) {
        *error_message = "swr_alloc_set_opts2 failed: " + AvErrToString(ret);
      }
      break;
    }

    ret = swr_init(swr_ctx);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "swr_init failed: " + AvErrToString(ret);
      }
      break;
    }

    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (packet == nullptr || frame == nullptr) {
      if (error_message != nullptr) {
        *error_message = "failed to allocate packet/frame";
      }
      break;
    }

    const int64_t duration = stream->duration;
    while ((ret = av_read_frame(format_ctx, packet)) >= 0) {
      if (cancel_requested()) {
        if (error_message != nullptr) {
          *error_message = "cancelled";
        }
        break;
      }

      if (packet->stream_index != audio_stream_index) {
        av_packet_unref(packet);
        continue;
      }

      ret = avcodec_send_packet(codec_ctx, packet);
      av_packet_unref(packet);

      if (ret < 0) {
        if (error_message != nullptr) {
          *error_message = "avcodec_send_packet failed: " + AvErrToString(ret);
        }
        break;
      }

      while ((ret = avcodec_receive_frame(codec_ctx, frame)) >= 0) {
        if (!ConvertFrame(
                swr_ctx,
                frame,
                target_sample_rate,
                out_interleaved,
                error_message)) {
          ret = AVERROR_EXTERNAL;
          break;
        }

        if (progress && duration > 0 && frame->pts != AV_NOPTS_VALUE) {
          double ratio = static_cast<double>(frame->pts) / static_cast<double>(duration);
          ratio = std::max(0.0, std::min(1.0, ratio));
          progress(ratio);
        }

        av_frame_unref(frame);
      }

      if (ret == AVERROR(EAGAIN)) {
        continue;
      }
      if (ret < 0 && ret != AVERROR_EOF) {
        if (error_message != nullptr && error_message->empty()) {
          *error_message = "avcodec_receive_frame failed: " + AvErrToString(ret);
        }
        break;
      }
      if (ret == AVERROR_EXTERNAL) {
        break;
      }
    }

    if (ret < 0 && ret != AVERROR_EOF && (error_message == nullptr || error_message->empty())) {
      if (error_message != nullptr) {
        *error_message = "av_read_frame failed: " + AvErrToString(ret);
      }
      break;
    }

    if (error_message != nullptr && *error_message == "cancelled") {
      break;
    }

    avcodec_send_packet(codec_ctx, nullptr);
    while ((ret = avcodec_receive_frame(codec_ctx, frame)) >= 0) {
      if (!ConvertFrame(
              swr_ctx,
              frame,
              target_sample_rate,
              out_interleaved,
              error_message)) {
        ret = AVERROR_EXTERNAL;
        break;
      }
      av_frame_unref(frame);
    }

    if (ret != AVERROR_EOF && ret != AVERROR(EAGAIN) && ret != AVERROR_EXTERNAL) {
      if (ret < 0 && error_message != nullptr && error_message->empty()) {
        *error_message = "decoder flush failed: " + AvErrToString(ret);
      }
    }

    if (cancel_requested()) {
      if (error_message != nullptr) {
        *error_message = "cancelled";
      }
      break;
    }

    if (progress) {
      progress(1.0);
    }
    ok = true;
  } while (false);

  if (frame != nullptr) {
    av_frame_free(&frame);
  }
  if (packet != nullptr) {
    av_packet_free(&packet);
  }
  if (swr_ctx != nullptr) {
    swr_free(&swr_ctx);
  }
  av_channel_layout_uninit(&in_layout);
  av_channel_layout_uninit(&out_layout);
  if (codec_ctx != nullptr) {
    avcodec_free_context(&codec_ctx);
  }
  if (format_ctx != nullptr) {
    avformat_close_input(&format_ctx);
  }

  return ok;
}

}  // namespace ams
