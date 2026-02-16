import 'dart:convert';

enum AmsBackend {
  auto(0),
  cpu(1),
  vulkan(2),
  cuda(3),
  metal(4);

  const AmsBackend(this.value);
  final int value;
}

enum AmsOutputFormat {
  wav(0, 'wav'),
  flac(1, 'flac'),
  mp3(2, 'mp3');

  const AmsOutputFormat(this.value, this.extensionName);
  final int value;
  final String extensionName;
}

enum SeparationJobState {
  pending(0),
  running(1),
  succeeded(2),
  failed(3),
  cancelled(4);

  const SeparationJobState(this.value);
  final int value;

  static SeparationJobState fromValue(int value) {
    return SeparationJobState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SeparationJobState.failed,
    );
  }
}

enum SeparationStage {
  idle(0),
  decode(1),
  infer(2),
  encode(3),
  done(4);

  const SeparationStage(this.value);
  final int value;

  static SeparationStage fromValue(int value) {
    return SeparationStage.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SeparationStage.idle,
    );
  }
}

class SeparationRequest {
  SeparationRequest({
    required this.modelPath,
    required this.inputPath,
    this.preparedInputPath,
    required this.outputDir,
    this.outputPrefix = 'separated',
    this.outputFormat = AmsOutputFormat.wav,
    this.chunkSize = -1,
    this.overlap = -1,
    this.backend = AmsBackend.auto,
  });

  final String modelPath;
  final String inputPath;
  final String? preparedInputPath;
  final String outputDir;
  final String outputPrefix;
  final AmsOutputFormat outputFormat;
  final int chunkSize;
  final int overlap;
  final AmsBackend backend;
}

class SeparationProgress {
  SeparationProgress({
    required this.state,
    required this.stage,
    required this.progress,
    required this.message,
  });

  final SeparationJobState state;
  final SeparationStage stage;
  final double progress;
  final String message;
}

class SeparationResult {
  SeparationResult({
    required this.outputFiles,
    required this.modelInputFile,
    required this.canonicalInputFile,
    required this.inferenceElapsedMs,
  });

  final List<String> outputFiles;
  final String? modelInputFile;
  final String? canonicalInputFile;
  final int? inferenceElapsedMs;

  factory SeparationResult.fromJson(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid result payload');
    }
    final dynamic files = decoded['files'];
    if (files is! List) {
      throw const FormatException('Missing files list in result payload');
    }
    final dynamic modelInputFile = decoded['model_input_file'];
    final dynamic canonicalInputFile = decoded['canonical_input_file'];
    final dynamic inferenceElapsedMs = decoded['inference_elapsed_ms'];
    return SeparationResult(
      outputFiles: files.whereType<String>().toList(growable: false),
      modelInputFile: modelInputFile is String ? modelInputFile : null,
      canonicalInputFile: canonicalInputFile is String
          ? canonicalInputFile
          : null,
      inferenceElapsedMs: _parsePositiveInt(inferenceElapsedMs),
    );
  }

  static int? _parsePositiveInt(dynamic value) {
    if (value is int && value >= 0) {
      return value;
    }
    if (value is double && value.isFinite && value >= 0) {
      return value.round();
    }
    return null;
  }
}
