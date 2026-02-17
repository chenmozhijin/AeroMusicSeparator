# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(aero_music_separator LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "aero_music_separator")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Optional dependency hints for native library builds.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../ggml/CMakeLists.txt")
  set(GGML_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../ggml" CACHE PATH "" FORCE)
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/ffmpeg/windows/x64/include")
  set(AMS_USE_SYSTEM_FFMPEG OFF CACHE BOOL "" FORCE)
  set(AMS_FFMPEG_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/ffmpeg/windows/x64" CACHE PATH "" FORCE)
endif()

# Backend selection for Windows Flutter builds.
# When AMS_NATIVE_BACKEND is set, enforce it strictly.
# Supported: cuda | vulkan | cpu
set(AMS_NATIVE_BACKEND "$ENV{AMS_NATIVE_BACKEND}")
string(TOLOWER "${AMS_NATIVE_BACKEND}" AMS_NATIVE_BACKEND)

if(AMS_NATIVE_BACKEND STREQUAL "cuda")
  if(NOT DEFINED ENV{CUDA_PATH} OR NOT EXISTS "$ENV{CUDA_PATH}/bin/nvcc.exe")
    message(FATAL_ERROR "AMS_NATIVE_BACKEND=cuda requested, but CUDA_PATH/nvcc.exe was not found.")
  endif()
  set(GGML_CUDA ON CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  message(STATUS "Windows native backend: CUDA (forced)")
elseif(AMS_NATIVE_BACKEND STREQUAL "vulkan")
  if(NOT DEFINED ENV{VULKAN_SDK} OR NOT EXISTS "$ENV{VULKAN_SDK}/Include/vulkan/vulkan.h")
    message(FATAL_ERROR "AMS_NATIVE_BACKEND=vulkan requested, but VULKAN_SDK headers were not found.")
  endif()
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN ON CACHE BOOL "" FORCE)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  message(STATUS "Windows native backend: Vulkan (forced)")
elseif(AMS_NATIVE_BACKEND STREQUAL "cpu")
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  message(STATUS "Windows native backend: CPU (forced)")
elseif(AMS_NATIVE_BACKEND)
  message(FATAL_ERROR "Unsupported AMS_NATIVE_BACKEND='${AMS_NATIVE_BACKEND}'. Use one of: cuda, vulkan, cpu.")
else()
  # Default local behavior when AMS_NATIVE_BACKEND is not provided:
  # Prefer CUDA when toolkit is available, otherwise try Vulkan SDK, else CPU only.
  if(DEFINED ENV{CUDA_PATH} AND EXISTS "$ENV{CUDA_PATH}/bin/nvcc.exe")
    set(GGML_CUDA ON CACHE BOOL "" FORCE)
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
    set(GGML_METAL OFF CACHE BOOL "" FORCE)
    message(STATUS "Windows native backend: CUDA")
  elseif(DEFINED ENV{VULKAN_SDK} AND EXISTS "$ENV{VULKAN_SDK}/Include/vulkan/vulkan.h")
    set(GGML_CUDA OFF CACHE BOOL "" FORCE)
    set(GGML_VULKAN ON CACHE BOOL "" FORCE)
    set(GGML_METAL OFF CACHE BOOL "" FORCE)
    message(STATUS "Windows native backend: Vulkan")
  else()
    set(GGML_CUDA OFF CACHE BOOL "" FORCE)
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
    set(GGML_METAL OFF CACHE BOOL "" FORCE)
    message(WARNING "Windows native backend: CPU only (CUDA_PATH/VULKAN_SDK not detected)")
  endif()
endif()

if(GGML_CUDA)
  set(AMS_CUDA_ARCHITECTURES "$ENV{AMS_CUDA_ARCHITECTURES}")
  if(AMS_CUDA_ARCHITECTURES)
    if(NOT AMS_CUDA_ARCHITECTURES MATCHES "^[0-9]+(;[0-9]+)*$")
      message(FATAL_ERROR
        "Invalid AMS_CUDA_ARCHITECTURES='${AMS_CUDA_ARCHITECTURES}'. "
        "Expected format: '<arch>[;<arch>...]', e.g. '75;86'.")
    endif()
    set(CMAKE_CUDA_ARCHITECTURES "${AMS_CUDA_ARCHITECTURES}" CACHE STRING "" FORCE)
    message(STATUS "Windows CUDA architectures from AMS_CUDA_ARCHITECTURES: ${CMAKE_CUDA_ARCHITECTURES}")
  endif()
endif()

# Native FFI library build (FFmpeg + BSRoformer).
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native" "${CMAKE_CURRENT_BINARY_DIR}/native")
add_dependencies(${BINARY_NAME} aero_separator_ffi)

# Keep FFI/runtime DLLs next to runner for `flutter run` (Debug/Profile/Release).
set(AMS_FFMPEG_DLLS "")
if(DEFINED AMS_FFMPEG_ROOT AND EXISTS "${AMS_FFMPEG_ROOT}/bin")
  file(GLOB AMS_FFMPEG_DLLS "${AMS_FFMPEG_ROOT}/bin/*.dll")
endif()

set(AMS_GGML_BACKEND_TARGETS "")
foreach(AMS_GGML_BACKEND_TARGET IN ITEMS ggml-cuda ggml-vulkan)
  if(TARGET ${AMS_GGML_BACKEND_TARGET})
    list(APPEND AMS_GGML_BACKEND_TARGETS ${AMS_GGML_BACKEND_TARGET})
  endif()
endforeach()

set(AMS_GGML_BACKEND_DLL_FILES "")
foreach(AMS_GGML_BACKEND_TARGET IN LISTS AMS_GGML_BACKEND_TARGETS)
  list(APPEND AMS_GGML_BACKEND_DLL_FILES $<TARGET_FILE:${AMS_GGML_BACKEND_TARGET}>)
endforeach()

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.21")
  add_custom_target(ams_copy_runtime_dlls ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory
      $<TARGET_FILE_DIR:${BINARY_NAME}>
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_FILE:aero_separator_ffi>
      $<TARGET_RUNTIME_DLLS:aero_separator_ffi>
      ${AMS_GGML_BACKEND_DLL_FILES}
      $<TARGET_FILE_DIR:${BINARY_NAME}>
    COMMAND_EXPAND_LISTS
    DEPENDS
      ${BINARY_NAME}
      aero_separator_ffi
      ${AMS_GGML_BACKEND_TARGETS}
  )

  if(AMS_FFMPEG_DLLS)
    add_custom_target(ams_copy_ffmpeg_dlls ALL
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${AMS_FFMPEG_DLLS}
        $<TARGET_FILE_DIR:${BINARY_NAME}>
      COMMAND_EXPAND_LISTS
      DEPENDS
        ${BINARY_NAME}
        aero_separator_ffi
    )
  endif()
endif()


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

install(FILES $<TARGET_FILE:aero_separator_ffi> DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.21")
  install(FILES $<TARGET_RUNTIME_DLLS:aero_separator_ffi> DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

if(AMS_GGML_BACKEND_DLL_FILES)
  install(FILES ${AMS_GGML_BACKEND_DLL_FILES} DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

if(DEFINED AMS_FFMPEG_ROOT AND EXISTS "${AMS_FFMPEG_ROOT}/bin")
  install(DIRECTORY "${AMS_FFMPEG_ROOT}/bin/" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime
    FILES_MATCHING PATTERN "*.dll")
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
