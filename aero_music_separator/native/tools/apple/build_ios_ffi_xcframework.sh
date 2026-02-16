#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="$(cd "${NATIVE_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/.." && pwd)"

SIM_ARCHS_CSV="${1:-${AMS_IOS_SIM_ARCHS:-arm64,x86_64}}"
IFS=',' read -r -a SIM_ARCHS <<< "${SIM_ARCHS_CSV}"

for arch in "${SIM_ARCHS[@]}"; do
  if [[ "${arch}" != "arm64" && "${arch}" != "x86_64" ]]; then
    echo "Unsupported iOS simulator architecture: ${arch}" >&2
    exit 1
  fi
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required but was not found" >&2
  exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required but was not found" >&2
  exit 1
fi

GENERATOR="Ninja"
if ! command -v ninja >/dev/null 2>&1; then
  GENERATOR="Unix Makefiles"
fi

BUILD_ROOT="${APP_DIR}/build/native-ios"
POD_ROOT="${NATIVE_DIR}/ios/AeroSeparatorFFI"
WORK_ROOT="${BUILD_ROOT}/work"
HEADERS_DIR="${NATIVE_DIR}/include"
DEVICE_FFMPEG_ROOT="${NATIVE_DIR}/third_party/ffmpeg/ios/iphoneos-arm64"

mkdir -p "${WORK_ROOT}" "${POD_ROOT}"

if [[ ! -d "${DEVICE_FFMPEG_ROOT}/include" ]]; then
  echo "Missing iOS FFmpeg device bundle: ${DEVICE_FFMPEG_ROOT}" >&2
  echo "Run native/tools/ffmpeg/build_ios.sh first." >&2
  exit 1
fi

configure_and_build() {
  local sdk="$1"
  local arch="$2"
  local ffmpeg_root="$3"
  local build_dir="$4"

  cmake \
    -S "${NATIVE_DIR}" \
    -B "${build_dir}" \
    -G "${GENERATOR}" \
    -DAMS_BSR_ROOT="${REPO_ROOT}/BSRoformer.cpp" \
    -DGGML_DIR="${REPO_ROOT}/ggml" \
    -DAMS_USE_SYSTEM_FFMPEG=OFF \
    -DAMS_FFMPEG_ROOT="${ffmpeg_root}" \
    -DGGML_CUDA=OFF \
    -DGGML_VULKAN=OFF \
    -DGGML_METAL=ON \
    -DGGML_OPENMP=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="${sdk}" \
    -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY

  cmake --build "${build_dir}" --config Release --parallel
}

collect_native_archives() {
  local build_dir="$1"
  local ffmpeg_root="$2"
  local output_list_file="$3"
  local main_lib=""

  : > "${output_list_file}"

  main_lib="$(find "${build_dir}" -type f -name "libaero_separator_ffi.a" | head -n1 || true)"
  if [[ -z "${main_lib}" ]]; then
    echo "Failed to locate libaero_separator_ffi.a under ${build_dir}" >&2
    exit 1
  fi
  echo "${main_lib}" >> "${output_list_file}"
  find "${build_dir}" -type f -name "libbs_roformer*.a" >> "${output_list_file}" || true
  find "${build_dir}" -type f -name "libggml*.a" >> "${output_list_file}" || true

  for lib_name in libavformat.a libavcodec.a libavutil.a libswresample.a libmp3lame.a; do
    if [[ -f "${ffmpeg_root}/lib/${lib_name}" ]]; then
      echo "${ffmpeg_root}/lib/${lib_name}" >> "${output_list_file}"
    fi
  done

  awk 'NF' "${output_list_file}" | awk '!seen[$0]++' > "${output_list_file}.tmp"
  mv "${output_list_file}.tmp" "${output_list_file}"
}

merge_archives() {
  local output_archive="$1"
  local list_file="$2"
  local archives=()
  while IFS= read -r archive; do
    [[ -z "${archive}" ]] && continue
    archives+=("${archive}")
  done < "${list_file}"
  if [[ ${#archives[@]} -eq 0 ]]; then
    echo "No archives to merge for ${output_archive}" >&2
    exit 1
  fi
  libtool -static -o "${output_archive}" "${archives[@]}"
}

DEVICE_BUILD_DIR="${BUILD_ROOT}/device-arm64"
DEVICE_LIST_FILE="${WORK_ROOT}/device-archives.txt"
DEVICE_MERGED="${WORK_ROOT}/libaero_separator_ffi_full_device.a"

configure_and_build "iphoneos" "arm64" "${DEVICE_FFMPEG_ROOT}" "${DEVICE_BUILD_DIR}"
collect_native_archives "${DEVICE_BUILD_DIR}" "${DEVICE_FFMPEG_ROOT}" "${DEVICE_LIST_FILE}"
merge_archives "${DEVICE_MERGED}" "${DEVICE_LIST_FILE}"

SIM_MERGED_ARCHIVES=()
SIM_BUILT_COUNT=0
for sim_arch in "${SIM_ARCHS[@]}"; do
  SIM_FFMPEG_ROOT="${NATIVE_DIR}/third_party/ffmpeg/ios/iphonesimulator-${sim_arch}"
  if [[ ! -d "${SIM_FFMPEG_ROOT}/include" ]]; then
    echo "[apple-tools] Skip simulator arch ${sim_arch}: ${SIM_FFMPEG_ROOT} not found." >&2
    continue
  fi
  SIM_BUILD_DIR="${BUILD_ROOT}/sim-${sim_arch}"
  SIM_LIST_FILE="${WORK_ROOT}/sim-${sim_arch}-archives.txt"
  SIM_MERGED="${WORK_ROOT}/libaero_separator_ffi_full_sim_${sim_arch}.a"
  configure_and_build "iphonesimulator" "${sim_arch}" "${SIM_FFMPEG_ROOT}" "${SIM_BUILD_DIR}"
  collect_native_archives "${SIM_BUILD_DIR}" "${SIM_FFMPEG_ROOT}" "${SIM_LIST_FILE}"
  merge_archives "${SIM_MERGED}" "${SIM_LIST_FILE}"
  SIM_MERGED_ARCHIVES+=("${SIM_MERGED}")
  SIM_BUILT_COUNT=$((SIM_BUILT_COUNT + 1))
done

if [[ ${SIM_BUILT_COUNT} -eq 0 ]]; then
  echo "No simulator FFmpeg bundle found. Build at least one simulator FFmpeg package first." >&2
  exit 1
fi

SIM_UNIVERSAL="${WORK_ROOT}/libaero_separator_ffi_full_sim_universal.a"
if [[ ${#SIM_MERGED_ARCHIVES[@]} -eq 1 ]]; then
  cp -f "${SIM_MERGED_ARCHIVES[0]}" "${SIM_UNIVERSAL}"
else
  lipo -create "${SIM_MERGED_ARCHIVES[@]}" -output "${SIM_UNIVERSAL}"
fi

XCFRAMEWORK_OUT="${POD_ROOT}/AeroSeparatorFFI.xcframework"
rm -rf "${XCFRAMEWORK_OUT}"

xcodebuild -create-xcframework \
  -library "${DEVICE_MERGED}" -headers "${HEADERS_DIR}" \
  -library "${SIM_UNIVERSAL}" -headers "${HEADERS_DIR}" \
  -output "${XCFRAMEWORK_OUT}"

echo "[apple-tools] iOS XCFramework generated: ${XCFRAMEWORK_OUT}"
