#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="$(cd "${NATIVE_DIR}/.." && pwd)"
REPO_DIR="$(cd "${APP_DIR}/.." && pwd)"

FEATURES_FILE="${SCRIPT_DIR}/features.env"

if [[ ! -f "${FEATURES_FILE}" ]]; then
  echo "features.env not found at ${FEATURES_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${FEATURES_FILE}"

: "${AMS_FFMPEG_VERSION:=${AMS_FFMPEG_VERSION_DEFAULT}}"
: "${AMS_LAME_VERSION:=${AMS_LAME_VERSION_DEFAULT}}"
: "${AMS_USE_SCCACHE:=ON}"
: "${AMS_FFMPEG_CACHE_DIR:=${REPO_DIR}/.cache/ffmpeg-src}"
: "${AMS_FFMPEG_BUILD_DIR:=${REPO_DIR}/.cache/ffmpeg-build}"
: "${AMS_FFMPEG_OUT_BASE:=${NATIVE_DIR}/third_party/ffmpeg}"
: "${AMS_JOBS:=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

ensure_tool() {
  local tool_name="$1"
  if ! command -v "${tool_name}" >/dev/null 2>&1; then
    echo "Required tool not found: ${tool_name}" >&2
    exit 1
  fi
}

ensure_dir() {
  local dir_path="$1"
  mkdir -p "${dir_path}"
}

fetch_and_extract_tar_gz() {
  local url="$1"
  local archive_name="$2"
  local extract_dir="$3"
  local source_root="$4"

  ensure_dir "${source_root}"
  ensure_dir "${extract_dir}"

  local archive_path="${source_root}/${archive_name}"
  if [[ ! -f "${archive_path}" ]]; then
    echo "[ffmpeg-tools] downloading ${url}" >&2
    curl -L --retry 3 --retry-delay 3 -o "${archive_path}" "${url}"
  fi

  if [[ -d "${extract_dir}" && -n "$(ls -A "${extract_dir}" 2>/dev/null)" ]]; then
    return
  fi

  rm -rf "${extract_dir}"
  ensure_dir "${extract_dir}"
  tar -xzf "${archive_path}" -C "${extract_dir}" --strip-components=1
}

with_sccache() {
  local compiler="$1"
  if [[ "${AMS_USE_SCCACHE}" != "ON" ]]; then
    echo "${compiler}"
    return
  fi
  if command -v sccache >/dev/null 2>&1; then
    echo "sccache ${compiler}"
    return
  fi
  echo "${compiler}"
}

build_lame() {
  local src_dir="$1"
  local install_prefix="$2"
  local host_triple="$3"
  local cc_cmd="$4"
  local cflags="$5"
  local ldflags="$6"
  local ar_cmd="$7"
  local ranlib_cmd="$8"
  local strip_cmd="$9"

  local lame_src="${src_dir}/lame"
  fetch_and_extract_tar_gz \
    "https://downloads.sourceforge.net/project/lame/lame/${AMS_LAME_VERSION}/lame-${AMS_LAME_VERSION}.tar.gz" \
    "lame-${AMS_LAME_VERSION}.tar.gz" \
    "${lame_src}" \
    "${AMS_FFMPEG_CACHE_DIR}"

  pushd "${lame_src}" >/dev/null
  make distclean >/dev/null 2>&1 || true

  if [[ -n "${host_triple}" ]]; then
    env \
      CC="${cc_cmd}" \
      AR="${ar_cmd}" \
      RANLIB="${ranlib_cmd}" \
      STRIP="${strip_cmd}" \
      CFLAGS="${cflags}" \
      LDFLAGS="${ldflags}" \
      ./configure \
        --host="${host_triple}" \
        --prefix="${install_prefix}" \
        --enable-static \
        --disable-shared \
        --disable-frontend \
        --disable-decoder
  else
    env \
      CC="${cc_cmd}" \
      AR="${ar_cmd}" \
      RANLIB="${ranlib_cmd}" \
      STRIP="${strip_cmd}" \
      CFLAGS="${cflags}" \
      LDFLAGS="${ldflags}" \
      ./configure \
        --prefix="${install_prefix}" \
        --enable-static \
        --disable-shared \
        --disable-frontend \
        --disable-decoder
  fi

  make -j"${AMS_JOBS}"
  make install
  popd >/dev/null
}

ffmpeg_feature_flags() {
  local flags=()
  for v in ${AMS_ENABLE_PROTOCOLS}; do
    flags+=("--enable-protocol=${v}")
  done
  for v in ${AMS_ENABLE_DEMUXERS}; do
    flags+=("--enable-demuxer=${v}")
  done
  for v in ${AMS_ENABLE_MUXERS}; do
    flags+=("--enable-muxer=${v}")
  done
  for v in ${AMS_ENABLE_PARSERS}; do
    flags+=("--enable-parser=${v}")
  done
  for v in ${AMS_ENABLE_DECODERS}; do
    flags+=("--enable-decoder=${v}")
  done
  for v in ${AMS_ENABLE_ENCODERS}; do
    flags+=("--enable-encoder=${v}")
  done
  printf '%s\n' "${flags[@]}"
}

