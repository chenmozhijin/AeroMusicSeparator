import 'dart:io';

import 'package:aero_music_separator/core/platform/file_access_service.dart';
import 'package:aero_music_separator/core/storage/managed_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Directory> createTempRoot(String suffix) {
    return Directory.systemTemp.createTemp('ams_store_$suffix');
  }

  test('ManagedFileStore imports and replaces active model', () async {
    final supportRoot = await createTempRoot('support');
    final tempRoot = await createTempRoot('temp');
    addTearDown(() async {
      if (await supportRoot.exists()) {
        await supportRoot.delete(recursive: true);
      }
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final store = ManagedFileStore(
      appSupportDirProvider: () async => supportRoot,
    );

    final source1 = File(
      '${tempRoot.path}${Platform.pathSeparator}source_model_1.gguf',
    );
    final source2 = File(
      '${tempRoot.path}${Platform.pathSeparator}source_model_2.gguf',
    );
    await source1.writeAsString('model-v1');
    await source2.writeAsString('model-v2');

    final managedPath1 = await store.importModel(
      PickedSourceFile(path: source1.path, name: source1.uri.pathSegments.last),
    );
    final managedPath2 = await store.importModel(
      PickedSourceFile(path: source2.path, name: source2.uri.pathSegments.last),
    );

    expect(managedPath1, managedPath2);
    expect(await File(managedPath2).readAsString(), 'model-v2');

    final modelFiles = await File(managedPath2).parent
        .list(followLinks: false)
        .where((entity) => entity is File)
        .toList();
    expect(modelFiles.length, 1);
  });

  test('ManagedFileStore resolves model path without caching', () async {
    final supportRoot = await createTempRoot('support_direct');
    final tempRoot = await createTempRoot('temp_direct');
    addTearDown(() async {
      if (await supportRoot.exists()) {
        await supportRoot.delete(recursive: true);
      }
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final store = ManagedFileStore(
      appSupportDirProvider: () async => supportRoot,
    );
    final source = File('${tempRoot.path}${Platform.pathSeparator}direct.gguf');
    await source.writeAsString('model-direct');

    final resolvedPath = await store.resolveModelForSelection(
      PickedSourceFile(path: source.path, name: source.uri.pathSegments.last),
      cacheModel: false,
    );

    expect(File(resolvedPath).absolute.path, source.absolute.path);
    final activeModelPath = await store.activeModelPath();
    expect(await File(activeModelPath).exists(), isFalse);
  });

  test(
    'ManagedFileStore resolves input path without creating cache copy',
    () async {
      final supportRoot = await createTempRoot('support_input_direct');
      final tempRoot = await createTempRoot('temp_input_direct');
      addTearDown(() async {
        if (await supportRoot.exists()) {
          await supportRoot.delete(recursive: true);
        }
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final store = ManagedFileStore(
        appSupportDirProvider: () async => supportRoot,
      );
      final source = File(
        '${tempRoot.path}${Platform.pathSeparator}input_source.wav',
      );
      await source.writeAsBytes(List<int>.filled(128, 7));

      final resolvedPath = await store.resolveInputAudioForSelection(
        PickedSourceFile(path: source.path, name: 'track.wav'),
      );
      expect(File(resolvedPath).absolute.path, source.absolute.path);

      final filesInSourceDir = await source.parent
          .list(followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      expect(filesInSourceDir.length, 1);
      expect(filesInSourceDir.single.absolute.path, source.absolute.path);
    },
  );

  test(
    'ManagedFileStore keeps legacy model path when cache migration is disabled',
    () async {
      final supportRoot = await createTempRoot('support_legacy_no_cache');
      final tempRoot = await createTempRoot('temp_legacy_no_cache');
      addTearDown(() async {
        if (await supportRoot.exists()) {
          await supportRoot.delete(recursive: true);
        }
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final store = ManagedFileStore(
        appSupportDirProvider: () async => supportRoot,
      );
      final legacy = File(
        '${tempRoot.path}${Platform.pathSeparator}legacy_direct.gguf',
      );
      await legacy.writeAsString('legacy-model');

      final migrated = await store.migrateStoredModelPath(
        legacy.path,
        cacheModel: false,
      );
      expect(migrated, isNotNull);
      expect(File(migrated!).absolute.path, legacy.absolute.path);

      final activeModelPath = await store.activeModelPath();
      expect(await File(activeModelPath).exists(), isFalse);
    },
  );

  test(
    'ManagedFileStore migrates legacy model path and clears invalid path',
    () async {
      final supportRoot = await createTempRoot('support_migrate');
      final tempRoot = await createTempRoot('temp_migrate');
      addTearDown(() async {
        if (await supportRoot.exists()) {
          await supportRoot.delete(recursive: true);
        }
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final store = ManagedFileStore(
        appSupportDirProvider: () async => supportRoot,
      );
      final legacy = File(
        '${tempRoot.path}${Platform.pathSeparator}legacy.gguf',
      );
      await legacy.writeAsString('legacy-model');

      final migrated = await store.migrateStoredModelPath(legacy.path);
      expect(migrated, isNotNull);
      expect(await File(migrated!).exists(), isTrue);
      expect(await store.isManagedModelPath(migrated), isTrue);
      expect(await store.migrateStoredModelPath('does/not/exist.gguf'), isNull);
    },
  );
}
