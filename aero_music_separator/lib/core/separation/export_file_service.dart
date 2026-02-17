import 'dart:io';

import '../platform/mobile_export_channel.dart';

class ExportCancelledException implements Exception {
  const ExportCancelledException(this.message);

  final String message;

  @override
  String toString() => 'ExportCancelledException($message)';
}

class ExportFileService {
  ExportFileService({
    MobileExportChannel? mobileExportChannel,
    bool? forceMobilePlatform,
  }) : _mobileExportChannel =
           mobileExportChannel ?? const MethodChannelMobileExportChannel(),
       _forceMobilePlatform = forceMobilePlatform;

  final MobileExportChannel _mobileExportChannel;
  final bool? _forceMobilePlatform;

  Future<String> resolveNonConflictingPath(
    String requestedPath, {
    Future<bool> Function(String path)? exists,
  }) async {
    final existsFn = exists ?? (path) => File(path).exists();
    if (!await existsFn(requestedPath)) {
      return requestedPath;
    }

    final requestedFile = File(requestedPath);
    final parent = requestedFile.parent.path;
    final fileName = requestedFile.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final hasExtension = dotIndex > 0 && dotIndex < fileName.length - 1;
    final baseName = hasExtension ? fileName.substring(0, dotIndex) : fileName;
    final extension = hasExtension ? fileName.substring(dotIndex) : '';

    for (var index = 1; index <= 9999; index++) {
      final candidate =
          '$parent${Platform.pathSeparator}$baseName($index)$extension';
      if (!await existsFn(candidate)) {
        return candidate;
      }
    }
    throw StateError('Unable to resolve file name conflict for $requestedPath');
  }

  Future<String> copyWithConflictResolution({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final resolvedPath = await resolveNonConflictingPath(destinationPath);
    final source = File(sourcePath);
    await source.copy(resolvedPath);
    return resolvedPath;
  }

  Future<String> exportViaSystemDialog({
    required String sourcePath,
    required String suggestedName,
    required String extension,
  }) async {
    if (!_isMobilePlatform) {
      throw UnsupportedError(
        'exportViaSystemDialog is only supported on Android and iOS.',
      );
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('ffi_read: source file not found', sourcePath);
    }
    RandomAccessFile? handle;
    try {
      handle = await source.open(mode: FileMode.read);
    } catch (error) {
      throw FileSystemException(
        'ffi_read: source file is not readable ($error)',
        sourcePath,
      );
    } finally {
      await handle?.close();
    }

    final resolvedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    final resolvedMime = _mimeTypeForExtension(resolvedExtension);
    final exported = await _mobileExportChannel.exportFile(
      sourcePath: sourcePath,
      suggestedName: suggestedName,
      mimeType: resolvedMime,
    );
    if (exported == null || exported.trim().isEmpty) {
      throw const ExportCancelledException('pick_destination: user cancelled');
    }
    return exported;
  }

  bool get _isMobilePlatform {
    final forced = _forceMobilePlatform;
    if (forced != null) {
      return forced;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  String _mimeTypeForExtension(String extension) {
    final normalized = extension.toLowerCase();
    switch (normalized) {
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'opus':
        return 'audio/opus';
      default:
        return 'application/octet-stream';
    }
  }
}
