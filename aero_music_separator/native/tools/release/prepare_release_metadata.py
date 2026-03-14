#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def sha256sum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-dir", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--notes-out", required=True)
    parser.add_argument("--checksums-out", required=True)
    args = parser.parse_args()

    asset_dir = Path(args.asset_dir)
    notes_out = Path(args.notes_out)
    checksums_out = Path(args.checksums_out)

    assets = sorted(path for path in asset_dir.iterdir() if path.is_file())
    if not assets:
        raise SystemExit(f"No release assets found in {asset_dir}")

    checksum_lines = [f"{sha256sum(asset)}  {asset.name}" for asset in assets]
    checksums_out.write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")

    note_lines = [
        f"# AeroMusicSeparator {args.tag}",
        "",
        "## Packaging Notes",
        "- macOS DMG assets are unsigned.",
        "- The iOS asset is an unsigned zipped xcarchive intended for local signing and IPA export.",
        "- The Android APK uses the repository's current signing configuration.",
        "- A `SHA256SUMS.txt` file is attached alongside the packaged assets.",
        "",
        "## Assets",
    ]
    note_lines.extend(f"- `{asset.name}`" for asset in assets)
    note_lines.append("")

    notes_out.write_text("\n".join(note_lines), encoding="utf-8")


if __name__ == "__main__":
    main()
