#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build_common.sh"

# On some runners only mingw32-make is present; expose it as make for common helpers.
if ! command -v make >/dev/null 2>&1 && command -v mingw32-make >/dev/null 2>&1; then
  make() {
    mingw32-make "$@"
  }
fi

ARCH="${1:-x64}"
case "${ARCH}" in
  x64)
    HOST_TRIPLE="x86_64-w64-mingw32"
    FF_ARCH="x86_64"
    OUT_ARCH="x64"
    ;;
  *)
    echo "Unsupported Windows arch: ${ARCH}" >&2
    echo "Usage: $0 [x64]" >&2
    exit 1
    ;;
esac

ensure_tool curl
ensure_tool tar
ensure_tool make
ensure_tool python3

pick_tool() {
  local preferred="$1"
  local fallback="$2"
  if command -v "${preferred}" >/dev/null 2>&1; then
    echo "${preferred}"
    return
  fi
  ensure_tool "${fallback}"
  echo "${fallback}"
}

WORK_ROOT="${AMS_FFMPEG_BUILD_DIR}/windows-${OUT_ARCH}"
SRC_ROOT="${WORK_ROOT}/src"
LAME_PREFIX="${WORK_ROOT}/lame-prefix"
OUT_ROOT="${AMS_FFMPEG_OUT_BASE}/windows/${OUT_ARCH}"

rm -rf "${WORK_ROOT}" "${OUT_ROOT}"
ensure_dir "${WORK_ROOT}"
ensure_dir "${SRC_ROOT}"
ensure_dir "${OUT_ROOT}"

FFMPEG_SRC="$(prepare_ffmpeg_source "${SRC_ROOT}")"

CC_RAW="$(pick_tool "${HOST_TRIPLE}-gcc" "gcc")"
CXX_RAW="$(pick_tool "${HOST_TRIPLE}-g++" "g++")"
AR_RAW="$(pick_tool "${HOST_TRIPLE}-ar" "ar")"
NM_RAW="$(pick_tool "${HOST_TRIPLE}-nm" "nm")"
RANLIB_RAW="$(pick_tool "${HOST_TRIPLE}-ranlib" "ranlib")"
STRIP_RAW="$(pick_tool "${HOST_TRIPLE}-strip" "strip")"

FF_CROSS_PREFIX=""
if [[ "${CC_RAW}" == "${HOST_TRIPLE}-gcc" ]] && \
   command -v "${HOST_TRIPLE}-ar" >/dev/null 2>&1 && \
   command -v "${HOST_TRIPLE}-nm" >/dev/null 2>&1 && \
   command -v "${HOST_TRIPLE}-ranlib" >/dev/null 2>&1 && \
   command -v "${HOST_TRIPLE}-strip" >/dev/null 2>&1; then
  FF_CROSS_PREFIX="${HOST_TRIPLE}-"
fi

CC_BIN="$(with_sccache "${CC_RAW}")"
CXX_BIN="$(with_sccache "${CXX_RAW}")"

build_lame \
  "${SRC_ROOT}" \
  "${LAME_PREFIX}" \
  "${HOST_TRIPLE}" \
  "${CC_BIN}" \
  "-O2 -fPIC" \
  "" \
  "${AR_RAW}" \
  "${RANLIB_RAW}" \
  "${STRIP_RAW}"

FFMPEG_EXTRA_FLAGS=(
  --prefix="${OUT_ROOT}"
  --target-os=mingw32
  --arch="${FF_ARCH}"
  --enable-shared
  --disable-static
  --cc="${CC_BIN}"
  --cxx="${CXX_BIN}"
  --ar="${AR_RAW}"
  --nm="${NM_RAW}"
  --ranlib="${RANLIB_RAW}"
  --strip="${STRIP_RAW}"
  --extra-cflags="-I${LAME_PREFIX}/include"
  --extra-ldflags="-L${LAME_PREFIX}/lib"
  --extra-libs="-lws2_32 -lshlwapi -lbcrypt"
  --enable-libmp3lame
)

if [[ -n "${FF_CROSS_PREFIX}" ]]; then
  FFMPEG_EXTRA_FLAGS+=(--cross-prefix="${FF_CROSS_PREFIX}")
fi

configure_ffmpeg "${FFMPEG_SRC}" "${FFMPEG_EXTRA_FLAGS[@]}"

build_ffmpeg "${FFMPEG_SRC}"
stage_third_party_licenses "${FFMPEG_SRC}" "${SRC_ROOT}/lame" "${OUT_ROOT}"

MINGW_BIN_DIR="$(dirname "$(command -v "${CC_RAW}")")"
for runtime_dll in libwinpthread-1.dll libgcc_s_seh-1.dll libstdc++-6.dll; do
  if [[ -f "${MINGW_BIN_DIR}/${runtime_dll}" ]]; then
    cp -f "${MINGW_BIN_DIR}/${runtime_dll}" "${OUT_ROOT}/bin/"
  fi
done

python3 "${SCRIPT_DIR}/package_manifest.py" \
  --root "${OUT_ROOT}" \
  --platform "windows" \
  --arch "${OUT_ARCH}" \
  --ffmpeg-version "${AMS_FFMPEG_VERSION}" \
  --lame-version "${AMS_LAME_VERSION}" \
  --ffmpeg-license "LGPL-2.1-or-later" \
  --lame-license "LGPL" \
  --gpl-enabled "false" \
  --version3-enabled "false" \
  --mp3-encoder "libmp3lame"

echo "[ffmpeg-tools] Windows build complete: ${OUT_ROOT}"
