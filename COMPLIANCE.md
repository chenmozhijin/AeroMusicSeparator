# Compliance Guide

This repository is distributed under **GPL-3.0-only** for project-owned code.
Third-party components keep their original licenses and must be shipped with
their license texts and build metadata.

## License Baseline

- Project license: `GPL-3.0-only` (`LICENSE`)
- FFmpeg profile: `LGPL-2.1-or-later` (see `aero_music_separator/assets/licenses/FFmpeg-LGPL.txt`)
- LAME: `LGPL` (see `aero_music_separator/assets/licenses/LAME-LICENSE.txt`)
- BSRoformer.cpp: `MIT` (see `aero_music_separator/assets/licenses/BSRoformer-LICENSE.txt`)
- ggml: `MIT` (see `aero_music_separator/assets/licenses/ggml-LICENSE.txt`)

## Distribution Policy

- macOS and iOS are supported build targets in this repository.
- iOS distribution target is **sideload / enterprise** for this release line.
- App Store distribution is out of scope for the current compliance policy.

## Required Release Artifacts

Each external binary release should include:

1. Project license text (`GPL-3.0`)
2. Third-party license texts (FFmpeg/LAME/BSRoformer.cpp/ggml)
3. FFmpeg build manifests (`manifest.json` from each packaged platform/arch)
4. Source/build reproduction notes
5. Source offer / source access instructions
6. Checksums for compliance bundle contents

## Automation

Compliance bundle generation script:

- `aero_music_separator/native/tools/compliance/generate_bundle.py`

Example:

```bash
python3 aero_music_separator/native/tools/compliance/generate_bundle.py \
  --repo-root . \
  --out ./compliance-bundle \
  --strict
```

CI workflow (`.github/workflows/full-build.yml`) uploads a `compliance-bundle`
artifact for release-oriented runs.

## Notes

- GPL compatibility does not remove third-party obligations.
- This document is technical guidance and not legal advice.
