#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: package_android_release.sh \
  --app-dir <path> \
  --version <version> \
  --variant <variant> \
  --output-dir <path>
EOF
}

APP_DIR=""
VERSION=""
VARIANT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-dir)
      APP_DIR="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in APP_DIR VERSION VARIANT OUTPUT_DIR; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required argument: ${required}" >&2
    usage >&2
    exit 1
  fi
done

APP_DIR="$(cd "${APP_DIR}" && pwd)"
OUTPUT_DIR="$(mkdir -p "${OUTPUT_DIR}" && cd "${OUTPUT_DIR}" && pwd)"

APK_PATH=""
for candidate_root in \
  "${APP_DIR}/build/app/outputs/flutter-apk" \
  "${APP_DIR}/android/app/build/outputs/apk/release"; do
  if [[ ! -d "${candidate_root}" ]]; then
    continue
  fi

  while IFS= read -r candidate; do
    APK_PATH="${candidate}"
    break
  done < <(find "${candidate_root}" -type f -name '*release*.apk' | sort)

  if [[ -n "${APK_PATH}" ]]; then
    break
  fi
done

if [[ -z "${APK_PATH}" ]]; then
  echo "Could not find a release APK under ${APP_DIR}" >&2
  exit 1
fi

OUTPUT_PATH="${OUTPUT_DIR}/AeroMusicSeparator-${VERSION}-android-${VARIANT}.apk"
cp -f "${APK_PATH}" "${OUTPUT_PATH}"

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  echo "Expected APK output at ${OUTPUT_PATH}" >&2
  exit 1
fi

echo "Created ${OUTPUT_PATH}"
