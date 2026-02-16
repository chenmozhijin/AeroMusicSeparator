# Aero Music Separator

[中文](README.md) | English

**Aero Music Separator** is a high-performance, offline music separation application built with **Flutter** and **Native FFI**. The core inference engine is powered by [BSRoformer.cpp](https://github.com/chenmozhijin/BSRoformer.cpp), supporting `BSRoformer` and `Mel-Band-Roformer` models.

## ✨ Key Features

- 🔒 **100% Offline**: No audio upload required, protecting your privacy.
- 🚀 **High Performance**: C++ core (BSRoformer.cpp) with CPU/GPU acceleration support.
- 📦 **GGUF Support**: Compatible with quantized `*.gguf` model files.
- 🎵 **Multi-Format**:
  - Input: Automatic normalization and resampling (44.1kHz stereo).
  - Export: Supports `WAV`, `FLAC`, and `MP3`.
- 🖥️ **Cross-Platform**: Windows, macOS, Linux, Android, iOS.
- 📊 **Full Control**: Task progress tracking, detailed logs, and cancellation support.

## 📥 Download & Installation

Please download the release package for your platform from the [Releases](../../releases) page.

### Platform Support

| Platform | Architecture | Status | Notes |
| --- | --- | --- | --- |
| **Windows** | x64 | ✅ Supported | Portable zip |
| **macOS** | x64 / arm64 | ✅ Supported | DMG / App |
| **Linux** | x64 | ✅ Supported | AppImage or binary |
| **Android** | arm64 / v7a / x64 | ✅ Supported | APK available |
| **iOS** | arm64 | ⚠️ Sideload | Sideload or Enterprise distribution only (No App Store) |

## 🚀 Quick Start

### 1. Get the App
Download and install the version matching your device.

### 2. Get a Model
The app does not come with built-in models. You need to download `*.gguf` model files separately.
Recommended source:
- **HuggingFace**: [chenmozhijin/BSRoformer-GGUF](https://huggingface.co/chenmozhijin/BSRoformer-GGUF)

> **Note**: Remember where you save the `.gguf` file.

### 3. Start Separation
1. Open the app.
2. **Select Model**: Click the model selection button and load your `.gguf` file.
3. **Select Audio**: Choose the music file you want to separate.
4. **Start**: Click the start button and wait for preprocessing and inference.
5. **Export**: Once finished, choose a format and path to save the separated tracks (Vocals/Instrumental).

## 🛠️ Build from Source

For developers who want to build from source.

### Prerequisites
- **Flutter SDK**: Latest Stable
- **CMake**: >= 3.17
- **C++ Compiler**: MSVC 2019+, GCC 9+, Clang 10+
- **Git**: For submodules

### Build Steps

1. **Clone Repository**:
   ```bash
   git clone --recursive https://github.com/Starttime/AeroMusicSeparator.git
   cd AeroMusicSeparator
   ```

2. **Init Submodules** (if not cloned recursively):
   ```bash
   git submodule update --init --recursive
   ```

3. **Flutter Dependencies**:
   ```bash
   cd aero_music_separator
   flutter pub get
   ```

4. **Run**:
   ```bash
   flutter run -d windows  # or macos, linux
   ```

> **Note**: The native core depends on FFmpeg. Build scripts handle most dependencies, but Linux/macOS dev environments might require system-level FFmpeg dev libraries (e.g., `libavcodec-dev`).

## 📄 License & Compliance

- **Main App**: [GPL-3.0-only](LICENSE)
- **Core Engine**: [BSRoformer.cpp](https://github.com/chenmozhijin/BSRoformer.cpp) (MIT)
- **Dependencies**:
  - FFmpeg (LGPL)
  - ggml (MIT)
  - flutter_rust_bridge (MIT/Apache-2.0)

See [COMPLIANCE.md](COMPLIANCE.md) for details.
In-app open source licenses can be found at: `Settings -> About -> Licenses`.
