#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build_common.sh"

ARCH="${1:-x86_64}"
if [[ "${ARCH}" != "x86_64" && "${ARCH}" != "aarch64" ]]; then
  echo "Unsupported Linux arch: ${ARCH}" >&2
  echo "Usage: $0 [x86_64|aarch64]" >&2
  exit 1
fi

if [[ "${ARCH}" != "$(uname -m)" ]]; then
  echo "Cross compile is not configured for Linux arch ${ARCH} on host $(uname -m)." >&2
  echo "Run this script on a matching runner or extend toolchain mapping." >&2
  exit 1
fi

ensure_tool curl
ensure_tool tar
ensure_tool make
ensure_tool gcc
ensure_tool g++
ensure_tool pkg-config
ensure_tool python3

WORK_ROOT="${AMS_FFMPEG_BUILD_DIR}/linux-${ARCH}"
SRC_ROOT="${WORK_ROOT}/src"
LAME_PREFIX="${WORK_ROOT}/lame-prefix"
OUT_ROOT="${AMS_FFMPEG_OUT_BASE}/linux/${ARCH}"

rm -rf "${WORK_ROOT}" "${OUT_ROOT}"
ensure_dir "${WORK_ROOT}"
ensure_dir "${SRC_ROOT}"
ensure_dir "${OUT_ROOT}"

FFMPEG_SRC="$(prepare_ffmpeg_source "${SRC_ROOT}")"

CC_BIN="$(with_sccache gcc)"
CXX_BIN="$(with_sccache g++)"

build_lame \
  "${SRC_ROOT}" \
  "${LAME_PREFIX}" \
  "" \
  "${CC_BIN}" \
  "-fPIC" \
  "" \
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
  --pkg-config-flags="--static" \
  --extra-cflags="-I${LAME_PREFIX}/include -fPIC" \
  --extra-ldflags="-L${LAME_PREFIX}/lib" \
  --extra-libs="-lm -lpthread" \
  --enable-libmp3lame

build_ffmpeg "${FFMPEG_SRC}"
stage_third_party_licenses "${FFMPEG_SRC}" "${SRC_ROOT}/lame" "${OUT_ROOT}"

python3 "${SCRIPT_DIR}/package_manifest.py" \
  --root "${OUT_ROOT}" \
  --platform "linux" \
  --arch "${ARCH}" \
  --ffmpeg-version "${AMS_FFMPEG_VERSION}" \
  --lame-version "${AMS_LAME_VERSION}" \
  --ffmpeg-license "LGPL-2.1-or-later" \
  --lame-license "LGPL" \
  --gpl-enabled "false" \
  --version3-enabled "false" \
  --mp3-encoder "libmp3lame"

echo "[ffmpeg-tools] linux build complete: ${OUT_ROOT}"
