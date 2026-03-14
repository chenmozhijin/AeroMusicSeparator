#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: package_macos_release.sh \
  --app-path <path> \
  --version <version> \
  --variant <variant> \
  --output-dir <path>
EOF
}

APP_PATH=""
VERSION=""
VARIANT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      APP_PATH="$2"
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

for required in APP_PATH VERSION VARIANT OUTPUT_DIR; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required argument: ${required}" >&2
    usage >&2
    exit 1
  fi
done

APP_PATH="$(cd "$(dirname "${APP_PATH}")" && pwd)/$(basename "${APP_PATH}")"
OUTPUT_DIR="$(mkdir -p "${OUTPUT_DIR}" && cd "${OUTPUT_DIR}" && pwd)"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected macOS app bundle at ${APP_PATH}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

DMG_ROOT="${TMP_DIR}/dmg-root"
mkdir -p "${DMG_ROOT}"
ditto "${APP_PATH}" "${DMG_ROOT}/$(basename "${APP_PATH}")"
ln -s /Applications "${DMG_ROOT}/Applications"

OUTPUT_PATH="${OUTPUT_DIR}/AeroMusicSeparator-${VERSION}-macos-${VARIANT}.dmg"
rm -f "${OUTPUT_PATH}"

hdiutil create \
  -volname "AeroMusicSeparator ${VERSION}" \
  -srcfolder "${DMG_ROOT}" \
  -ov \
  -format UDZO \
  "${OUTPUT_PATH}" >/dev/null

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  echo "Expected DMG output at ${OUTPUT_PATH}" >&2
  exit 1
fi

echo "Created ${OUTPUT_PATH}"
