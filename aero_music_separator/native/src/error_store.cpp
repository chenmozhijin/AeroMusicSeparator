#include "error_store.h"

#include <cstring>
#include <new>

namespace ams {

thread_local std::string g_last_error;

void SetLastError(const std::string& message) {
  g_last_error = message;
}

const char* GetLastError() {
  return g_last_error.c_str();
}

char* AllocCString(const std::string& value) {
  auto* ptr = new (std::nothrow) char[value.size() + 1];
  if (ptr == nullptr) {
    return nullptr;
  }
  std::memcpy(ptr, value.c_str(), value.size() + 1);
  return ptr;
}

}  // namespace ams
