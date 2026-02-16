import 'dart:io';

class ExportFileService {
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
}
