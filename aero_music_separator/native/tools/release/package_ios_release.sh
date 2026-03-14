#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: package_ios_release.sh \
  --project-dir <path> \
  --workspace <path> \
  --scheme <name> \
  --version <version> \
  --variant <variant> \
  --output-dir <path> \
  [--archive-path <path>]
EOF
}

PROJECT_DIR=""
WORKSPACE=""
SCHEME="Runner"
VERSION=""
VARIANT=""
OUTPUT_DIR=""
ARCHIVE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
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
    --archive-path)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in PROJECT_DIR WORKSPACE SCHEME VERSION VARIANT OUTPUT_DIR; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required argument: ${required}" >&2
    usage >&2
    exit 1
  fi
done

PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
WORKSPACE_PATH="${PROJECT_DIR}/${WORKSPACE}"
OUTPUT_DIR="$(mkdir -p "${OUTPUT_DIR}" && cd "${OUTPUT_DIR}" && pwd)"

if [[ ! -d "${WORKSPACE_PATH}" ]]; then
  echo "Expected iOS workspace at ${WORKSPACE_PATH}" >&2
  exit 1
fi

if [[ -z "${ARCHIVE_PATH}" ]]; then
  ARCHIVE_PATH="${PROJECT_DIR}/build/ios/archive/Runner.xcarchive"
fi

rm -rf "${ARCHIVE_PATH}"

pushd "${PROJECT_DIR}" >/dev/null
xcodebuild archive \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  COMPILER_INDEX_STORE_ENABLE=NO
popd >/dev/null

APP_IN_ARCHIVE="${ARCHIVE_PATH}/Products/Applications/Runner.app"
if [[ ! -d "${APP_IN_ARCHIVE}" ]]; then
  echo "Expected Runner.app in archive at ${APP_IN_ARCHIVE}" >&2
  exit 1
fi

OUTPUT_PATH="${OUTPUT_DIR}/AeroMusicSeparator-${VERSION}-ios-${VARIANT}.xcarchive.zip"
rm -f "${OUTPUT_PATH}"

ditto -c -k --sequesterRsrc --keepParent "${ARCHIVE_PATH}" "${OUTPUT_PATH}"

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  echo "Expected archive output at ${OUTPUT_PATH}" >&2
  exit 1
fi

echo "Created ${OUTPUT_PATH}"
