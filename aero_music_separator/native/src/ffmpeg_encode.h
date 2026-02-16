#pragma once

#include <functional>
#include <string>
#include <vector>

#include "ams_ffi.h"

namespace ams {

bool EncodeFromStereoF32(const std::string& output_path,
                         const std::vector<float>& interleaved_audio,
                         int sample_rate,
                         int32_t output_format,
                         std::function<bool()> cancel_requested,
                         std::function<void(double)> progress,
                         std::string* error_message);

bool WriteCanonicalInputWavPcm16(const std::string& output_path,
                                 const std::vector<float>& interleaved_audio,
                                 int sample_rate,
                                 std::function<bool()> cancel_requested,
                                 std::function<void(double)> progress,
                                 std::string* error_message);

const char* OutputFormatExtension(int32_t output_format);

}  // namespace ams
