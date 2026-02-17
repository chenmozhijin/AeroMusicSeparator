import 'dart:io';

import 'package:aero_music_separator/core/platform/mobile_export_channel.dart';
import 'package:aero_music_separator/core/separation/export_file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ExportFileService resolves conflict with numeric suffix', () async {
    final service = ExportFileService();
    final base = '${Platform.pathSeparator}tmp';
    final original = '$base${Platform.pathSeparator}stem.wav';
    final existing = <String>{
      original,
      '$base${Platform.pathSeparator}stem(1).wav',
      '$base${Platform.pathSeparator}stem(2).wav',
    };

    final resolved = await service.resolveNonConflictingPath(
      original,
      exists: (path) async => existing.contains(path),
    );

    expect(resolved, '$base${Platform.pathSeparator}stem(3).wav');
  });

  test('ExportFileService routes system dialog export on mobile', () async {
    final temp = await Directory.systemTemp.createTemp('ams_export_mobile');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
    final source = File('${temp.path}${Platform.pathSeparator}stem.wav');
    await source.writeAsString('stem-data');

    final fakeChannel = _FakeMobileExportChannel(
      result: 'content://exported/stem.wav',
    );
    final service = ExportFileService(
      mobileExportChannel: fakeChannel,
      forceMobilePlatform: true,
    );

    final result = await service.exportViaSystemDialog(
      sourcePath: source.path,
      suggestedName: 'stem.wav',
      extension: 'wav',
    );

    expect(result, 'content://exported/stem.wav');
    expect(fakeChannel.lastMimeType, 'audio/wav');
    expect(fakeChannel.callCount, 1);
  });

  test('ExportFileService throws ExportCancelledException when user cancels', () async {
    final temp = await Directory.systemTemp.createTemp('ams_export_cancel');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
    final source = File('${temp.path}${Platform.pathSeparator}stem.wav');
    await source.writeAsString('stem-data');

    final service = ExportFileService(
      mobileExportChannel: _FakeMobileExportChannel(result: null),
      forceMobilePlatform: true,
    );

    await expectLater(
      service.exportViaSystemDialog(
        sourcePath: source.path,
        suggestedName: 'stem.wav',
        extension: 'wav',
      ),
      throwsA(isA<ExportCancelledException>()),
    );
  });
}

class _FakeMobileExportChannel implements MobileExportChannel {
  _FakeMobileExportChannel({required this.result});

  final String? result;
  String? lastMimeType;
  int callCount = 0;

  @override
  Future<String?> exportFile({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    callCount += 1;
    lastMimeType = mimeType;
    return result;
  }
}
