import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class FileAccessUnsupportedException implements Exception {
  const FileAccessUnsupportedException(this.message);

  final String message;

  @override
  String toString() => 'FileAccessUnsupportedException($message)';
}

class FileAccessService {
  static const List<String> _audioExtensions = <String>[
    'wav',
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wma',
  ];

  Future<String?> pickModelFilePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['gguf'],
      allowMultiple: false,
      dialogTitle: 'Select model file',
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single.path;
  }

  Future<String?> pickAudioFilePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
      allowMultiple: false,
      dialogTitle: 'Select source audio file',
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single.path;
  }

  Future<String?> pickExportDirectory() async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select export directory',
      );
    } on PlatformException catch (e) {
      if (Platform.isIOS) {
        throw FileAccessUnsupportedException(
          'Directory picker is unavailable on this iOS device: ${e.code}',
        );
      }
      rethrow;
    } on MissingPluginException catch (e) {
      if (Platform.isIOS) {
        throw FileAccessUnsupportedException(
          'Directory picker is unavailable on this iOS device: ${e.message}',
        );
      }
      rethrow;
    }
  }

  Future<String?> pickSaveFilePath({
    required String suggestedName,
    required String extension,
  }) async {
    final safeExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save file',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: <String>[safeExtension],
    );
  }
}
