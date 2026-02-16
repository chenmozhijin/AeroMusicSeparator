#include "ffmpeg_encode.h"

#include <algorithm>
#include <cstdint>
#include <string>
#include <utility>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libswresample/swresample.h>
}

namespace {

struct EncodeConfig {
  AVCodecID codec_id = AV_CODEC_ID_NONE;
  const char* muxer_name = nullptr;
  bool apply_mp3_defaults = false;
  AVSampleFormat forced_sample_format = AV_SAMPLE_FMT_NONE;
};

std::string AvErrToString(int errnum) {
  char buffer[AV_ERROR_MAX_STRING_SIZE] = {0};
  av_strerror(errnum, buffer, sizeof(buffer));
  return std::string(buffer);
}

AVSampleFormat SelectOutputSampleFormat(const AVCodec* codec) {
  if (codec == nullptr || codec->sample_fmts == nullptr) {
    return AV_SAMPLE_FMT_FLTP;
  }

  const AVSampleFormat preferred[] = {
      AV_SAMPLE_FMT_FLTP,
      AV_SAMPLE_FMT_FLT,
      AV_SAMPLE_FMT_S16P,
      AV_SAMPLE_FMT_S16,
  };

  for (AVSampleFormat wanted : preferred) {
    for (const AVSampleFormat* fmt = codec->sample_fmts; *fmt != AV_SAMPLE_FMT_NONE; ++fmt) {
      if (*fmt == wanted) {
        return wanted;
      }
    }
  }

  return codec->sample_fmts[0];
}

void SetupStereoLayout(AVCodecContext* codec_ctx) {
#if LIBAVUTIL_VERSION_MAJOR >= 57
  av_channel_layout_default(&codec_ctx->ch_layout, 2);
#else
  codec_ctx->channel_layout = AV_CH_LAYOUT_STEREO;
  codec_ctx->channels = 2;
#endif
}

void SetupFrameLayout(AVFrame* frame, const AVCodecContext* codec_ctx) {
#if LIBAVUTIL_VERSION_MAJOR >= 57
  av_channel_layout_copy(&frame->ch_layout, &codec_ctx->ch_layout);
#else
  frame->channel_layout = codec_ctx->channel_layout;
#endif
}

void InitStereoLayout(AVChannelLayout* layout) {
  av_channel_layout_default(layout, 2);
}

int SendFrameAndWritePackets(AVCodecContext* codec_ctx,
                             AVFormatContext* format_ctx,
                             AVFrame* frame,
                             std::string* error_message) {
  int ret = avcodec_send_frame(codec_ctx, frame);
  if (ret < 0) {
    if (error_message != nullptr) {
      *error_message = "avcodec_send_frame failed: " + AvErrToString(ret);
    }
    return ret;
  }

  AVPacket* packet = av_packet_alloc();
  if (packet == nullptr) {
    if (error_message != nullptr) {
      *error_message = "av_packet_alloc failed";
    }
    return AVERROR(ENOMEM);
  }

  while ((ret = avcodec_receive_packet(codec_ctx, packet)) >= 0) {
    av_packet_rescale_ts(packet, codec_ctx->time_base, format_ctx->streams[0]->time_base);
    packet->stream_index = 0;
    ret = av_interleaved_write_frame(format_ctx, packet);
    av_packet_unref(packet);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "av_interleaved_write_frame failed: " + AvErrToString(ret);
      }
      av_packet_free(&packet);
      return ret;
    }
  }

  av_packet_free(&packet);
  if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
    return 0;
  }
  if (ret < 0) {
    if (error_message != nullptr) {
      *error_message = "avcodec_receive_packet failed: " + AvErrToString(ret);
    }
    return ret;
  }
  return 0;
}

