import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../platform/file_access_service.dart';

class ManagedFileStore {
  ManagedFileStore({
    Future<Directory> Function()? appSupportDirProvider,
    Future<Directory> Function()? tempDirProvider,
    int maxCachedInputFiles = 20,
  }) : _appSupportDirProvider = appSupportDirProvider,
       _tempDirProvider = tempDirProvider,
       _maxCachedInputFiles = maxCachedInputFiles;

  final Future<Directory> Function()? _appSupportDirProvider;
  final Future<Directory> Function()? _tempDirProvider;
  final int _maxCachedInputFiles;

  static const String _rootDirName = 'aero_music_separator';
  static const String _modelDirName = 'models';
  static const String _activeModelFileName = 'active.gguf';
  static const String _inputCacheDirName = 'input_cache';

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

  Future<String> importInputAudio(PickedSourceFile source) async {
    final sourceFile = await _requireReadableFile(
      source.path,
      stage: 'ffi_read',
      subject: 'input audio',
    );
    final dir = await _inputCacheDirectory();
    await dir.create(recursive: true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitizeName(_fileBaseName(source.name, source.path));
    final extension = _fileExtension(source.name, source.path);

    var candidate = File(
      '${dir.path}${Platform.pathSeparator}${timestamp}_$safeName$extension',
    );
    var sequence = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${dir.path}${Platform.pathSeparator}${timestamp}_${safeName}_$sequence$extension',
      );
      sequence += 1;
    }
    await sourceFile.copy(candidate.path);
    return candidate.path;
  }

  Future<void> cleanupOldInputs() async {
    final dir = await _inputCacheDirectory();
    if (!await dir.exists()) {
      return;
    }
    final entries = await dir
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    if (entries.isEmpty) {
      return;
    }
    final ranked = <MapEntry<File, int>>[];
    for (final file in entries) {
      final stat = await file.stat();
      final score = _inputCacheRank(
        file,
        fallbackMillis: stat.modified.millisecondsSinceEpoch,
      );
      ranked.add(MapEntry<File, int>(file, score));
    }
    ranked.sort((a, b) => b.value.compareTo(a.value));
    if (_maxCachedInputFiles < 0) {
      return;
    }
    for (var i = _maxCachedInputFiles; i < ranked.length; i++) {
      final file = ranked[i].key;
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String?> migrateStoredModelPath(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) {
      return null;
    }
    final trimmed = storedPath.trim();
    final file = File(trimmed);
    if (!await file.exists()) {
      return null;
    }
    if (!await isManagedModelPath(trimmed)) {
      final name = _fileNameFromPath(trimmed);
      return importModel(
        PickedSourceFile(path: trimmed, name: name),
      );
    }
    try {
      await _requireReadableFile(trimmed, stage: 'ffi_read', subject: 'model');
      return trimmed;
    } on FileSystemException {
      return null;
    }
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

  Future<Directory> _tempDirectory() async {
    final provider = _tempDirProvider;
    if (provider != null) {
      return provider();
    }
    return getTemporaryDirectory();
  }

  Future<Directory> _modelDirectory() async {
    final base = await _appSupportDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}$_rootDirName'
      '${Platform.pathSeparator}$_modelDirName',
    );
  }

  Future<Directory> _inputCacheDirectory() async {
    final base = await _tempDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}$_rootDirName'
      '${Platform.pathSeparator}$_inputCacheDirName',
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
      if (_normalizePath(entry.path) == _normalizePath(await _activeModelPath())) {
        continue;
      }
      await entry.delete();
    }
  }

  String _fileBaseName(String preferredName, String fallbackPath) {
    final name = preferredName.trim().isNotEmpty
        ? preferredName.trim()
        : _fileNameFromPath(fallbackPath);
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      return name.substring(0, dotIndex);
    }
    return name;
  }

  String _fileExtension(String preferredName, String fallbackPath) {
    final name = preferredName.trim().isNotEmpty
        ? preferredName.trim()
        : _fileNameFromPath(fallbackPath);
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < name.length - 1) {
      return name.substring(dotIndex);
    }
    return '';
  }

  String _fileNameFromPath(String path) {
    final segments = File(path).uri.pathSegments;
    if (segments.isEmpty) {
      return path;
    }
    return segments.last;
  }

  String _sanitizeName(String rawName) {
    final replaced = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final compact = replaced.replaceAll(RegExp(r'_+'), '_').trim();
    if (compact.isEmpty) {
      return 'input';
    }
    return compact;
  }

  String _normalizePath(String path) {
    final absolute = File(path).absolute.path;
    if (Platform.isWindows) {
      return absolute.toLowerCase();
    }
    return absolute;
  }

  int _inputCacheRank(File file, {required int fallbackMillis}) {
    final name = _fileNameFromPath(file.path);
    final underscore = name.indexOf('_');
    if (underscore <= 0) {
      return fallbackMillis;
    }
    final prefix = name.substring(0, underscore);
    final parsed = int.tryParse(prefix);
    if (parsed == null || parsed <= 0) {
      return fallbackMillis;
    }
    return parsed;
  }
}
