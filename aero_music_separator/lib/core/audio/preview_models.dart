import 'dart:convert';

enum InputPreviewState { idle, loading, ready, error }

enum InputPrepareTaskState {
  pending(0),
  running(1),
  succeeded(2),
  failed(3),
  cancelled(4);

  const InputPrepareTaskState(this.value);
  final int value;

  static InputPrepareTaskState fromValue(int value) {
    return InputPrepareTaskState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InputPrepareTaskState.failed,
    );
  }
}

enum InputPrepareStage {
  idle(0),
  decode(1),
  resample(2),
  writeCanonical(3),
  done(4);

  const InputPrepareStage(this.value);
  final int value;

  static InputPrepareStage fromValue(int value) {
    return InputPrepareStage.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InputPrepareStage.idle,
    );
  }
}

class InputPreviewInfo {
  InputPreviewInfo({
    required this.canonicalPath,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
  });

  final String canonicalPath;
  final int durationMs;
  final int sampleRate;
  final int channels;

  factory InputPreviewInfo.fromJson(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid prepare result payload');
    }

    final dynamic canonical = decoded['canonical_input_file'];
    final dynamic sampleRate = decoded['sample_rate'];
    final dynamic channels = decoded['channels'];
    final dynamic durationMs = decoded['duration_ms'];

    if (canonical is! String ||
        sampleRate is! int ||
        channels is! int ||
        durationMs is! int) {
      throw const FormatException('Missing fields in prepare result payload');
    }

    return InputPreviewInfo(
      canonicalPath: canonical,
      durationMs: durationMs,
      sampleRate: sampleRate,
      channels: channels,
    );
  }
}

class InputPrepareProgress {
  InputPrepareProgress({
    required this.state,
    required this.stage,
    required this.progress,
    required this.message,
  });

  final InputPrepareTaskState state;
  final InputPrepareStage stage;
  final double progress;
  final String message;
}
