#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: package_linux_appimage.sh \
  --bundle-dir <path> \
  --version <version> \
  --variant <variant> \
  --output-dir <path> \
  --appimagetool <path> \
  --icon <path> \
  --desktop-file <path>
EOF
}

BUNDLE_DIR=""
VERSION=""
VARIANT=""
OUTPUT_DIR=""
APPIMAGETOOL=""
ICON_PATH=""
DESKTOP_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-dir)
      BUNDLE_DIR="$2"
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
    --appimagetool)
      APPIMAGETOOL="$2"
      shift 2
      ;;
    --icon)
      ICON_PATH="$2"
      shift 2
      ;;
    --desktop-file)
      DESKTOP_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in BUNDLE_DIR VERSION VARIANT OUTPUT_DIR APPIMAGETOOL ICON_PATH DESKTOP_FILE; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required argument: ${required}" >&2
    usage >&2
    exit 1
  fi
done

BUNDLE_DIR="$(cd "${BUNDLE_DIR}" && pwd)"
OUTPUT_DIR="$(mkdir -p "${OUTPUT_DIR}" && cd "${OUTPUT_DIR}" && pwd)"
APPIMAGETOOL="$(cd "$(dirname "${APPIMAGETOOL}")" && pwd)/$(basename "${APPIMAGETOOL}")"
ICON_PATH="$(cd "$(dirname "${ICON_PATH}")" && pwd)/$(basename "${ICON_PATH}")"
DESKTOP_FILE="$(cd "$(dirname "${DESKTOP_FILE}")" && pwd)/$(basename "${DESKTOP_FILE}")"

MAIN_BINARY="${BUNDLE_DIR}/aero_music_separator"
if [[ ! -x "${MAIN_BINARY}" ]]; then
  echo "Expected Flutter Linux bundle executable at ${MAIN_BINARY}" >&2
  exit 1
fi

if [[ ! -f "${APPIMAGETOOL}" ]]; then
  echo "appimagetool was not found at ${APPIMAGETOOL}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

APPDIR="${TMP_DIR}/AeroMusicSeparator.AppDir"
mkdir -p "${APPDIR}"
cp -a "${BUNDLE_DIR}/." "${APPDIR}/"
install -m 0644 "${DESKTOP_FILE}" "${APPDIR}/AeroMusicSeparator.desktop"
install -m 0644 "${ICON_PATH}" "${APPDIR}/AeroMusicSeparator.png"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${HERE}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
exec "${HERE}/aero_music_separator" "$@"
EOF

chmod +x "${APPDIR}/AppRun" "${APPDIR}/aero_music_separator"

OUTPUT_PATH="${OUTPUT_DIR}/AeroMusicSeparator-${VERSION}-linux-${VARIANT}.AppImage"
rm -f "${OUTPUT_PATH}"

ARCH=x86_64 VERSION="${VERSION}" APPIMAGE_EXTRACT_AND_RUN=1 "${APPIMAGETOOL}" "${APPDIR}" "${OUTPUT_PATH}"

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  echo "Expected AppImage output at ${OUTPUT_PATH}" >&2
  exit 1
fi

echo "Created ${OUTPUT_PATH}"