bool EncodeToFile(const std::string& output_path,
                  const std::vector<float>& interleaved_audio,
                  int sample_rate,
                  const EncodeConfig& config,
                  std::function<bool()> cancel_requested,
                  std::function<void(double)> progress,
                  std::string* error_message) {
  if (output_path.empty() || sample_rate <= 0 || interleaved_audio.size() % 2 != 0 ||
      config.codec_id == AV_CODEC_ID_NONE || config.muxer_name == nullptr) {
    if (error_message != nullptr) {
      *error_message = "invalid encoder arguments";
    }
    return false;
  }

  AVFormatContext* format_ctx = nullptr;
  AVCodecContext* codec_ctx = nullptr;
  SwrContext* swr_ctx = nullptr;
  AVFrame* frame = nullptr;
  AVChannelLayout in_layout = AV_CHANNEL_LAYOUT_STEREO;
  AVChannelLayout out_layout = AV_CHANNEL_LAYOUT_STEREO;
  bool ok = false;

  do {
    int ret =
        avformat_alloc_output_context2(&format_ctx, nullptr, config.muxer_name, output_path.c_str());
    if (ret < 0 || format_ctx == nullptr) {
      if (error_message != nullptr) {
        *error_message = "avformat_alloc_output_context2 failed: " + AvErrToString(ret);
      }
      break;
    }

    const AVCodec* codec = avcodec_find_encoder(config.codec_id);
    if (codec == nullptr) {
      if (error_message != nullptr) {
        *error_message = "encoder not found for requested output format";
      }
      break;
    }

    AVStream* stream = avformat_new_stream(format_ctx, codec);
    if (stream == nullptr) {
      if (error_message != nullptr) {
        *error_message = "avformat_new_stream failed";
      }
      break;
    }

    codec_ctx = avcodec_alloc_context3(codec);
    if (codec_ctx == nullptr) {
      if (error_message != nullptr) {
        *error_message = "avcodec_alloc_context3 failed";
      }
      break;
    }

    codec_ctx->sample_rate = sample_rate;
    SetupStereoLayout(codec_ctx);
    codec_ctx->time_base = AVRational{1, sample_rate};
    codec_ctx->sample_fmt = config.forced_sample_format == AV_SAMPLE_FMT_NONE
                                ? SelectOutputSampleFormat(codec)
                                : config.forced_sample_format;

    if (config.apply_mp3_defaults) {
      codec_ctx->bit_rate = 192000;
    }

    if (format_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
      codec_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    ret = avcodec_open2(codec_ctx, codec, nullptr);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avcodec_open2 failed: " + AvErrToString(ret);
      }
      break;
    }

    ret = avcodec_parameters_from_context(stream->codecpar, codec_ctx);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avcodec_parameters_from_context failed: " + AvErrToString(ret);
      }
      break;
    }
    stream->time_base = codec_ctx->time_base;

    if (!(format_ctx->oformat->flags & AVFMT_NOFILE)) {
      ret = avio_open(&format_ctx->pb, output_path.c_str(), AVIO_FLAG_WRITE);
      if (ret < 0) {
        if (error_message != nullptr) {
          *error_message = "avio_open failed: " + AvErrToString(ret);
        }
        break;
      }
    }

    ret = avformat_write_header(format_ctx, nullptr);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "avformat_write_header failed: " + AvErrToString(ret);
      }
      break;
    }

    av_channel_layout_copy(&out_layout, &codec_ctx->ch_layout);
    InitStereoLayout(&in_layout);
    ret = swr_alloc_set_opts2(
        &swr_ctx,
        &out_layout,
        codec_ctx->sample_fmt,
        codec_ctx->sample_rate,
        &in_layout,
        AV_SAMPLE_FMT_FLT,
        sample_rate,
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

    const int total_samples = static_cast<int>(interleaved_audio.size() / 2);
    const int frame_size = codec_ctx->frame_size > 0 ? codec_ctx->frame_size : 1024;
    int input_offset = 0;
    int64_t next_pts = 0;

    while (input_offset < total_samples || swr_get_delay(swr_ctx, sample_rate) > 0) {
      if (cancel_requested()) {
        if (error_message != nullptr) {
          *error_message = "cancelled";
        }
        break;
      }

      const int remaining = total_samples - input_offset;
      const int in_samples = remaining > 0 ? std::min(frame_size, remaining) : 0;

      frame = av_frame_alloc();
      if (frame == nullptr) {
        if (error_message != nullptr) {
          *error_message = "av_frame_alloc failed";
        }
        break;
      }

      frame->nb_samples = frame_size;
      SetupFrameLayout(frame, codec_ctx);
      frame->format = codec_ctx->sample_fmt;
      frame->sample_rate = codec_ctx->sample_rate;

      ret = av_frame_get_buffer(frame, 0);
      if (ret < 0) {
        if (error_message != nullptr) {
          *error_message = "av_frame_get_buffer failed: " + AvErrToString(ret);
        }
        break;
      }

      const uint8_t* in_data[1] = {nullptr};
      if (in_samples > 0) {
        in_data[0] = reinterpret_cast<const uint8_t*>(interleaved_audio.data() + (input_offset * 2));
      }

      const int converted = swr_convert(
          swr_ctx,
          frame->data,
          frame->nb_samples,
          in_samples > 0 ? in_data : nullptr,
          in_samples);

      if (converted < 0) {
        if (error_message != nullptr) {
          *error_message = "swr_convert failed: " + AvErrToString(converted);
        }
        break;
      }

      if (converted == 0 && in_samples == 0) {
        av_frame_free(&frame);
        frame = nullptr;
        break;
      }

      frame->nb_samples = converted;
      frame->pts = next_pts;
      next_pts += converted;

      ret = SendFrameAndWritePackets(codec_ctx, format_ctx, frame, error_message);
      av_frame_free(&frame);
      frame = nullptr;
      if (ret < 0) {
        break;
      }

      input_offset += in_samples;
      if (progress) {
        const double p = total_samples > 0
                             ? static_cast<double>(input_offset) / static_cast<double>(total_samples)
                             : 1.0;
        progress(std::max(0.0, std::min(1.0, p)));
      }
    }

    if (error_message != nullptr && *error_message == "cancelled") {
      break;
    }

    if (error_message == nullptr || error_message->empty()) {
      ret = SendFrameAndWritePackets(codec_ctx, format_ctx, nullptr, error_message);
      if (ret < 0) {
        break;
      }
    }

    ret = av_write_trailer(format_ctx);
    if (ret < 0) {
      if (error_message != nullptr) {
        *error_message = "av_write_trailer failed: " + AvErrToString(ret);
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
  if (swr_ctx != nullptr) {
    swr_free(&swr_ctx);
  }
  av_channel_layout_uninit(&in_layout);
  av_channel_layout_uninit(&out_layout);
  if (codec_ctx != nullptr) {
    avcodec_free_context(&codec_ctx);
  }
  if (format_ctx != nullptr) {
    if (!(format_ctx->oformat->flags & AVFMT_NOFILE) && format_ctx->pb != nullptr) {
      avio_closep(&format_ctx->pb);
    }
    avformat_free_context(format_ctx);
  }

  return ok;
}

EncodeConfig ConfigForOutputFormat(int32_t output_format) {
  switch (output_format) {
    case AMS_OUTPUT_WAV:
      return EncodeConfig{AV_CODEC_ID_PCM_F32LE, "wav", false, AV_SAMPLE_FMT_NONE};
    case AMS_OUTPUT_FLAC:
      return EncodeConfig{AV_CODEC_ID_FLAC, "flac", false, AV_SAMPLE_FMT_NONE};
    case AMS_OUTPUT_MP3:
      return EncodeConfig{AV_CODEC_ID_MP3, "mp3", true, AV_SAMPLE_FMT_NONE};
    default:
      return EncodeConfig{};
  }
}

}  // namespace

namespace ams {

const char* OutputFormatExtension(int32_t output_format) {
  switch (output_format) {
    case AMS_OUTPUT_WAV:
      return "wav";
    case AMS_OUTPUT_FLAC:
      return "flac";
    case AMS_OUTPUT_MP3:
      return "mp3";
    default:
      return "wav";
  }
}

bool EncodeFromStereoF32(const std::string& output_path,
                         const std::vector<float>& interleaved_audio,
                         int sample_rate,
                         int32_t output_format,
                         std::function<bool()> cancel_requested,
                         std::function<void(double)> progress,
                         std::string* error_message) {
  const EncodeConfig config = ConfigForOutputFormat(output_format);
  if (config.codec_id == AV_CODEC_ID_NONE) {
    if (error_message != nullptr) {
      *error_message = "unsupported output format";
    }
    return false;
  }

  return EncodeToFile(
      output_path,
      interleaved_audio,
      sample_rate,
      config,
      std::move(cancel_requested),
      std::move(progress),
      error_message);
}

bool WriteCanonicalInputWavPcm16(const std::string& output_path,
                                 const std::vector<float>& interleaved_audio,
                                 int sample_rate,
                                 std::function<bool()> cancel_requested,
                                 std::function<void(double)> progress,
                                 std::string* error_message) {
  const EncodeConfig config{
      AV_CODEC_ID_PCM_S16LE,
      "wav",
      false,
      AV_SAMPLE_FMT_S16,
  };
  return EncodeToFile(
      output_path,
      interleaved_audio,
      sample_rate,
      config,
      std::move(cancel_requested),
      std::move(progress),
      error_message);
}

}  // namespace ams
