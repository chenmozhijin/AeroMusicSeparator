#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def expect_equal(name: str, actual, expected) -> None:
    if actual != expected:
        raise SystemExit(
            f"[ffmpeg-license-verify] {name} mismatch: expected {expected!r}, got {actual!r}"
        )


def expect_manifest_file(manifest: dict, rel_path: str) -> None:
    files = manifest.get("files")
    if not isinstance(files, list):
        raise SystemExit("[ffmpeg-license-verify] manifest 'files' is missing or not a list")

    for entry in files:
        if isinstance(entry, dict) and entry.get("path") == rel_path:
            return
    raise SystemExit(f"[ffmpeg-license-verify] missing file in manifest: {rel_path}")


def expect_manifest_file_suffix(manifest: dict, suffix: str) -> None:
    files = manifest.get("files")
    if not isinstance(files, list):
        raise SystemExit("[ffmpeg-license-verify] manifest 'files' is missing or not a list")

    for entry in files:
        if isinstance(entry, dict):
            rel_path = entry.get("path")
            if isinstance(rel_path, str) and rel_path.endswith(suffix):
                return
    raise SystemExit(f"[ffmpeg-license-verify] missing file in manifest (suffix): {suffix}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify FFmpeg package manifest license profile invariants"
    )
    parser.add_argument("--manifest", required=True, help="Path to manifest.json")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise SystemExit("[ffmpeg-license-verify] manifest root must be a JSON object")

    expect_equal("ffmpeg_license", manifest.get("ffmpeg_license"), "LGPL-2.1-or-later")
    expect_equal("lame_license", manifest.get("lame_license"), "LGPL")
    expect_equal("gpl_enabled", manifest.get("gpl_enabled"), False)
    expect_equal("version3_enabled", manifest.get("version3_enabled"), False)
    expect_equal("mp3_encoder", manifest.get("mp3_encoder"), "libmp3lame")

    platform = manifest.get("platform")
    if platform == "ios":
        expect_manifest_file_suffix(manifest, "licenses/FFmpeg-LGPL.txt")
        expect_manifest_file_suffix(manifest, "licenses/LAME-LICENSE.txt")
    else:
        expect_manifest_file(manifest, "licenses/FFmpeg-LGPL.txt")
        expect_manifest_file(manifest, "licenses/LAME-LICENSE.txt")

    print(f"[ffmpeg-license-verify] OK: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
