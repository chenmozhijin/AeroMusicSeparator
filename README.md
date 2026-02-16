# Aero Music Separator

[English](README.en.md) | 中文

**Aero Music Separator** 是一个基于 **Flutter** 和 **Native FFI** 的高性能本地离线音乐分离应用。核心推理引擎采用 [BSRoformer.cpp](https://github.com/chenmozhijin/BSRoformer.cpp)，支持 `BSRoformer` 和 `Mel-Band-Roformer` 模型。

## ✨ 核心特性

- 🔒 **完全本地离线**：无需上传音频，保护隐私。
- 🚀 **高性能推理**：C++ 核心 (BSRoformer.cpp)，支持 CPU/GPU 加速。
- 📦 **GGUF 模型支持**：支持加载量化后的 `*.gguf` 模型文件。
- 🎵 **多格式支持**：
  - 输入：自动标准化重采样（44.1kHz 立体声）。
  - 导出：支持 `WAV`, `FLAC`, `MP3` 格式。
- 🖥️ **跨平台支持**：Windows, macOS, Linux, Android, iOS。
- 📊 **完整交互**：任务进度显示、详细日志、随时取消。

## 📥 下载与安装

请前往 [Releases](../../releases) 页面下载对应平台的发布包。

### 平台说明

| 平台 | 架构 | 状态 | 备注 |
| --- | --- | --- | --- |
| **Windows** | x64 | ✅ 支持 | 解压即用 |
| **macOS** | x64 / arm64 | ✅ 支持 | 包含独立的 .app |
| **Linux** | x64 | ✅ 支持 | AppImage 或二进制包 |
| **Android** | arm64 / v7a / x64 | ✅ 支持 | 提供 APK 安装包 |
| **iOS** | arm64 | ⚠️ 侧载 | 仅支持侧载或企业证书分发，未上架 App Store |

## 🚀 快速开始

### 1. 获取应用
下载并安装适合您设备的应用版本。

### 2. 获取模型
本应用不内置模型，您需要单独下载 `.gguf` 格式的模型文件。
推荐下载地址：
- **HuggingFace**: [chenmozhijin/BSRoformer-GGUF](https://huggingface.co/chenmozhijin/BSRoformer-GGUF)

> **注意**：下载后请记住模型文件的保存位置。

### 3. 开始分离
1. 打开应用。
2. **选择模型**：点击模型选择按钮，加载下载好的 `.gguf` 文件。
3. **选择音频**：选择需要分离的音乐文件。
4. **开始任务**：点击开始按钮，等待预处理和推理完成。
5. **导出结果**：任务完成后，选择导出格式和路径保存分离后的音轨（人声/伴奏）。

## 🛠️ 源码构建

如果您是开发者，可以按照以下步骤从源码构建。

### 前置要求
- **Flutter SDK**: 最新稳定版
- **CMake**: >= 3.17
- **C++ 编译器**: MSVC 2019+, GCC 9+, Clang 10+
- **Git**: 用于拉取子模块

### 构建步骤

1. **克隆仓库**:
   ```bash
   git clone --recursive https://github.com/Starttime/AeroMusicSeparator.git
   cd AeroMusicSeparator
   ```

2. **初始化子模块** (如果未递归克隆):
   ```bash
   git submodule update --init --recursive
   ```

3. **Flutter 依赖**:
   ```bash
   cd aero_music_separator
   flutter pub get
   ```

4. **构建运行**:
   ```bash
   flutter run -d windows  # 或 macos, linux
   ```

> **注意**：Native 核心依赖 FFmpeg。构建脚本会自动处理大部分依赖，但 Linux/macOS 开发环境可能需要安装系统级的 FFmpeg 开发库（如 `libavcodec-dev` 等）。

## 📄 许可证与合规

- **主程序**: [GPL-3.0-only](LICENSE)
- **核心引擎**: [BSRoformer.cpp](https://github.com/chenmozhijin/BSRoformer.cpp) (MIT)
- **依赖组件**:
  - FFmpeg (LGPL)
  - ggml (MIT)
  - flutter_rust_bridge (MIT/Apache-2.0)

详细合规说明请参阅 [COMPLIANCE.md](COMPLIANCE.md)。
应用内开源许可证明示位于：`设置 -> 关于 -> 开源许可`。
