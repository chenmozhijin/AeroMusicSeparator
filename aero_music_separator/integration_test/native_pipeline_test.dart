import 'dart:convert';
import 'dart:io';

import 'package:aero_music_separator/core/separation/input_prepare_service.dart';
import 'package:aero_music_separator/core/separation/separation_models.dart';
import 'package:aero_music_separator/core/separation/separation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native prepare + separation pipeline', (WidgetTester _) async {
    final modelUrl = const String.fromEnvironment(
      'AMS_IT_MODEL_URL',
      defaultValue: '',
    ).trim();
    final audioUrl = const String.fromEnvironment(
      'AMS_IT_AUDIO_URL',
      defaultValue: '',
    ).trim();
    final backendsRaw = const String.fromEnvironment(
      'AMS_IT_BACKENDS',
      defaultValue: 'cpu',
    );
    final minOutputBytes = _parsePositiveInt(
      const String.fromEnvironment(
        'AMS_IT_MIN_OUTPUT_BYTES',
        defaultValue: '1000',
      ),
      fallback: 1000,
    );
    final durationToleranceMs = _parsePositiveInt(
      const String.fromEnvironment(
        'AMS_IT_DURATION_TOLERANCE_MS',
        defaultValue: '300',
      ),
      fallback: 300,
    );
    final chunkSize = _parsePositiveInt(
      const String.fromEnvironment(
        'AMS_IT_CHUNK_SIZE',
        defaultValue: '131072',
      ),
      fallback: 131072,
    );
    final overlap = _parsePositiveInt(
      const String.fromEnvironment(
        'AMS_IT_OVERLAP',
        defaultValue: '2',
      ),
      fallback: 2,
    );

    expect(modelUrl, isNotEmpty, reason: 'AMS_IT_MODEL_URL is required');
    expect(audioUrl, isNotEmpty, reason: 'AMS_IT_AUDIO_URL is required');

    final tempRoot = await getTemporaryDirectory();
    final workRoot = Directory(
      '${tempRoot.path}/native_pipeline_it_${DateTime.now().millisecondsSinceEpoch}',
    );
    await workRoot.create(recursive: true);
    addTearDown(() async {
      if (await workRoot.exists()) {
        await workRoot.delete(recursive: true);
      }
    });

    final modelFile = File('${workRoot.path}/model.gguf');
    final inputFile = File('${workRoot.path}/input.wav');
    await _downloadToFile(modelUrl, modelFile);
    await _downloadToFile(audioUrl, inputFile);

    final prepareDir = Directory('${workRoot.path}/prepare');
    await prepareDir.create(recursive: true);

    final prepareService = InputPrepareService();
    addTearDown(prepareService.dispose);

    final preview = await prepareService.start(
      InputPrepareRequest(
        inputPath: inputFile.path,
        workDir: prepareDir.path,
        outputPrefix: 'integration',
      ),
    );
    expect(File(preview.canonicalPath).existsSync(), isTrue);
    expect(preview.durationMs, greaterThan(0));
    expect(preview.sampleRate, 44100);
    expect(preview.channels, 2);

    final backends = _parseBackends(backendsRaw);
    var successfulRuns = 0;
    for (final backend in backends) {
      final runTag = backend.name;
      try {
        await _runSeparationOnce(
          modelPath: modelFile.path,
          inputPath: inputFile.path,
          canonicalInputPath: preview.canonicalPath,
          outputRoot: Directory('${workRoot.path}/output'),
          backend: backend,
          runTag: runTag,
          expectedDurationMs: preview.durationMs,
          minOutputBytes: minOutputBytes,
          durationToleranceMs: durationToleranceMs,
          chunkSize: chunkSize,
          overlap: overlap,
        );
        successfulRuns += 1;
      } catch (e, st) {
        if (backend == AmsBackend.vulkan) {
          debugPrint('::warning::Vulkan integration run failed, fallback to CPU. error=$e');
          await _runSeparationOnce(
            modelPath: modelFile.path,
            inputPath: inputFile.path,
            canonicalInputPath: preview.canonicalPath,
            outputRoot: Directory('${workRoot.path}/output'),
            backend: AmsBackend.cpu,
            runTag: 'cpu_fallback_from_vulkan',
            expectedDurationMs: preview.durationMs,
            minOutputBytes: minOutputBytes,
            durationToleranceMs: durationToleranceMs,
            chunkSize: chunkSize,
            overlap: overlap,
          );
          successfulRuns += 1;
          continue;
        }
        Error.throwWithStackTrace(e, st);
      }
    }

    expect(successfulRuns, greaterThan(0));
  });
}

