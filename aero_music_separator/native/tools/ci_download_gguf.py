#!/usr/bin/env python3
"""
Download a GGUF model for CI integration tests.

Default behavior:
- repository: chenmozhijin/BSRoformer-GGUF
- pick the smallest *.gguf file in the repo
- download to the requested output path
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Optional

from huggingface_hub import HfApi, hf_hub_download, hf_hub_url
from huggingface_hub.utils import HfHubHTTPError, get_hf_file_metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download a GGUF model for CI.")
    parser.add_argument(
        "--repo",
        default="chenmozhijin/BSRoformer-GGUF",
        help="HuggingFace model repository id (default: chenmozhijin/BSRoformer-GGUF)",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output path for the downloaded model file (e.g. .ci-integration/model.gguf)",
    )
    parser.add_argument(
        "--filename",
        default="",
        help="Optional filename in repo. If omitted, pick the smallest *.gguf file.",
    )
    parser.add_argument(
        "--token-env",
        default="HF_TOKEN",
        help="Environment variable name for HF token (default: HF_TOKEN).",
    )
    parser.add_argument(
        "--metadata",
        default="",
        help="Optional metadata JSON output path.",
    )
    return parser.parse_args()


def _file_size(api_url: str, token: Optional[str]) -> Optional[int]:
    try:
        metadata = get_hf_file_metadata(api_url, token=token)
    except HfHubHTTPError:
        return None
    if metadata is None:
        return None
    return metadata.size


def choose_filename(repo: str, requested: str, token: Optional[str]) -> tuple[str, Optional[int]]:
    api = HfApi(token=token)
    files = api.list_repo_files(repo_id=repo, repo_type="model")
    if requested:
        if requested not in files:
            raise FileNotFoundError(f"requested file not found in repo: {requested}")
        size = _file_size(hf_hub_url(repo_id=repo, filename=requested, repo_type="model"), token)
        return requested, size

    gguf_files = [f for f in files if f.lower().endswith(".gguf")]
    if not gguf_files:
        raise FileNotFoundError(f"no .gguf file found in repo: {repo}")

    sized: list[tuple[str, Optional[int]]] = []
    for name in gguf_files:
        size = _file_size(hf_hub_url(repo_id=repo, filename=name, repo_type="model"), token)
        sized.append((name, size))

    # Prefer known sizes first, then smallest by size; fallback to lexicographic order.
    sized.sort(key=lambda item: (item[1] is None, item[1] if item[1] is not None else sys.maxsize, item[0]))
    return sized[0]


def main() -> int:
    args = parse_args()
    token = os.environ.get(args.token_env) or None

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    filename, size = choose_filename(args.repo, args.filename.strip(), token)
    print(f"[ci-model] repo: {args.repo}")
    print(f"[ci-model] selected: {filename}")
    if size is not None:
        print(f"[ci-model] size: {size} bytes")
    else:
        print("[ci-model] size: unknown")

    downloaded = hf_hub_download(
        repo_id=args.repo,
        filename=filename,
        repo_type="model",
        token=token,
    )

    shutil.copyfile(downloaded, output)
    print(f"[ci-model] downloaded to: {output}")

    metadata_path = Path(args.metadata).resolve() if args.metadata else output.parent / "model-meta.json"
    payload = {
        "repo": args.repo,
        "filename": filename,
        "size_bytes": size,
        "output": str(output),
    }
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"[ci-model] metadata: {metadata_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
