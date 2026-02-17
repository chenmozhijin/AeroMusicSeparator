import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class PickedSourceFile {
  const PickedSourceFile({
    required this.path,
    required this.name,
    this.identifier,
  });

  final String path;
  final String name;
  final String? identifier;
}

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

  Future<PickedSourceFile?> pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['gguf'],
      allowMultiple: false,
      dialogTitle: 'Select model file',
    );
    return _resolveSinglePickedFile(result);
  }

  Future<PickedSourceFile?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
      allowMultiple: false,
      dialogTitle: 'Select source audio file',
    );
    return _resolveSinglePickedFile(result);
  }

  PickedSourceFile? _resolveSinglePickedFile(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      throw const FileAccessUnsupportedException(
        'Unable to resolve a local file path from the selected document.',
      );
    }
    return PickedSourceFile(path: path, name: file.name, identifier: file.identifier);
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
