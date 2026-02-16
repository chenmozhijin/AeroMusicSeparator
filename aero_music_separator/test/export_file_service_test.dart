import 'dart:io';

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
}
