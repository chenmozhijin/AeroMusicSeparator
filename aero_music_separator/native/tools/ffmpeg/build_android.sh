#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/build_common.sh"

ABI="${1:-arm64-v8a}"
API_LEVEL="${AMS_ANDROID_API_LEVEL:-24}"
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "${NDK}" ]]; then
  echo "ANDROID_NDK_HOME or ANDROID_NDK_ROOT is required." >&2
  exit 1
fi

TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"
if [[ ! -d "${TOOLCHAIN}" ]]; then
  echo "Android NDK toolchain not found: ${TOOLCHAIN}" >&2
  exit 1
fi

case "${ABI}" in
  arm64-v8a)
    HOST_TRIPLE="aarch64-linux-android"
    FF_ARCH="aarch64"
    FF_CPU="armv8-a"
    CLANG_TRIPLE="aarch64-linux-android"
    ;;
  armeabi-v7a)
    HOST_TRIPLE="armv7a-linux-androideabi"
    FF_ARCH="arm"
    FF_CPU="armv7-a"
    CLANG_TRIPLE="armv7a-linux-androideabi"
    ;;
  x86_64)
    HOST_TRIPLE="x86_64-linux-android"
    FF_ARCH="x86_64"
    FF_CPU=""
    CLANG_TRIPLE="x86_64-linux-android"
    ;;
  *)
    echo "Unsupported Android ABI: ${ABI}" >&2
    echo "Usage: $0 [arm64-v8a|armeabi-v7a|x86_64]" >&2
    exit 1
    ;;
esac

ensure_tool curl
ensure_tool tar
ensure_tool make
ensure_tool python3

WORK_ROOT="${AMS_FFMPEG_BUILD_DIR}/android-${ABI}"
SRC_ROOT="${WORK_ROOT}/src"
LAME_PREFIX="${WORK_ROOT}/lame-prefix"
OUT_ROOT="${AMS_FFMPEG_OUT_BASE}/android/${ABI}"

rm -rf "${WORK_ROOT}" "${OUT_ROOT}"
ensure_dir "${WORK_ROOT}"
ensure_dir "${SRC_ROOT}"
ensure_dir "${OUT_ROOT}"

FFMPEG_SRC="$(prepare_ffmpeg_source "${SRC_ROOT}")"

CC_RAW="${TOOLCHAIN}/bin/${CLANG_TRIPLE}${API_LEVEL}-clang"
CXX_RAW="${TOOLCHAIN}/bin/${CLANG_TRIPLE}${API_LEVEL}-clang++"
AR_RAW="${TOOLCHAIN}/bin/llvm-ar"
RANLIB_RAW="${TOOLCHAIN}/bin/llvm-ranlib"
STRIP_RAW="${TOOLCHAIN}/bin/llvm-strip"

CC_BIN="$(with_sccache "${CC_RAW}")"
CXX_BIN="$(with_sccache "${CXX_RAW}")"

BASE_CFLAGS="-fPIC"
if [[ "${ABI}" == "armeabi-v7a" ]]; then
  BASE_CFLAGS="${BASE_CFLAGS} -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
fi
# Keep FFmpeg internals local when static archives are linked into our shared JNI library.
FFMPEG_CFLAGS="${BASE_CFLAGS} -fvisibility=hidden"

build_lame \
  "${SRC_ROOT}" \
  "${LAME_PREFIX}" \
  "${HOST_TRIPLE}" \
  "${CC_BIN}" \
  "${BASE_CFLAGS}" \
  "" \
  "${AR_RAW}" \
  "${RANLIB_RAW}" \
  "${STRIP_RAW}"

FFMPEG_FLAGS=(
  --prefix="${OUT_ROOT}"
  --enable-static
  --disable-shared
  --enable-cross-compile
  --target-os=android
  --arch="${FF_ARCH}"
  --cc="${CC_BIN}"
  --cxx="${CXX_BIN}"
  --ar="${AR_RAW}"
  --ranlib="${RANLIB_RAW}"
  --strip="${STRIP_RAW}"
  --sysroot="${TOOLCHAIN}/sysroot"
  --extra-cflags="-I${LAME_PREFIX}/include ${FFMPEG_CFLAGS}"
  --extra-ldflags="-L${LAME_PREFIX}/lib"
  --extra-libs="-lm"
  --enable-libmp3lame
)

if [[ -n "${FF_CPU}" ]]; then
  FFMPEG_FLAGS+=(--cpu="${FF_CPU}")
fi

configure_ffmpeg "${FFMPEG_SRC}" "${FFMPEG_FLAGS[@]}"

build_ffmpeg "${FFMPEG_SRC}"
stage_third_party_licenses "${FFMPEG_SRC}" "${SRC_ROOT}/lame" "${OUT_ROOT}"

python3 "${SCRIPT_DIR}/package_manifest.py" \
  --root "${OUT_ROOT}" \
  --platform "android" \
  --arch "${ABI}" \
  --ffmpeg-version "${AMS_FFMPEG_VERSION}" \
  --lame-version "${AMS_LAME_VERSION}" \
  --ffmpeg-license "LGPL-2.1-or-later" \
  --lame-license "LGPL" \
  --gpl-enabled "false" \
  --version3-enabled "false" \
  --mp3-encoder "libmp3lame"

echo "[ffmpeg-tools] Android build complete: ${OUT_ROOT}"
