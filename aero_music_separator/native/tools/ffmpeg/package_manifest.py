#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate manifest for FFmpeg package directory")
    parser.add_argument("--root", required=True, help="Package root directory")
    parser.add_argument("--platform", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--ffmpeg-version", required=True)
    parser.add_argument("--lame-version", required=True)
    parser.add_argument("--ffmpeg-license", required=True)
    parser.add_argument("--lame-license", required=True)
    parser.add_argument("--gpl-enabled", required=True, choices=("true", "false"))
    parser.add_argument("--version3-enabled", required=True, choices=("true", "false"))
    parser.add_argument("--mp3-encoder", required=True)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        raise FileNotFoundError(f"Root directory not found: {root}")

    files = []
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(root).as_posix()
        files.append(
            {
                "path": rel,
                "size": p.stat().st_size,
                "sha256": sha256_file(p),
            }
        )

    manifest = {
        "platform": args.platform,
        "arch": args.arch,
        "ffmpeg_version": args.ffmpeg_version,
        "lame_version": args.lame_version,
        "ffmpeg_license": args.ffmpeg_license,
        "lame_license": args.lame_license,
        "gpl_enabled": args.gpl_enabled == "true",
        "version3_enabled": args.version3_enabled == "true",
        "mp3_encoder": args.mp3_encoder,
        "file_count": len(files),
        "files": files,
    }

    out = root / "manifest.json"
    out.write_text(json.dumps(manifest, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"[ffmpeg-manifest] wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
