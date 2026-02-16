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

CC_BIN=""
CXX_BIN=""
ASM_BIN="$(xcrun --sdk macosx --find clang)"
export SCCACHE_DISABLE=1

OPENMP_CMAKE_ARGS=()
configure_openmp_args() {
  local omp_prefix="$1"
  local omp_lib="${omp_prefix}/lib/libomp.dylib"
  local omp_include="${omp_prefix}/include"
  if [[ -f "${omp_lib}" ]]; then
    OPENMP_CMAKE_ARGS+=(
      -DGGML_OPENMP=ON
      "-DOpenMP_C_FLAGS=-Xpreprocessor -fopenmp"
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp"
      -DOpenMP_C_LIB_NAMES=omp
      -DOpenMP_CXX_LIB_NAMES=omp
      -DOpenMP_omp_LIBRARY="${omp_lib}"
      -DOpenMP_C_INCLUDE_DIR="${omp_include}"
      -DOpenMP_CXX_INCLUDE_DIR="${omp_include}"
    )
    return 0
  fi
  return 1
}

LLVM_PREFIX=""
for candidate in /opt/homebrew/opt/llvm /usr/local/opt/llvm; do
  if [[ -x "${candidate}/bin/clang" && -x "${candidate}/bin/clang++" ]]; then
    LLVM_PREFIX="${candidate}"
    break
  fi
done

if [[ -n "${LLVM_PREFIX}" ]]; then
  CC_BIN="${LLVM_PREFIX}/bin/clang"
  CXX_BIN="${LLVM_PREFIX}/bin/clang++"
  if configure_openmp_args "${LLVM_PREFIX}"; then
    echo "[apple-tools] Using Homebrew LLVM toolchain with OpenMP from ${LLVM_PREFIX}"
  else
    echo "[apple-tools] warning: LLVM found at ${LLVM_PREFIX} but libomp is missing; OpenMP may be unavailable." >&2
    OPENMP_CMAKE_ARGS+=(-DGGML_OPENMP=ON)
  fi
else
  CC_BIN="$(xcrun --sdk macosx --find clang)"
  CXX_BIN="$(xcrun --sdk macosx --find clang++)"
  echo "[apple-tools] warning: Homebrew LLVM not found, falling back to system clang." >&2
  LIBOMP_PREFIX=""
  for candidate in /opt/homebrew/opt/libomp /usr/local/opt/libomp; do
    if [[ -f "${candidate}/lib/libomp.dylib" ]]; then
      LIBOMP_PREFIX="${candidate}"
      break
    fi
  done
  if [[ -n "${LIBOMP_PREFIX}" ]]; then
    configure_openmp_args "${LIBOMP_PREFIX}" || true
  else
    OPENMP_CMAKE_ARGS+=(-DGGML_OPENMP=ON)
  fi
fi

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
  "${OPENMP_CMAKE_ARGS[@]}"
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
