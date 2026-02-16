#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="$(cd "${NATIVE_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/.." && pwd)"

ARCH="${CURRENT_ARCH:-$(uname -m)}"
if [[ "${ARCH}" != "arm64" && "${ARCH}" != "x86_64" ]]; then
  ARCH="$(uname -m)"
fi

BUILD_DIR="${APP_DIR}/build/native-macos-${ARCH}"
FFMPEG_ROOT="${NATIVE_DIR}/third_party/ffmpeg/macos/${ARCH}"

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
  echo "This script must run from Xcode build phases (missing build env)." >&2
  exit 1
fi

APP_FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${APP_FRAMEWORKS_DIR}"

find_native_lib() {
  find "${BUILD_DIR}" -type f -name "libaero_separator_ffi.dylib" | head -n1
}

AERO_LIB="$(find_native_lib || true)"
if [[ -z "${AERO_LIB}" ]]; then
  echo "[apple-tools] Native dylib not found, invoking build_macos_native.sh (${ARCH})"
  bash "${SCRIPT_DIR}/build_macos_native.sh" "${ARCH}"
  AERO_LIB="$(find_native_lib || true)"
fi

if [[ -z "${AERO_LIB}" ]]; then
  echo "Failed to locate libaero_separator_ffi.dylib under ${BUILD_DIR}" >&2
  exit 1
fi

if [[ ! -d "${FFMPEG_ROOT}/lib" ]]; then
  echo "FFmpeg root missing at ${FFMPEG_ROOT}. Build FFmpeg first." >&2
  exit 1
fi

copy_if_exists() {
  local pattern="$1"
  local copied=false
  shopt -s nullglob globstar
  for file in ${pattern}; do
    cp -f "${file}" "${APP_FRAMEWORKS_DIR}/"
    copied=true
  done
  shopt -u nullglob globstar
  if [[ "${copied}" == false ]]; then
    return 1
  fi
  return 0
}

cp -f "${AERO_LIB}" "${APP_FRAMEWORKS_DIR}/"
copy_if_exists "${FFMPEG_ROOT}/lib/*.dylib" || true
copy_if_exists "${BUILD_DIR}/**/libggml*.dylib" || true
copy_if_exists "${BUILD_DIR}/**/libbs_roformer*.dylib" || true

fix_install_names() {
  local dylib="$1"
  local basename
  basename="$(basename "${dylib}")"
  install_name_tool -id "@rpath/${basename}" "${dylib}" || true
  while IFS= read -r dep; do
    local dep_base
    dep_base="$(basename "${dep}")"
    if [[ -f "${APP_FRAMEWORKS_DIR}/${dep_base}" ]]; then
      install_name_tool -change "${dep}" "@rpath/${dep_base}" "${dylib}" || true
    fi
  done < <(otool -L "${dylib}" | awk 'NR>1 {print $1}')
}

while IFS= read -r dylib; do
  fix_install_names "${dylib}"
done < <(find "${APP_FRAMEWORKS_DIR}" -type f -name "*.dylib")

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  while IFS= read -r dylib; do
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "${dylib}"
  done < <(find "${APP_FRAMEWORKS_DIR}" -type f -name "*.dylib")
fi

if ! otool -L "${APP_FRAMEWORKS_DIR}/libaero_separator_ffi.dylib" >/dev/null 2>&1; then
  echo "Failed to inspect packaged libaero_separator_ffi.dylib" >&2
  exit 1
fi

echo "[apple-tools] Packaged runtime dylibs into ${APP_FRAMEWORKS_DIR}"
