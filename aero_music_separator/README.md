# Aero Music Separator

Flutter client with a native FFI core:

- Native core: `aero_music_separator/native` (`FFmpeg + BSRoformer.cpp`)
- Model runtime: `../BSRoformer.cpp` submodule
- FFI API: `native/include/ams_ffi.h`

## Repository layout

```text
AeroMusicSeparator/
  BSRoformer.cpp/
  aero_music_separator/
```

## What is implemented

- C ABI engine/job interface: open, start, poll, cancel, result, destroy
- FFmpeg decode + resample to `44.1kHz stereo float`
- BSRoformer inference with `cancel_callback` pass-through
- FFmpeg output encoding: `WAV`, `FLAC`, `MP3`
- Flutter FFI layer and basic UI for running tasks
- CI workflows:
  - `.github/workflows/test-ci.yml`
  - `.github/workflows/full-build.yml`

## Build prerequisites

### Common

- `BSRoformer.cpp` submodule initialized
- `ggml` source available at `../ggml` **or** pass `-DGGML_DIR=...`

## Runtime support

- Native separation runtime is currently supported on:
  - Windows
  - Linux
  - Android
  - macOS (`x86_64` / `arm64`)
  - iOS (`arm64` device + simulators)
- iOS release policy for this repository is sideload distribution.

### FFmpeg

- FFmpeg prebuild scripts under `native/tools/ffmpeg` enforce an LGPL profile (`CONFIG_GPL=0`, `CONFIG_VERSION3=0`).
- MP3 encoding is provided by `libmp3lame`.
- Generated FFmpeg bundles include license texts at `native/third_party/ffmpeg/<platform>/<arch>/licenses/`.
- Linux/macOS: install system FFmpeg dev packages (`libavformat`, `libavcodec`, `libavutil`, `libswresample`)
- Windows: place prebuilt FFmpeg under:

```text
aero_music_separator/native/third_party/ffmpeg/windows/x64/
  include/
  lib/
```

## Flutter dependencies

Run in `aero_music_separator/`:

```bash
flutter pub get
```

## Notes

- Web is intentionally out of scope.
- Android pipeline expects prebuilt FFmpeg artifacts under `native/third_party/ffmpeg/android`.

### Android Vulkan compatibility

- On some Android GPU drivers, Vulkan may crash during model import (weight buffer allocation stage).
- Android runtime now enables a Vulkan safe mode for `Auto` / `Vulkan` backend selection by setting:
  - `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1`
  - `GGML_VK_ALLOW_SYSMEM_FALLBACK=1`
- If a specific device still crashes, enable **Use CPU Inference** in app settings as a stable fallback.

## File Picker Notes

- The app uses `file_picker` for model/audio selection and export.
- iOS uses CocoaPods integration (`ios/Podfile`) and declares a custom `.gguf` document type in `ios/Runner/Info.plist`.
- Export flow is cross-platform:
  - Android/Desktop: try directory export first.
  - iOS: if directory selection is unavailable on the device/provider, the app falls back to per-file Save dialogs.

## File Picker Troubleshooting

Use this recovery flow for iOS plugin build issues:

```bash
flutter clean
```

```bash
rm -rf ios/Pods ios/Podfile.lock
```

```bash
pod repo update
pod install --repo-update
```

If plugin registration or pod sync still fails, run `flutter pub get` again and reopen the iOS workspace from `ios/Runner.xcworkspace`.