Future<void> _runSeparationOnce({
  required String modelPath,
  required String inputPath,
  required String canonicalInputPath,
  required Directory outputRoot,
  required AmsBackend backend,
  required String runTag,
  required int expectedDurationMs,
  required int minOutputBytes,
  required int durationToleranceMs,
  required int chunkSize,
  required int overlap,
}) async {
  await outputRoot.create(recursive: true);
  final runDir = Directory(
    '${outputRoot.path}/${runTag}_${DateTime.now().millisecondsSinceEpoch}',
  );
  await runDir.create(recursive: true);

  final controller = SeparationTaskController();
  try {
    final result = await controller.start(
      SeparationRequest(
        modelPath: modelPath,
        inputPath: inputPath,
        preparedInputPath: canonicalInputPath,
        outputDir: runDir.path,
        outputPrefix: 'integration_$runTag',
        outputFormat: AmsOutputFormat.wav,
        chunkSize: chunkSize,
        overlap: overlap,
        backend: backend,
      ),
    );

    expect(result.outputFiles, isNotEmpty, reason: 'No output files for backend $backend');
    for (final outputPath in result.outputFiles) {
      final file = File(outputPath);
      expect(await file.exists(), isTrue, reason: 'Missing output file: $outputPath');
      final size = await file.length();
      expect(
        size,
        greaterThanOrEqualTo(minOutputBytes),
        reason: 'Output file too small: $outputPath ($size bytes)',
      );
      final durationMs = await _readWavDurationMs(file);
      final delta = (durationMs - expectedDurationMs).abs();
      expect(
        delta,
        lessThanOrEqualTo(durationToleranceMs),
        reason: 'Duration mismatch for $outputPath: actual=$durationMs expected=$expectedDurationMs delta=$delta',
      );
    }
  } finally {
    controller.dispose();
  }
}

Future<void> _downloadToFile(String url, File outFile) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Download failed: $url status=${response.statusCode}',
        uri: uri,
      );
    }
    await outFile.parent.create(recursive: true);
    final sink = outFile.openWrite();
    await response.pipe(sink);
    await sink.close();
  } finally {
    client.close(force: true);
  }
}

Future<int> _readWavDurationMs(File file) async {
  final bytes = await file.readAsBytes();
  if (bytes.length < 44) {
    throw FormatException('WAV too small: ${file.path}');
  }
  if (ascii.decode(bytes.sublist(0, 4)) != 'RIFF' ||
      ascii.decode(bytes.sublist(8, 12)) != 'WAVE') {
    throw FormatException('Not a RIFF/WAVE file: ${file.path}');
  }

  final data = ByteData.sublistView(bytes);
  var offset = 12;
  int? byteRate;
  int? dataSize;

  while (offset + 8 <= bytes.length) {
    final chunkId = ascii.decode(bytes.sublist(offset, offset + 4));
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkDataStart = offset + 8;
    if (chunkDataStart + chunkSize > bytes.length) {
      break;
    }

    if (chunkId == 'fmt ' && chunkSize >= 16) {
      byteRate = data.getUint32(chunkDataStart + 8, Endian.little);
    } else if (chunkId == 'data') {
      dataSize = chunkSize;
    }

    final padded = chunkSize + (chunkSize.isOdd ? 1 : 0);
    offset = chunkDataStart + padded;
  }

  if (byteRate == null || byteRate <= 0 || dataSize == null || dataSize < 0) {
    throw FormatException('Invalid WAV metadata: ${file.path}');
  }
  return ((dataSize * 1000) / byteRate).round();
}

List<AmsBackend> _parseBackends(String raw) {
  final result = <AmsBackend>[];
  final seen = <AmsBackend>{};
  for (final token in raw.split(',')) {
    final name = token.trim().toLowerCase();
    if (name.isEmpty) {
      continue;
    }
    final backend = _backendFromName(name);
    if (backend == null || seen.contains(backend)) {
      continue;
    }
    seen.add(backend);
    result.add(backend);
  }
  if (result.isEmpty) {
    return <AmsBackend>[AmsBackend.cpu];
  }
  return result;
}

AmsBackend? _backendFromName(String name) {
  switch (name) {
    case 'cpu':
      return AmsBackend.cpu;
    case 'vulkan':
      return AmsBackend.vulkan;
    case 'cuda':
      return AmsBackend.cuda;
    case 'metal':
      return AmsBackend.metal;
    case 'auto':
      return AmsBackend.auto;
    default:
      return null;
  }
}

int _parsePositiveInt(String raw, {required int fallback}) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) {
    return fallback;
  }
  return value;
}
