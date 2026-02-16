cmake_minimum_required(VERSION 3.17)
project(aero_separator_native LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(AMS_USE_SYSTEM_FFMPEG "Use pkg-config/system FFmpeg when possible" ON)
set(AMS_FFMPEG_ROOT "" CACHE PATH "Path to FFmpeg root (contains include/ and lib/)")
set(AMS_BSR_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../BSRoformer.cpp" CACHE PATH "Path to BSRoformer.cpp submodule")

if(NOT WIN32)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

if(NOT EXISTS "${AMS_BSR_ROOT}/CMakeLists.txt")
  message(FATAL_ERROR "BSRoformer.cpp not found at AMS_BSR_ROOT='${AMS_BSR_ROOT}'")
endif()

if(NOT TARGET bs_roformer)
  if(NOT DEFINED GGML_CUDA)
    set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  endif()
  if(NOT DEFINED GGML_VULKAN)
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  endif()
  if(NOT DEFINED GGML_METAL)
    set(GGML_METAL OFF CACHE BOOL "" FORCE)
  endif()

  set(MBR_BUILD_CLI OFF CACHE BOOL "" FORCE)
  set(MBR_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  add_subdirectory("${AMS_BSR_ROOT}" bsr_build)
endif()

if(TARGET bs_roformer)
  set_target_properties(bs_roformer PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

set(AMS_NATIVE_LIB_TYPE SHARED)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  # iOS app bundles consume static libraries/frameworks rather than loose dylibs.
  set(AMS_NATIVE_LIB_TYPE STATIC)
endif()

add_library(aero_separator_ffi ${AMS_NATIVE_LIB_TYPE}
  src/ams_ffi.cpp
  src/engine_manager.cpp
  src/prepare_manager.cpp
  src/job_manager.cpp
  src/ffmpeg_decode_resample.cpp
  src/ffmpeg_encode.cpp
  src/error_store.cpp
  src/json_result.cpp
)

if(MSVC)
  target_compile_options(aero_separator_ffi PRIVATE /W3 /EHsc /utf-8)
  target_compile_definitions(aero_separator_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
  target_compile_options(aero_separator_ffi PRIVATE -Wall -Wextra)
endif()

target_include_directories(aero_separator_ffi
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${AMS_BSR_ROOT}/include"
)

target_link_libraries(aero_separator_ffi PRIVATE bs_roformer)

# Ensure optional ggml backend runtime targets are built together with FFI.
foreach(AMS_GGML_BACKEND_TARGET IN ITEMS ggml-cuda ggml-vulkan ggml-metal)
  if(TARGET ${AMS_GGML_BACKEND_TARGET})
    add_dependencies(aero_separator_ffi ${AMS_GGML_BACKEND_TARGET})
  endif()
endforeach()

if(AMS_FFMPEG_ROOT)
  message(STATUS "Using FFmpeg from AMS_FFMPEG_ROOT='${AMS_FFMPEG_ROOT}'")
  target_include_directories(aero_separator_ffi PRIVATE "${AMS_FFMPEG_ROOT}/include")
  target_link_directories(aero_separator_ffi PRIVATE "${AMS_FFMPEG_ROOT}/lib")
  if(WIN32)
    # MinGW-style FFmpeg installs import .lib files under bin/.
    target_link_directories(aero_separator_ffi PRIVATE "${AMS_FFMPEG_ROOT}/bin")
  endif()
  target_link_libraries(aero_separator_ffi PRIVATE avformat avcodec avutil swresample)
else()
  if(AMS_USE_SYSTEM_FFMPEG)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
    pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
    pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
    pkg_check_modules(SWRESAMPLE REQUIRED IMPORTED_TARGET libswresample)

    target_link_libraries(aero_separator_ffi PRIVATE
      PkgConfig::AVFORMAT
      PkgConfig::AVCODEC
      PkgConfig::AVUTIL
      PkgConfig::SWRESAMPLE
    )
  else()
    message(FATAL_ERROR "FFmpeg is required. Set AMS_FFMPEG_ROOT or enable AMS_USE_SYSTEM_FFMPEG.")
  endif()
endif()

if(WIN32)
  set_target_properties(aero_separator_ffi PROPERTIES OUTPUT_NAME "aero_separator_ffi")
elseif(APPLE)
  set_target_properties(aero_separator_ffi PROPERTIES
    OUTPUT_NAME "aero_separator_ffi"
    MACOSX_RPATH ON
  )
else()
  set_target_properties(aero_separator_ffi PROPERTIES OUTPUT_NAME "aero_separator_ffi")
endif()
