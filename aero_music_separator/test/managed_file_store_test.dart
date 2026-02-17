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
      tempDirProvider: () async => tempRoot,
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

  test('ManagedFileStore imports audio and cleans up old cache files', () async {
    final supportRoot = await createTempRoot('support_audio');
    final tempRoot = await createTempRoot('temp_audio');
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
      tempDirProvider: () async => tempRoot,
      maxCachedInputFiles: 2,
    );
    final source = File('${tempRoot.path}${Platform.pathSeparator}input_source.wav');
    await source.writeAsBytes(List<int>.filled(128, 7));

    final importedPaths = <String>[];
    for (var i = 0; i < 3; i++) {
      importedPaths.add(
        await store.importInputAudio(
          PickedSourceFile(path: source.path, name: 'track_$i.wav'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await store.cleanupOldInputs();

    final inputDir = File(importedPaths.first).parent;
    final remainingFiles = await inputDir
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    expect(remainingFiles.length, lessThanOrEqualTo(2));
    expect(await File(importedPaths.last).exists(), isTrue);
  });

  test('ManagedFileStore migrates legacy model path and clears invalid path', () async {
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
      tempDirProvider: () async => tempRoot,
    );
    final legacy = File('${tempRoot.path}${Platform.pathSeparator}legacy.gguf');
    await legacy.writeAsString('legacy-model');

    final migrated = await store.migrateStoredModelPath(legacy.path);
    expect(migrated, isNotNull);
    expect(await File(migrated!).exists(), isTrue);
    expect(await store.isManagedModelPath(migrated), isTrue);
    expect(await store.migrateStoredModelPath('does/not/exist.gguf'), isNull);
  });
}
