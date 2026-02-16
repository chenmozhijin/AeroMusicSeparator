cmake_minimum_required(VERSION 3.22.1)
project(aero_separator_android LANGUAGES C CXX)

# This CMake project delegates to the shared native FFI core.
set(AMS_BSR_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../BSRoformer.cpp" CACHE PATH "")
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native" native_build)
