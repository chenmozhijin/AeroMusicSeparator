#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace ams {

std::string BuildJobResultJson(const std::vector<std::string>& output_files,
                               const std::string& model_input_file,
                               const std::string& canonical_input_file,
                               int64_t inference_elapsed_ms);

std::string BuildPrepareResultJson(const std::string& canonical_input_file,
                                   int32_t sample_rate,
                                   int32_t channels,
                                   int64_t duration_ms);

}  // namespace ams
