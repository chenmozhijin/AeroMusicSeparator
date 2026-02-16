#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build_common.sh"

ARCH="${1:-arm64}"
if [[ "${ARCH}" != "arm64" && "${ARCH}" != "x86_64" ]]; then
  echo "Unsupported macOS arch: ${ARCH}" >&2
  echo "Usage: $0 [arm64|x86_64]" >&2
  exit 1
fi

ensure_tool curl
ensure_tool tar
ensure_tool make
ensure_tool clang
ensure_tool clang++
ensure_tool xcrun
ensure_tool python3

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
if [[ -z "${SDKROOT}" ]]; then
  echo "Failed to resolve macOS SDKROOT" >&2
  exit 1
fi

WORK_ROOT="${AMS_FFMPEG_BUILD_DIR}/macos-${ARCH}"
SRC_ROOT="${WORK_ROOT}/src"
LAME_PREFIX="${WORK_ROOT}/lame-prefix"
OUT_ROOT="${AMS_FFMPEG_OUT_BASE}/macos/${ARCH}"

rm -rf "${WORK_ROOT}" "${OUT_ROOT}"
ensure_dir "${WORK_ROOT}"
ensure_dir "${SRC_ROOT}"
ensure_dir "${OUT_ROOT}"

FFMPEG_SRC="$(prepare_ffmpeg_source "${SRC_ROOT}")"

BASE_CFLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mmacosx-version-min=12.0 -fPIC"
BASE_LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mmacosx-version-min=12.0"

CC_BIN="$(with_sccache clang)"
CXX_BIN="$(with_sccache clang++)"

build_lame \
  "${SRC_ROOT}" \
  "${LAME_PREFIX}" \
  "" \
  "${CC_BIN}" \
  "${BASE_CFLAGS}" \
  "${BASE_LDFLAGS}" \
  "ar" \
  "ranlib" \
  "strip"

configure_ffmpeg \
  "${FFMPEG_SRC}" \
  --prefix="${OUT_ROOT}" \
  --enable-shared \
  --disable-static \
  --cc="${CC_BIN}" \
  --cxx="${CXX_BIN}" \
  --arch="${ARCH}" \
  --target-os=darwin \
  --extra-cflags="-I${LAME_PREFIX}/include ${BASE_CFLAGS}" \
  --extra-ldflags="-L${LAME_PREFIX}/lib ${BASE_LDFLAGS}" \
  --enable-libmp3lame

build_ffmpeg "${FFMPEG_SRC}"
stage_third_party_licenses "${FFMPEG_SRC}" "${SRC_ROOT}/lame" "${OUT_ROOT}"

python3 "${SCRIPT_DIR}/package_manifest.py" \
  --root "${OUT_ROOT}" \
  --platform "macos" \
  --arch "${ARCH}" \
  --ffmpeg-version "${AMS_FFMPEG_VERSION}" \
  --lame-version "${AMS_LAME_VERSION}" \
  --ffmpeg-license "LGPL-2.1-or-later" \
  --lame-license "LGPL" \
  --gpl-enabled "false" \
  --version3-enabled "false" \
  --mp3-encoder "libmp3lame"

echo "[ffmpeg-tools] macOS build complete: ${OUT_ROOT}"
