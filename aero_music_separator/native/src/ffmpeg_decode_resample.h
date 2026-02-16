#pragma once

#include <functional>
#include <string>
#include <vector>

namespace ams {

bool DecodeToStereoF32(const std::string& input_path,
                       int target_sample_rate,
                       std::vector<float>* out_interleaved,
                       std::function<bool()> cancel_requested,
                       std::function<void(double)> progress,
                       std::string* error_message);

}  // namespace ams
