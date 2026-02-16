cmake_minimum_required(VERSION 3.22.1)
project(aero_separator_android LANGUAGES C CXX)

# This CMake project delegates to the shared native FFI core.
set(AMS_BSR_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../BSRoformer.cpp" CACHE PATH "")

if(NOT DEFINED ANDROID_ABI OR ANDROID_ABI STREQUAL "")
  message(FATAL_ERROR "ANDROID_ABI is required for Android native builds.")
endif()

set(AMS_FFMPEG_ANDROID_ROOT "" CACHE PATH "Path to FFmpeg android root containing ABI subdirectories")
if(AMS_FFMPEG_ANDROID_ROOT)
  set(AMS_FFMPEG_ROOT "${AMS_FFMPEG_ANDROID_ROOT}/${ANDROID_ABI}" CACHE PATH "Resolved FFmpeg root for current ABI" FORCE)
endif()

if(NOT DEFINED AMS_FFMPEG_ROOT OR AMS_FFMPEG_ROOT STREQUAL "")
  message(FATAL_ERROR "AMS_FFMPEG_ROOT is not set. Pass AMS_FFMPEG_ANDROID_ROOT or AMS_FFMPEG_ROOT.")
endif()

if(NOT EXISTS "${AMS_FFMPEG_ROOT}/include" OR NOT EXISTS "${AMS_FFMPEG_ROOT}/lib")
  message(FATAL_ERROR
    "FFmpeg root for ABI '${ANDROID_ABI}' not found or incomplete: ${AMS_FFMPEG_ROOT}. "
    "Expected include/ and lib/ under this directory.")
endif()

set(AMS_VULKAN_INCLUDE_DIR "" CACHE PATH "Path containing Vulkan C++ headers (vulkan/vulkan.hpp)")
if(GGML_VULKAN)
  if(NOT AMS_VULKAN_INCLUDE_DIR)
    message(FATAL_ERROR "GGML_VULKAN=ON requires AMS_VULKAN_INCLUDE_DIR.")
  endif()
  if(NOT EXISTS "${AMS_VULKAN_INCLUDE_DIR}/vulkan/vulkan.hpp")
    message(FATAL_ERROR
      "Vulkan C++ headers not found at AMS_VULKAN_INCLUDE_DIR='${AMS_VULKAN_INCLUDE_DIR}'. "
      "Expected ${AMS_VULKAN_INCLUDE_DIR}/vulkan/vulkan.hpp")
  endif()
  include_directories(BEFORE "${AMS_VULKAN_INCLUDE_DIR}")
  set(Vulkan_INCLUDE_DIR "${AMS_VULKAN_INCLUDE_DIR}" CACHE PATH "Vulkan include dir" FORCE)
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native" native_build)
