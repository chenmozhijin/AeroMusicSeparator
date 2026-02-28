import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../platform/file_access_service.dart';

class ManagedFileStore {
  ManagedFileStore({Future<Directory> Function()? appSupportDirProvider})
    : _appSupportDirProvider = appSupportDirProvider;

  final Future<Directory> Function()? _appSupportDirProvider;

  static const String _rootDirName = 'aero_music_separator';
  static const String _modelDirName = 'models';
  static const String _activeModelFileName = 'active.gguf';

  Future<String> resolveModelForSelection(
    PickedSourceFile source, {
    required bool cacheModel,
  }) async {
    if (cacheModel) {
      return importModel(source);
    }
    final sourceFile = await _requireReadableFile(
      source.path,
      stage: 'ffi_read',
      subject: 'model',
    );
    return sourceFile.path;
  }

  Future<String> importModel(PickedSourceFile source) async {
    final sourceFile = await _requireReadableFile(
      source.path,
      stage: 'ffi_read',
      subject: 'model',
    );
    final targetPath = await _activeModelPath();
    if (_normalizePath(sourceFile.path) == _normalizePath(targetPath)) {
      return targetPath;
    }

    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    final tempFile = File('$targetPath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await sourceFile.copy(tempFile.path);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
    await _removeInactiveManagedModels(targetFile.parent);
    return targetPath;
  }

  Future<String> resolveInputAudioForSelection(PickedSourceFile source) async {
    final sourceFile = await _requireReadableFile(
      source.path,
      stage: 'ffi_read',
      subject: 'input audio',
    );
    return sourceFile.path;
  }

  Future<String?> migrateStoredModelPath(
    String? storedPath, {
    bool cacheModel = true,
  }) async {
    if (storedPath == null || storedPath.trim().isEmpty) {
      return null;
    }
    final trimmed = storedPath.trim();
    final file = File(trimmed);
    if (!await file.exists()) {
      return null;
    }
    try {
      await _requireReadableFile(trimmed, stage: 'ffi_read', subject: 'model');
    } on FileSystemException {
      return null;
    }
    if (!cacheModel) {
      return trimmed;
    }
    if (!await isManagedModelPath(trimmed)) {
      final name = _fileNameFromPath(trimmed);
      return importModel(PickedSourceFile(path: trimmed, name: name));
    }
    return trimmed;
  }

  Future<bool> isManagedModelPath(String path) async {
    final targetPath = await _activeModelPath();
    return _normalizePath(path) == _normalizePath(targetPath);
  }

  Future<String> activeModelPath() => _activeModelPath();

  Future<Directory> _appSupportDirectory() async {
    final provider = _appSupportDirProvider;
    if (provider != null) {
      return provider();
    }
    return getApplicationSupportDirectory();
  }

  Future<Directory> _modelDirectory() async {
    final base = await _appSupportDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}$_rootDirName'
      '${Platform.pathSeparator}$_modelDirName',
    );
  }

  Future<String> _activeModelPath() async {
    final dir = await _modelDirectory();
    return '${dir.path}${Platform.pathSeparator}$_activeModelFileName';
  }

  Future<File> _requireReadableFile(
    String path, {
    required String stage,
    required String subject,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('$stage: $subject file not found', path);
    }
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      return file;
    } catch (error) {
      throw FileSystemException(
        '$stage: $subject file is not readable ($error)',
        path,
      );
    } finally {
      await handle?.close();
    }
  }

  Future<void> _removeInactiveManagedModels(Directory modelDir) async {
    final entries = await modelDir.list(followLinks: false).toList();
    for (final entry in entries) {
      if (entry is! File) {
        continue;
      }
      if (_normalizePath(entry.path) ==
          _normalizePath(await _activeModelPath())) {
        continue;
      }
      await entry.delete();
    }
  }

  String _fileNameFromPath(String path) {
    final segments = File(path).uri.pathSegments;
    if (segments.isEmpty) {
      return path;
    }
    return segments.last;
  }

  String _normalizePath(String path) {
    final absolute = File(path).absolute.path;
    if (Platform.isWindows) {
      return absolute.toLowerCase();
    }
    return absolute;
  }
}
