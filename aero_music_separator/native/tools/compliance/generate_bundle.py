#!/usr/bin/env python3
"""Generate a release compliance bundle for Aero Music Separator."""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import shutil
import textwrap
from pathlib import Path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _copy_required(src: Path, dst: Path) -> None:
    if not src.exists():
        raise FileNotFoundError(f"required file is missing: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _read_manifest(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _build_source_offer(repo_root: Path, commit: str) -> str:
    return textwrap.dedent(
        f"""\
        Aero Music Separator - Source & License Notice
        =============================================

        This distribution is released under GPL-3.0-only for project-owned code.
        Third-party components keep their original licenses.

        Build commit:
          {commit}

        Source code:
          - Repository root snapshot used for this build.
          - Native build scripts under:
            aero_music_separator/native/tools/
          - FFmpeg profile scripts under:
            aero_music_separator/native/tools/ffmpeg/

        If you received a binary copy and need corresponding source artifacts,
        contact the distributor of this binary and request the matching source
        bundle and build scripts.

        This notice is provided to support GPLv3/LGPL compliance workflows and
        does not replace legal advice.
        """
    ).strip() + "\n"


def _write_summary(
    output_root: Path,
    manifest_rows: list[tuple[str, str, str, str]],
    commit: str,
) -> None:
    lines = [
        "# Third-Party Summary",
        "",
        f"- Generated at: {_dt.datetime.now(_dt.UTC).isoformat()}",
        f"- Source commit: `{commit}`",
        "",
        "## License Files Included",
        "",
        "- `LICENSES/GPL-3.0.txt`",
        "- `LICENSES/FFmpeg-LGPL.txt`",
        "- `LICENSES/LAME-LICENSE.txt`",
        "- `LICENSES/BSRoformer-LICENSE.txt`",
        "- `LICENSES/ggml-LICENSE.txt`",
        "",
        "## FFmpeg Build Manifests",
        "",
        "| Platform | Arch | FFmpeg | LAME |",
        "| --- | --- | --- | --- |",
    ]
    for platform, arch, ffmpeg_version, lame_version in manifest_rows:
        lines.append(f"| {platform} | {arch} | {ffmpeg_version} | {lame_version} |")

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- FFmpeg builds are expected to use LGPL profile (`CONFIG_GPL=0`, `CONFIG_VERSION3=0`).",
            "- This summary is generated from `native/third_party/ffmpeg/**/manifest.json`.",
        ]
    )

    (output_root / "THIRD_PARTY_SUMMARY.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def _write_build_repro(output_root: Path) -> None:
    content = textwrap.dedent(
        """\
        # Build Reproduction (Reference)

        Run from repository root:

        - Build FFmpeg bundles:
          - `aero_music_separator/native/tools/ffmpeg/build_linux.sh <arch>`
          - `aero_music_separator/native/tools/ffmpeg/build_windows.ps1 -Arch x64`
          - `aero_music_separator/native/tools/ffmpeg/build_macos.sh <x86_64|arm64>`
          - `aero_music_separator/native/tools/ffmpeg/build_ios.sh <arm64|x86_64>`
          - `aero_music_separator/native/tools/ffmpeg/build_android.sh <abi>`

        - Build macOS native runtime helper:
          - `aero_music_separator/native/tools/apple/build_macos_native.sh <x86_64|arm64>`

        - Build iOS XCFramework:
          - `aero_music_separator/native/tools/apple/build_ios_ffi_xcframework.sh <arm64|x86_64>`

        CI workflow references:
        - `.github/workflows/full-build.yml`
        - `.github/workflows/test-ci.yml`
        """
    )
    (output_root / "BUILD_REPRODUCTION.md").write_text(content, encoding="utf-8")


def _write_checksums(output_root: Path) -> None:
    checksum_path = output_root / "checksums.sha256"
    rows: list[str] = []
    for file_path in sorted(output_root.rglob("*")):
        if not file_path.is_file():
            continue
        if file_path == checksum_path:
            continue
        rel = file_path.relative_to(output_root).as_posix()
        rows.append(f"{_sha256(file_path)}  {rel}")
    checksum_path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def _validate_strict(output_root: Path, manifest_count: int) -> None:
    required = [
        output_root / "LICENSES" / "GPL-3.0.txt",
        output_root / "LICENSES" / "FFmpeg-LGPL.txt",
        output_root / "LICENSES" / "LAME-LICENSE.txt",
        output_root / "LICENSES" / "BSRoformer-LICENSE.txt",
        output_root / "LICENSES" / "ggml-LICENSE.txt",
        output_root / "SOURCE_CODE_OFFER.txt",
        output_root / "THIRD_PARTY_SUMMARY.md",
        output_root / "BUILD_REPRODUCTION.md",
        output_root / "checksums.sha256",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise RuntimeError(f"strict validation failed, missing files: {missing}")
    if manifest_count == 0:
        raise RuntimeError("strict validation failed, no FFmpeg manifest found")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[4]),
        help="Path to repository root",
    )
    parser.add_argument(
        "--out",
        required=True,
        help="Output directory for compliance bundle",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if required files/manifests are missing",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()

    if out_root.exists():
        shutil.rmtree(out_root)
    out_root.mkdir(parents=True, exist_ok=True)
    licenses_dir = out_root / "LICENSES"
    manifests_dir = out_root / "FFMPEG_MANIFESTS"
    licenses_dir.mkdir(parents=True, exist_ok=True)
    manifests_dir.mkdir(parents=True, exist_ok=True)

    _copy_required(repo_root / "LICENSE", licenses_dir / "GPL-3.0.txt")
    _copy_required(
        repo_root / "aero_music_separator" / "assets" / "licenses" / "FFmpeg-LGPL.txt",
        licenses_dir / "FFmpeg-LGPL.txt",
    )
    _copy_required(
        repo_root / "aero_music_separator" / "assets" / "licenses" / "LAME-LICENSE.txt",
        licenses_dir / "LAME-LICENSE.txt",
    )
    _copy_required(
        repo_root / "aero_music_separator" / "assets" / "licenses" / "BSRoformer-LICENSE.txt",
        licenses_dir / "BSRoformer-LICENSE.txt",
    )
    _copy_required(
        repo_root / "aero_music_separator" / "assets" / "licenses" / "ggml-LICENSE.txt",
        licenses_dir / "ggml-LICENSE.txt",
    )

    commit = (
        os.environ.get("GITHUB_SHA")
        or os.environ.get("CI_COMMIT_SHA")
        or "unknown-commit"
    )
    (out_root / "SOURCE_CODE_OFFER.txt").write_text(
        _build_source_offer(repo_root, commit), encoding="utf-8"
    )

    manifest_rows: list[tuple[str, str, str, str]] = []
    manifest_paths = sorted(
        (
            repo_root
            / "aero_music_separator"
            / "native"
            / "third_party"
            / "ffmpeg"
        ).glob("**/manifest.json")
    )
    for manifest_path in manifest_paths:
        manifest = _read_manifest(manifest_path)
        platform = str(manifest.get("platform", "unknown"))
        arch = str(manifest.get("arch", "unknown"))
        ffmpeg_version = str(manifest.get("ffmpeg_version", "unknown"))
        lame_version = str(manifest.get("lame_version", "unknown"))
        manifest_rows.append((platform, arch, ffmpeg_version, lame_version))
        relative = manifest_path.relative_to(
            repo_root / "aero_music_separator" / "native" / "third_party" / "ffmpeg"
        )
        destination = manifests_dir / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(manifest_path, destination)

    _write_summary(out_root, manifest_rows, commit)
    _write_build_repro(out_root)
    _write_checksums(out_root)

    if args.strict:
        _validate_strict(out_root, len(manifest_rows))

    print(f"[compliance] bundle generated at: {out_root}")
    print(f"[compliance] manifests copied: {len(manifest_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
