#include "json_result.h"

#include <sstream>

namespace {

std::string EscapeJson(const std::string& value) {
  std::string out;
  out.reserve(value.size() + 8);
  for (char c : value) {
    switch (c) {
      case '\\':
        out += "\\\\";
        break;
      case '"':
        out += "\\\"";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        out.push_back(c);
        break;
    }
  }
  return out;
}

void AppendJsonStringField(std::ostringstream& oss, const char* key, const std::string& value) {
  oss << '"' << key << "\":\"" << EscapeJson(value) << '"';
}

}  // namespace

namespace ams {

std::string BuildJobResultJson(const std::vector<std::string>& output_files,
                               const std::string& model_input_file,
                               const std::string& canonical_input_file,
                               int64_t inference_elapsed_ms) {
  std::ostringstream oss;
  oss << '{';
  AppendJsonStringField(oss, "model_input_file", model_input_file);
  oss << ',';
  AppendJsonStringField(
      oss,
      "canonical_input_file",
      canonical_input_file.empty() ? model_input_file : canonical_input_file);
  oss << ",\"files\":[";
  for (size_t i = 0; i < output_files.size(); ++i) {
    if (i > 0) {
      oss << ',';
    }
    oss << '"' << EscapeJson(output_files[i]) << '"';
  }
  oss << "],\"inference_elapsed_ms\":" << inference_elapsed_ms << '}';
  return oss.str();
}

std::string BuildPrepareResultJson(const std::string& canonical_input_file,
                                   int32_t sample_rate,
                                   int32_t channels,
                                   int64_t duration_ms) {
  std::ostringstream oss;
  oss << '{';
  AppendJsonStringField(oss, "canonical_input_file", canonical_input_file);
  oss << ",\"sample_rate\":" << sample_rate;
  oss << ",\"channels\":" << channels;
  oss << ",\"duration_ms\":" << duration_ms;
  oss << '}';
  return oss.str();
}

}  // namespace ams
