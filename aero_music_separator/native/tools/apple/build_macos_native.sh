#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="$(cd "${NATIVE_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/.." && pwd)"

ARCH="${1:-${CURRENT_ARCH:-$(uname -m)}}"
case "${ARCH}" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported macOS architecture: ${ARCH}" >&2
    echo "Usage: $0 [arm64|x86_64]" >&2
    exit 1
    ;;
esac

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required but was not found" >&2
  exit 1
fi

CC_BIN="$(xcrun --sdk macosx --find clang)"
CXX_BIN="$(xcrun --sdk macosx --find clang++)"
ASM_BIN="$(xcrun --sdk macosx --find clang)"
export SCCACHE_DISABLE=1

GENERATOR="Ninja"
if ! command -v ninja >/dev/null 2>&1; then
  GENERATOR="Unix Makefiles"
fi

FFMPEG_ROOT="${NATIVE_DIR}/third_party/ffmpeg/macos/${ARCH}"
BUILD_DIR="${APP_DIR}/build/native-macos-${ARCH}"

CMAKE_ARGS=(
  -S "${NATIVE_DIR}"
  -B "${BUILD_DIR}"
  -G "${GENERATOR}"
  -DAMS_BSR_ROOT="${REPO_ROOT}/BSRoformer.cpp"
  -DGGML_DIR="${REPO_ROOT}/ggml"
  -DGGML_CUDA=OFF
  -DGGML_VULKAN=OFF
  -DGGML_METAL=ON
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
  -DCMAKE_C_COMPILER="${CC_BIN}"
  -DCMAKE_CXX_COMPILER="${CXX_BIN}"
  -DCMAKE_ASM_COMPILER="${ASM_BIN}"
  -DCMAKE_C_COMPILER_LAUNCHER=
  -DCMAKE_CXX_COMPILER_LAUNCHER=
  -DCMAKE_ASM_COMPILER_LAUNCHER=
)

if [[ -d "${FFMPEG_ROOT}/include" ]]; then
  CMAKE_ARGS+=(
    -DAMS_USE_SYSTEM_FFMPEG=OFF
    -DAMS_FFMPEG_ROOT="${FFMPEG_ROOT}"
  )
else
  echo "[apple-tools] ${FFMPEG_ROOT} not found, falling back to system FFmpeg." >&2
  CMAKE_ARGS+=(-DAMS_USE_SYSTEM_FFMPEG=ON)
fi

echo "[apple-tools] Configure native macOS runtime (${ARCH})"
cmake "${CMAKE_ARGS[@]}"

echo "[apple-tools] Build native macOS runtime (${ARCH})"
cmake --build "${BUILD_DIR}" --config Release --parallel

echo "[apple-tools] Native runtime build complete: ${BUILD_DIR}"
