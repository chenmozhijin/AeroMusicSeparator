import 'dart:io';

import 'package:aero_music_separator/core/separation/result_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ResultCacheManager keeps only latest cache directory', () async {
    final baseTemp = await Directory.systemTemp.createTemp('ams_cache_test_');
    try {
      final manager = ResultCacheManager(tempDirProvider: () async => baseTemp);

      final firstDir = await manager.prepareLatestRunDir();
      final firstFile = File('$firstDir${Platform.pathSeparator}old.wav');
      await firstFile.writeAsString('old');
      expect(await firstFile.exists(), isTrue);

      final secondDir = await manager.prepareLatestRunDir();
      expect(secondDir, firstDir);
      expect(await firstFile.exists(), isFalse);
      expect(await Directory(secondDir).exists(), isTrue);
    } finally {
      if (await baseTemp.exists()) {
        await baseTemp.delete(recursive: true);
      }
    }
  });
}
