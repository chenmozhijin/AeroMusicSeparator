#pragma once

#include <string>

namespace ams {

void SetLastError(const std::string& message);
const char* GetLastError();
char* AllocCString(const std::string& value);

}  // namespace ams
