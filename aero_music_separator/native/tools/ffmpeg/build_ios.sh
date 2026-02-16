#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
: "${AMS_USE_SCCACHE:=ON}"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build_common.sh"

SIM_ARCH="${1:-arm64}"
if [[ "${SIM_ARCH}" != "arm64" && "${SIM_ARCH}" != "x86_64" ]]; then
  echo "Unsupported iOS simulator arch: ${SIM_ARCH}" >&2
  echo "Usage: $0 [arm64|x86_64]" >&2
  exit 1
fi

ensure_tool curl
ensure_tool tar
ensure_tool make
ensure_tool python3
ensure_tool xcrun

WORK_ROOT="${AMS_FFMPEG_BUILD_DIR}/ios"
SRC_ROOT="${WORK_ROOT}/src"

rm -rf "${WORK_ROOT}"
ensure_dir "${WORK_ROOT}"
ensure_dir "${SRC_ROOT}"

FFMPEG_SRC="$(prepare_ffmpeg_source "${SRC_ROOT}")"

build_one_target() {
  local sdk="$1"
  local arch="$2"
  local host_triple="$3"
  local out_root="$4"
  local build_root="$5"

  local cc_raw
  local cxx_raw
  local ar_raw
  local ranlib_raw
  local strip_raw
  local sdkroot

  cc_raw="$(xcrun --sdk "${sdk}" --find clang)"
  cxx_raw="$(xcrun --sdk "${sdk}" --find clang++)"
  ar_raw="$(xcrun --sdk "${sdk}" --find ar)"
  ranlib_raw="$(xcrun --sdk "${sdk}" --find ranlib)"
  strip_raw="$(xcrun --sdk "${sdk}" --find strip)"
  sdkroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

  local min_flag
  if [[ "${sdk}" == "iphoneos" ]]; then
    min_flag="-miphoneos-version-min=13.0"
  else
    min_flag="-mios-simulator-version-min=13.0"
  fi

  local base_cflags="-arch ${arch} -isysroot ${sdkroot} ${min_flag} -fPIC"
  local base_ldflags="-arch ${arch} -isysroot ${sdkroot} ${min_flag}"

  local cc_bin
  local cxx_bin
  cc_bin="$(with_sccache "${cc_raw}")"
  cxx_bin="$(with_sccache "${cxx_raw}")"

  local lame_prefix="${build_root}/lame-prefix"
  local ffmpeg_build="${build_root}/ffmpeg"
  rm -rf "${build_root}" "${out_root}"
  ensure_dir "${build_root}"
  ensure_dir "${out_root}"

  build_lame \
    "${SRC_ROOT}" \
    "${lame_prefix}" \
    "${host_triple}" \
    "${cc_bin}" \
    "${base_cflags}" \
    "${base_ldflags}" \
    "${ar_raw}" \
    "${ranlib_raw}" \
    "${strip_raw}"

  rm -rf "${ffmpeg_build}"
  cp -R "${FFMPEG_SRC}" "${ffmpeg_build}"

  configure_ffmpeg \
    "${ffmpeg_build}" \
    --prefix="${out_root}" \
    --enable-static \
    --disable-shared \
    --enable-cross-compile \
    --target-os=darwin \
    --arch="${arch}" \
    --cc="${cc_bin}" \
    --cxx="${cxx_bin}" \
    --ar="${ar_raw}" \
    --ranlib="${ranlib_raw}" \
    --strip="${strip_raw}" \
    --extra-cflags="-I${lame_prefix}/include ${base_cflags}" \
    --extra-ldflags="-L${lame_prefix}/lib ${base_ldflags}" \
    --enable-libmp3lame

  build_ffmpeg "${ffmpeg_build}"
  stage_third_party_licenses "${ffmpeg_build}" "${SRC_ROOT}/lame" "${out_root}"
}

IOS_OUT_DEVICE="${AMS_FFMPEG_OUT_BASE}/ios/iphoneos-arm64"
IOS_OUT_SIM="${AMS_FFMPEG_OUT_BASE}/ios/iphonesimulator-${SIM_ARCH}"

build_one_target \
  "iphoneos" \
  "arm64" \
  "aarch64-apple-darwin" \
  "${IOS_OUT_DEVICE}" \
  "${WORK_ROOT}/build-iphoneos-arm64"

build_one_target \
  "iphonesimulator" \
  "${SIM_ARCH}" \
  "${SIM_ARCH}-apple-darwin" \
  "${IOS_OUT_SIM}" \
  "${WORK_ROOT}/build-iphonesimulator-${SIM_ARCH}"

python3 "${SCRIPT_DIR}/package_manifest.py" \
  --root "${AMS_FFMPEG_OUT_BASE}/ios" \
  --platform "ios" \
  --arch "device-arm64+sim-${SIM_ARCH}" \
  --ffmpeg-version "${AMS_FFMPEG_VERSION}" \
  --lame-version "${AMS_LAME_VERSION}" \
  --ffmpeg-license "LGPL-2.1-or-later" \
  --lame-license "LGPL" \
  --gpl-enabled "false" \
  --version3-enabled "false" \
  --mp3-encoder "libmp3lame"

echo "[ffmpeg-tools] iOS build complete: ${AMS_FFMPEG_OUT_BASE}/ios"
