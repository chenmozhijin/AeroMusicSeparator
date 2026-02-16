import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ResultCacheManager {
  ResultCacheManager({Future<Directory> Function()? tempDirProvider})
    : _tempDirProvider = tempDirProvider;

  final Future<Directory> Function()? _tempDirProvider;

  static const String _rootDirName = 'aero_music_separator';
  static const String _cacheDirName = 'result_cache';
  static const String _latestDirName = 'latest';

  Future<Directory> _baseTempDirectory() async {
    final provider = _tempDirProvider;
    if (provider != null) {
      return provider();
    }
    return getTemporaryDirectory();
  }

  Future<Directory> _latestRunDirectory() async {
    final base = await _baseTempDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}$_rootDirName'
      '${Platform.pathSeparator}$_cacheDirName'
      '${Platform.pathSeparator}$_latestDirName',
    );
  }

  Future<void> clearLatestRunDir() async {
    final dir = await _latestRunDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> prepareLatestRunDir() async {
    await clearLatestRunDir();
    final dir = await _latestRunDirectory();
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<List<File>> listStemFiles() async {
    final dir = await _latestRunDirectory();
    if (!await dir.exists()) {
      return <File>[];
    }
    final entities = await dir
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    entities.sort((a, b) => a.path.compareTo(b.path));
    return entities;
  }
}