ffmpeg_base_flags() {
  cat <<EOF
--disable-everything
--disable-autodetect
--disable-programs
--disable-doc
--disable-network
--disable-avdevice
--disable-postproc
--disable-swscale
--disable-bsfs
--disable-filters
--disable-hwaccels
--enable-avcodec
--enable-avformat
--enable-avutil
--enable-swresample
--enable-small
--enable-pic
EOF
}

assert_config_flag() {
  local config_path="$1"
  local macro_name="$2"
  local expected_value="$3"

  if grep -Eq "^#define[[:space:]]+${macro_name}[[:space:]]+${expected_value}$" "${config_path}"; then
    return
  fi

  echo "[ffmpeg-tools] configure verification failed: expected ${macro_name}=${expected_value}" >&2
  local actual_line
  actual_line="$(grep -E "^#define[[:space:]]+${macro_name}[[:space:]]+" "${config_path}" | head -n1 || true)"
  if [[ -n "${actual_line}" ]]; then
    echo "[ffmpeg-tools] actual: ${actual_line}" >&2
  else
    echo "[ffmpeg-tools] actual: ${macro_name} not defined in ${config_path}" >&2
  fi
  exit 1
}

verify_ffmpeg_lgpl_profile() {
  local ffmpeg_src="$1"
  local config_h="${ffmpeg_src}/config.h"
  if [[ ! -f "${config_h}" ]]; then
    echo "[ffmpeg-tools] configure verification failed: config.h not found at ${config_h}" >&2
    exit 1
  fi

  assert_config_flag "${config_h}" "CONFIG_GPL" "0"
  assert_config_flag "${config_h}" "CONFIG_VERSION3" "0"
  assert_config_flag "${config_h}" "CONFIG_LIBMP3LAME" "1"
}

stage_third_party_licenses() {
  local ffmpeg_src="$1"
  local lame_src="$2"
  local out_root="$3"

  local licenses_dir="${out_root}/licenses"
  ensure_dir "${licenses_dir}"

  local ffmpeg_license_src=""
  for candidate in \
    "${ffmpeg_src}/COPYING.LGPLv2.1" \
    "${ffmpeg_src}/COPYING.LGPLv3"; do
    if [[ -f "${candidate}" ]]; then
      ffmpeg_license_src="${candidate}"
      break
    fi
  done
  if [[ -z "${ffmpeg_license_src}" ]]; then
    echo "[ffmpeg-tools] missing FFmpeg LGPL license text under ${ffmpeg_src}" >&2
    exit 1
  fi

  local lame_license_src=""
  for candidate in \
    "${lame_src}/COPYING" \
    "${lame_src}/LICENSE"; do
    if [[ -f "${candidate}" ]]; then
      lame_license_src="${candidate}"
      break
    fi
  done
  if [[ -z "${lame_license_src}" ]]; then
    echo "[ffmpeg-tools] missing LAME license text under ${lame_src}" >&2
    exit 1
  fi

  cp -f "${ffmpeg_license_src}" "${licenses_dir}/FFmpeg-LGPL.txt"
  cp -f "${lame_license_src}" "${licenses_dir}/LAME-LICENSE.txt"
}

configure_ffmpeg() {
  local ffmpeg_src="$1"
  shift
  local extra_flags=("$@")

  local args=()
  while IFS= read -r flag; do
    [[ -z "${flag}" ]] && continue
    args+=("${flag}")
  done < <(ffmpeg_base_flags)

  while IFS= read -r flag; do
    [[ -z "${flag}" ]] && continue
    args+=("${flag}")
  done < <(ffmpeg_feature_flags)

  args+=("${extra_flags[@]}")

  pushd "${ffmpeg_src}" >/dev/null
  ./configure "${args[@]}"
  verify_ffmpeg_lgpl_profile "${ffmpeg_src}"
  popd >/dev/null
}

build_ffmpeg() {
  local ffmpeg_src="$1"
  pushd "${ffmpeg_src}" >/dev/null
  make -j"${AMS_JOBS}"
  make install
  popd >/dev/null
}

prepare_ffmpeg_source() {
  local src_root="$1"
  local ffmpeg_src="${src_root}/ffmpeg"
  fetch_and_extract_tar_gz \
    "https://ffmpeg.org/releases/ffmpeg-${AMS_FFMPEG_VERSION#n}.tar.gz" \
    "ffmpeg-${AMS_FFMPEG_VERSION#n}.tar.gz" \
    "${ffmpeg_src}" \
    "${AMS_FFMPEG_CACHE_DIR}"
  printf '%s\n' "${ffmpeg_src}"
}
