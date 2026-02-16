import 'dart:async';
import 'dart:io';

import 'package:aero_music_separator/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/audio/preview_models.dart';
import '../../core/audio/preview_player.dart';
import '../../core/ffi/ams_native.dart';
import '../../core/platform/file_access_service.dart';
import '../../core/runtime/openmp_runtime_configurator.dart';
import '../../core/separation/export_file_service.dart';
import '../../core/separation/input_prepare_service.dart';
import '../../core/separation/model_defaults_service.dart';
import '../../core/separation/result_cache_manager.dart';
import '../../core/separation/separation_models.dart';
import '../../core/separation/separation_service.dart';
import '../../core/settings/app_settings_store.dart';

enum ChunkOverlapMode { auto, custom }

class _StemItem {
  _StemItem({required this.path});

  final String path;
  bool selected = true;

  String get fileName {
    final segments = Uri.file(path).pathSegments;
    if (segments.isEmpty) {
      return path;
    }
    return segments.last;
  }

  String get extensionWithoutDot {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == name.length - 1) {
      return 'wav';
    }
    return name.substring(dotIndex + 1);
  }
}

class _LogEntry {
  const _LogEntry({required this.id, required this.message});

  final int id;
  final String message;
}

class InferencePage extends StatefulWidget {
  const InferencePage({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<InferencePage> createState() => _InferencePageState();
}

class _InferencePageState extends State<InferencePage> {
  final _modelPathController = TextEditingController();
  final _inputPathController = TextEditingController();
  final _outputPrefixController = TextEditingController();
  final _chunkSizeController = TextEditingController();
  final _overlapController = TextEditingController();

  final SeparationTaskController _taskController = SeparationTaskController();
  final PreviewPlayer _previewPlayer = PreviewPlayer();
  InputPrepareService _prepareService = InputPrepareService();
  final AppSettingsStore _settingsStore = AppSettingsStore();
  final FileAccessService _fileAccessService = FileAccessService();
  final ModelDefaultsService _modelDefaultsService = ModelDefaultsService();
  final ResultCacheManager _resultCacheManager = ResultCacheManager();
  final ExportFileService _exportFileService = ExportFileService();
  final OpenMpRuntimeConfigurator _openMpConfigurator =
      OpenMpRuntimeConfigurator();
  static const double _progressUpdateThreshold = 0.01;
  static const int _positionUpdateThresholdMs = 200;
  static const int _maxLogEntries = 300;

  StreamSubscription<SeparationProgress>? _progressSubscription;
  StreamSubscription<InputPrepareProgress>? _prepareProgressSubscription;
  StreamSubscription<PreviewPlaybackState>? _previewPlayerStateSubscription;
  StreamSubscription<Duration>? _previewPositionSubscription;
  StreamSubscription<Duration>? _previewDurationSubscription;

  AmsOutputFormat _outputFormat = AmsOutputFormat.wav;
  SeparationProgress? _latestProgress;
  Duration? _lastInferenceElapsed;
  InputPrepareProgress? _latestPrepareProgress;
  InputPreviewState _previewState = InputPreviewState.idle;
  InputPreviewInfo? _previewInfo;

  bool _previewPlaying = false;
  String? _activePlaybackPath;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackPositionForUi = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  bool _running = false;
  bool _exporting = false;
  bool _loadingModelDefaults = false;
  int _prepareGeneration = 0;

  ChunkOverlapMode _chunkOverlapMode = ChunkOverlapMode.auto;
  ModelDefaults? _modelDefaults;
  String? _modelDefaultsPath;

  String? _sourceInputPath;
  final List<_StemItem> _stemItems = <_StemItem>[];
  final List<_LogEntry> _logs = <_LogEntry>[];
  int _nextLogId = 0;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool get _nativeRuntimeSupported => AmsNative.isRuntimeSupportedPlatform;

  String get _nativeUnsupportedMessage => _l10n.nativeRuntimeUnsupported;

  AmsBackend _backendFor(bool forceCpu) =>
      forceCpu ? AmsBackend.cpu : AmsBackend.auto;

  @override
  void initState() {
    super.initState();
    _progressSubscription = _taskController.progress.listen((event) {
      if (!mounted) {
        return;
      }
      final shouldRebuild =
          widget.isActive && _shouldRebuildForSeparationProgress(event);
      _latestProgress = event;
      if (shouldRebuild) {
        _updateState(() {});
      }
    });
    _bindPrepareProgress();
    _previewPlayerStateSubscription = _previewPlayer.stateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      final nextPlaying = state == PreviewPlaybackState.playing;
      final changed = _previewPlaying != nextPlaying;
      _previewPlaying = nextPlaying;
      if (widget.isActive && changed) {
        _updateState(() {});
      }
    });
    _previewPositionSubscription = _previewPlayer.positionStream.listen((
      value,
    ) {
      if (!mounted) {
        return;
      }
      final shouldRebuild =
          widget.isActive && _shouldRebuildForPlaybackPosition(value);
      _playbackPosition = value;
      if (shouldRebuild) {
        _updateState(() {});
      }
    });
    _previewDurationSubscription = _previewPlayer.durationStream.listen((
      value,
    ) {
      if (!mounted) {
        return;
      }
      final changed = _playbackDuration != value;
      _playbackDuration = value;
      if (widget.isActive && changed) {
        _updateState(() {});
      }
    });
    unawaited(_loadSettings());
  }

  @override
  void didUpdateWidget(covariant InferencePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && mounted) {
      _updateState(() {});
    }
  }

  void _updateState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    if (widget.isActive) {
      setState(updater);
      return;
    }
    updater();
  }

  bool _shouldRebuildForSeparationProgress(SeparationProgress next) {
    final previous = _latestProgress;
    if (previous == null) {
      return true;
    }
    if (previous.state != next.state || previous.stage != next.stage) {
      return true;
    }
    return (previous.progress - next.progress).abs() >=
        _progressUpdateThreshold;
  }

  bool _shouldRebuildForPrepareProgress(InputPrepareProgress next) {
    final previous = _latestPrepareProgress;
    if (previous == null) {
      return true;
    }
    if (previous.state != next.state || previous.stage != next.stage) {
      return true;
    }
    return (previous.progress - next.progress).abs() >=
        _progressUpdateThreshold;
  }

  bool _shouldRebuildForPlaybackPosition(Duration next) {
    final deltaMs = (_playbackPositionForUi - next).abs().inMilliseconds;
    if (deltaMs < _positionUpdateThresholdMs) {
      return false;
    }
    _playbackPositionForUi = next;
    return true;
  }

  bool _isCancelledError(Object error) {
    if (error is NativeCancelledException) {
      return true;
    }
    if (error is NativeFfiException &&
        error.code == AmsNativeStatus.cancelled) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('cancelled');
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _prepareProgressSubscription?.cancel();
    _previewPlayerStateSubscription?.cancel();
    _previewPositionSubscription?.cancel();
    _previewDurationSubscription?.cancel();

    _taskController.dispose();
    _prepareService.dispose();
    unawaited(_previewPlayer.dispose());

    _modelPathController.dispose();
    _inputPathController.dispose();
    _outputPrefixController.dispose();
    _chunkSizeController.dispose();
    _overlapController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final modelPath = await _settingsStore.readLastModelPath();
    if (!mounted) {
      return;
    }
    _updateState(() {
      if (modelPath != null) {
        _modelPathController.text = modelPath;
      }
    });
    if (modelPath != null && _nativeRuntimeSupported) {
      await _loadModelDefaultsIfNeeded(force: true);
    }
  }

  Future<void> _applyOpenMpForNextTask({required bool forceCpu}) async {
    final preset = await _settingsStore.readOpenMpPreset();
    await _openMpConfigurator.applyForNextTask(
      preset: preset,
      forceCpu: forceCpu,
      platform: defaultTargetPlatform,
    );
  }

  void _bindPrepareProgress() {
    _prepareProgressSubscription?.cancel();
    _prepareProgressSubscription = _prepareService.progress.listen((event) {
      if (!mounted) {
        return;
      }
      final shouldRebuild =
          widget.isActive && _shouldRebuildForPrepareProgress(event);
      _latestPrepareProgress = event;
      if (shouldRebuild) {
        _updateState(() {});
      }
    });
  }

  void _resetPrepareService() {
    _prepareProgressSubscription?.cancel();
    _prepareService.dispose();
    _prepareService = InputPrepareService();
    _bindPrepareProgress();
  }

  Future<void> _pickModelFile() async {
    if (_running || _exporting) {
      return;
    }
    try {
      final path = await _fileAccessService.pickModelFilePath();
      if (path == null || path.trim().isEmpty) {
        return;
      }
      _modelPathController.text = path;
      await _settingsStore.writeLastModelPath(path);
      _updateState(() {
        _modelDefaults = null;
        _modelDefaultsPath = null;
      });
      if (_nativeRuntimeSupported) {
        await _loadModelDefaultsIfNeeded(force: true);
      }
    } catch (e) {
      _reportError(_l10n.logModelSelectionFailed('$e'));
    }
  }

  Future<void> _pickInputFile() async {
    if (_running || _exporting) {
      return;
    }
    if (!_nativeRuntimeSupported) {
      _reportError(_nativeUnsupportedMessage);
      return;
    }
    try {
      final path = await _fileAccessService.pickAudioFilePath();
      if (path == null || path.trim().isEmpty) {
        return;
      }
      _sourceInputPath = path;
      _inputPathController.text = path;
      _outputPrefixController.text = _defaultOutputPrefixForPath(path);
      _stemItems.clear();
      await _prepareInput(path);
    } catch (e) {
      _reportError(_l10n.logInputSelectionFailed('$e'));
    }
  }

  Future<String> _resolvePrepareWorkDir() async {
    final baseDir = await getTemporaryDirectory();
    return '${baseDir.path}${Platform.pathSeparator}aero_music_separator'
        '${Platform.pathSeparator}prepare_cache';
  }

  String _defaultOutputPrefixForPath(String inputPath) {
    final name = File(inputPath).uri.pathSegments.last;
    if (name.isEmpty) {
      return 'separated';
    }
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      return name.substring(0, dotIndex);
    }
    return name;
  }

  String _resolveOutputPrefix() {
    final current = _outputPrefixController.text.trim();
    if (current.isNotEmpty) {
      return current;
    }
    final sourceInputPath = _sourceInputPath;
    if (sourceInputPath != null && sourceInputPath.isNotEmpty) {
      return _defaultOutputPrefixForPath(sourceInputPath);
    }
    return 'separated';
  }

  Future<void> _prepareInput(String inputPath) async {
    if (!_nativeRuntimeSupported) {
      _reportError(_nativeUnsupportedMessage);
      return;
    }

    final generation = ++_prepareGeneration;
    _resetPrepareService();
    await _previewPlayer.stop();

    if (!mounted) {
      return;
    }
    _updateState(() {
      _previewPlaying = false;
      _activePlaybackPath = null;
      _playbackPosition = Duration.zero;
      _playbackPositionForUi = Duration.zero;
      _playbackDuration = Duration.zero;
      _previewState = InputPreviewState.loading;
      _previewInfo = null;
      _latestPrepareProgress = InputPrepareProgress(
        state: InputPrepareTaskState.running,
        stage: InputPrepareStage.decode,
        progress: 0.0,
        message: _l10n.prepareStatusLoadingInput,
      );
    });

    _appendLog(_l10n.logPreparingInput);
    final workDir = await _resolvePrepareWorkDir();
    if (!mounted || generation != _prepareGeneration) {
      return;
    }
    final request = InputPrepareRequest(
      inputPath: inputPath,
      workDir: workDir,
      outputPrefix: _resolveOutputPrefix(),
    );

    try {
      final result = await _prepareService.start(request);
      if (!mounted || generation != _prepareGeneration) {
        return;
      }
      _updateState(() {
        _previewState = InputPreviewState.ready;
        _previewInfo = result;
      });
      _appendLog(_l10n.logInputReady(result.canonicalPath));
    } catch (e) {
      if (!mounted || generation != _prepareGeneration) {
        return;
      }
      if (_isCancelledError(e)) {
        _updateState(() {
          _previewState = InputPreviewState.idle;
          _previewInfo = null;
        });
        _appendLog(_l10n.logPrepareCancelled);
      } else {
        _updateState(() {
          _previewState = InputPreviewState.error;
        });
        _reportError(_l10n.logPrepareFailed('$e'));
      }
    }
  }

  Future<void> _togglePlaybackForPath(String path) async {
    try {
      if (_activePlaybackPath == path) {
        if (_previewPlaying) {
          await _previewPlayer.pause();
        } else {
          await _previewPlayer.resume();
        }
        return;
      }
      await _previewPlayer.play(path);
      if (!mounted) {
        return;
      }
      _updateState(() {
        _activePlaybackPath = path;
        _playbackPosition = Duration.zero;
        _playbackPositionForUi = Duration.zero;
      });
    } catch (e) {
      _reportError(_l10n.logPlaybackFailed('$e'));
    }
  }

  Future<void> _seekPlayback(String path, double valueMs) async {
    if (_activePlaybackPath != path) {
      return;
    }
    final clamped = valueMs.clamp(
      0.0,
      _playbackDuration.inMilliseconds.toDouble(),
    );
    await _previewPlayer.seek(Duration(milliseconds: clamped.round()));
  }

  Future<bool> _loadModelDefaultsIfNeeded({
    bool force = false,
    bool reportUnsupported = true,
  }) async {
    final modelPath = _modelPathController.text.trim();
    if (modelPath.isEmpty) {
      if (mounted) {
        _updateState(() {
          _modelDefaults = null;
          _modelDefaultsPath = null;
        });
      }
      return false;
    }
    if (!force && _modelDefaultsPath == modelPath && _modelDefaults != null) {
      return true;
    }

    if (!_nativeRuntimeSupported) {
      if (mounted) {
        _updateState(() {
          _modelDefaults = null;
          _modelDefaultsPath = null;
        });
      }
      if (reportUnsupported) {
        _reportError(_nativeUnsupportedMessage);
      }
      return false;
    }

    final forceCpu = await _settingsStore.readForceCpuEnabled();
    final backend = _backendFor(forceCpu);
    try {
      await _applyOpenMpForNextTask(forceCpu: forceCpu);
    } catch (e) {
      _reportError(_l10n.logTaskFailed('OpenMP: $e'));
    }

    if (mounted) {
      _updateState(() {
        _loadingModelDefaults = true;
      });
    }
    try {
      final defaults = await _modelDefaultsService.loadDefaults(
        modelPath: modelPath,
        backend: backend,
      );
      if (!mounted) {
        return false;
      }
      _updateState(() {
        _modelDefaults = defaults;
        _modelDefaultsPath = modelPath;
        if (_chunkSizeController.text.trim().isEmpty ||
            _chunkOverlapMode == ChunkOverlapMode.auto) {
          _chunkSizeController.text = '${defaults.chunkSize}';
        }
        if (_overlapController.text.trim().isEmpty ||
            _chunkOverlapMode == ChunkOverlapMode.auto) {
          _overlapController.text = '${defaults.overlap}';
        }
      });
      _appendLog(
        _l10n.logLoadedModelDefaults(
          '${defaults.chunkSize}',
          '${defaults.overlap}',
          '${defaults.sampleRate}',
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        _updateState(() {
          _modelDefaults = null;
          _modelDefaultsPath = null;
        });
      }
      _reportError(_l10n.logFailedReadModelDefaults('$e'));
      return false;
    } finally {
      if (mounted) {
        _updateState(() {
          _loadingModelDefaults = false;
        });
      }
    }
  }

  int? _parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _start() async {
    if (_running || _exporting) {
      return;
    }
    if (!_nativeRuntimeSupported) {
      _reportError(_nativeUnsupportedMessage);
      return;
    }

    final modelPath = _modelPathController.text.trim();
    if (modelPath.isEmpty) {
      _reportError(_l10n.logModelPathRequired);
      return;
    }
    if (_previewState != InputPreviewState.ready ||
        _previewInfo == null ||
        _sourceInputPath == null) {
      _reportError(_l10n.logPrepareWaitRequired);
      return;
    }

    await _settingsStore.writeLastModelPath(modelPath);
    final loadedDefaults = await _loadModelDefaultsIfNeeded();
    if (!loadedDefaults) {
      _reportError(_l10n.logUnableLoadDefaults);
      return;
    }

    final forceCpu = await _settingsStore.readForceCpuEnabled();
    final backend = _backendFor(forceCpu);
    try {
      await _applyOpenMpForNextTask(forceCpu: forceCpu);
    } catch (e) {
      _reportError(_l10n.logTaskFailed('OpenMP: $e'));
    }

    var chunkSize = -1;
    var overlap = -1;
    if (_chunkOverlapMode == ChunkOverlapMode.custom) {
      final parsedChunk = _parsePositiveInt(_chunkSizeController.text);
      final parsedOverlap = _parsePositiveInt(_overlapController.text);
      if (parsedChunk == null || parsedOverlap == null) {
        _reportError(_l10n.logInvalidChunkOverlap);
        return;
      }
      chunkSize = parsedChunk;
      overlap = parsedOverlap;
    }

    final outputDir = await _resultCacheManager.prepareLatestRunDir();
    final request = SeparationRequest(
      modelPath: modelPath,
      inputPath: _sourceInputPath!,
      preparedInputPath: _previewInfo!.canonicalPath,
      outputDir: outputDir,
      outputPrefix: _resolveOutputPrefix(),
      outputFormat: _outputFormat,
      chunkSize: chunkSize,
      overlap: overlap,
      backend: backend,
    );

    _updateState(() {
      _running = true;
      _latestProgress = SeparationProgress(
        state: SeparationJobState.pending,
        stage: SeparationStage.idle,
        progress: 0,
        message: _l10n.statusPreparing,
      );
      _lastInferenceElapsed = null;
      _stemItems.clear();
    });

    _appendLog(_l10n.logStartingTask);
    try {
      final result = await _taskController.start(request);
      if (!mounted) {
        return;
      }
      final stems = result.outputFiles
          .map((path) => _StemItem(path: path))
          .toList(growable: false);
      _updateState(() {
        _stemItems
          ..clear()
          ..addAll(stems);
        if (result.inferenceElapsedMs != null) {
          _lastInferenceElapsed = Duration(
            milliseconds: result.inferenceElapsedMs!,
          );
        }
      });
      _appendLog(_l10n.logTaskFinished);
      if (result.inferenceElapsedMs != null) {
        _appendLog(
          _l10n.logInferenceElapsed(
            _formatInferenceElapsed(
              Duration(milliseconds: result.inferenceElapsedMs!),
            ),
          ),
        );
      }
      for (final file in result.outputFiles) {
        _appendLog('  $file');
      }
      if (result.modelInputFile != null) {
        _appendLog(_l10n.logModelInput(result.modelInputFile!));
      }
      if (result.canonicalInputFile != null) {
        _appendLog(_l10n.logCanonicalInput(result.canonicalInputFile!));
      }
    } catch (e) {
      if (_isCancelledError(e)) {
        _appendLog(_l10n.logTaskCancelled);
      } else {
        _reportError(_l10n.logTaskFailed('$e'));
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _running = false;
        });
      }
    }
  }

  void _cancel() {
    if (_running) {
      _appendLog(_l10n.logCancellingTask);
      _taskController.cancel();
      return;
    }
    if (_previewState == InputPreviewState.loading) {
      _appendLog(_l10n.logCancellingPrepare);
      _prepareService.cancel();
    }
  }

  Future<void> _saveSingleStem(_StemItem item) async {
    if (_running || _exporting) {
      return;
    }
    try {
      _updateState(() {
        _exporting = true;
      });
      final path = await _fileAccessService.pickSaveFilePath(
        suggestedName: item.fileName,
        extension: item.extensionWithoutDot,
      );
      if (path == null || path.trim().isEmpty) {
        _appendLog(_l10n.logSaveCancelled(item.fileName));
        return;
      }
      final saved = await _exportFileService.copyWithConflictResolution(
        sourcePath: item.path,
        destinationPath: path,
      );
      _appendLog(_l10n.logSavedStem(saved));
    } catch (e) {
      _reportError(_l10n.logSaveStemFailed(item.fileName, '$e'));
    } finally {
      if (mounted) {
        _updateState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _exportAllStems() async {
    final stems = List<_StemItem>.from(_stemItems);
    await _exportStems(stems);
  }

  Future<void> _exportSelectedStems() async {
    final stems = _stemItems
        .where((item) => item.selected)
        .toList(growable: false);
    await _exportStems(stems);
  }

  Future<void> _exportStems(List<_StemItem> stems) async {
    if (_running || _exporting) {
      return;
    }
    if (stems.isEmpty) {
      _appendLog(_l10n.logNoStemsSelected);
      return;
    }
    _updateState(() {
      _exporting = true;
    });
    try {
      String? exportDir;
      try {
        exportDir = await _fileAccessService.pickExportDirectory();
      } on FileAccessUnsupportedException catch (_) {
        _appendLog(_l10n.logDirectoryExportUnavailable);
        await _exportBySaveDialogs(stems);
        return;
      }

      if (exportDir == null || exportDir.trim().isEmpty) {
        _appendLog(_l10n.logExportCancelled);
        return;
      }
      await _exportToDirectory(stems, exportDir);
    } catch (e) {
      _reportError(_l10n.logExportFailed('$e'));
    } finally {
      if (mounted) {
        _updateState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _exportToDirectory(
    List<_StemItem> stems,
    String exportDir,
  ) async {
    for (final stem in stems) {
      final targetPath = '$exportDir${Platform.pathSeparator}${stem.fileName}';
      final copied = await _exportFileService.copyWithConflictResolution(
        sourcePath: stem.path,
        destinationPath: targetPath,
      );
      _appendLog(_l10n.logExportedStem(copied));
    }
  }

  Future<void> _exportBySaveDialogs(List<_StemItem> stems) async {
    for (final stem in stems) {
      final savePath = await _fileAccessService.pickSaveFilePath(
        suggestedName: stem.fileName,
        extension: stem.extensionWithoutDot,
      );
      if (savePath == null || savePath.trim().isEmpty) {
        _appendLog(_l10n.logSkippedStem(stem.fileName));
        continue;
      }
      final copied = await _exportFileService.copyWithConflictResolution(
        sourcePath: stem.path,
        destinationPath: savePath,
      );
      _appendLog(_l10n.logSavedStem(copied));
    }
  }

  String _previewStateText(AppLocalizations l10n) {
    switch (_previewState) {
      case InputPreviewState.idle:
        return l10n.previewStateNoInput;
      case InputPreviewState.loading:
        final stage = _latestPrepareProgress?.stage ?? InputPrepareStage.idle;
        return _prepareStageText(l10n, stage);
      case InputPreviewState.ready:
        return l10n.previewStateReady;
      case InputPreviewState.error:
        return l10n.previewStateFailed;
    }
  }

  String _prepareStageText(AppLocalizations l10n, InputPrepareStage stage) {
    switch (stage) {
      case InputPrepareStage.decode:
        return l10n.prepareStatusDecodingInput;
      case InputPrepareStage.resample:
        return l10n.prepareStatusNormalizing;
      case InputPrepareStage.writeCanonical:
        return l10n.prepareStatusWritingCanonical;
      case InputPrepareStage.done:
        return l10n.prepareStatusReady;
      case InputPrepareStage.idle:
        return l10n.statusPreparing;
    }
  }

  String _separationStatusText(AppLocalizations l10n) {
    final progress = _latestProgress;
    if (progress == null) {
      return l10n.statusIdle;
    }
    if (progress.state == SeparationJobState.cancelled) {
      return l10n.statusCancelled;
    }
    if (progress.state == SeparationJobState.failed) {
      return l10n.statusFailed;
    }
    if (progress.state == SeparationJobState.succeeded) {
      return l10n.statusCompleted;
    }
    switch (progress.stage) {
      case SeparationStage.decode:
        return l10n.statusDecodingResampling;
      case SeparationStage.infer:
        return l10n.statusRunningInference;
      case SeparationStage.encode:
        return l10n.statusEncodingOutput;
      case SeparationStage.done:
        return l10n.statusDone;
      case SeparationStage.idle:
        return l10n.statusPreparing;
    }
  }

  void _appendLog(String message) {
    if (!mounted) {
      return;
    }
    final entry = _LogEntry(id: _nextLogId++, message: message);
    _updateState(() {
      _logs.add(entry);
      if (_logs.length > _maxLogEntries) {
        _logs.removeRange(0, _logs.length - _maxLogEntries);
      }
    });
  }

  void _reportError(String message) {
    _appendLog(message);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration value) {
    if (value.isNegative) {
      value = Duration.zero;
    }
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatInferenceElapsed(Duration value) {
    final milliseconds = value.inMilliseconds;
    if (milliseconds < 1000) {
      return '$milliseconds ms';
    }
    return '${(milliseconds / 1000).toStringAsFixed(2)} s';
  }

  Widget _buildSeekBarForPath(String path) {
    final isActive = _activePlaybackPath == path;
    final durationMs = isActive
        ? _playbackDuration.inMilliseconds.toDouble()
        : 0.0;
    final positionMs = isActive
        ? _playbackPosition.inMilliseconds.toDouble()
        : 0.0;
    final safeMax = durationMs > 0 ? durationMs : 1.0;
    final safeValue = positionMs.clamp(0.0, safeMax);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(
            _formatDuration(isActive ? _playbackPosition : Duration.zero),
          ),
        ),
        Expanded(
          child: Slider(
            value: safeValue,
            min: 0.0,
            max: safeMax,
            onChanged: (isActive && durationMs > 0)
                ? (value) => unawaited(_seekPlayback(path, value))
                : null,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _formatDuration(isActive ? _playbackDuration : Duration.zero),
          ),
        ),
      ],
    );
  }

  Widget _buildStemActions({
    required AppLocalizations l10n,
    required _StemItem item,
    required bool isPlaying,
  }) {
    final checkbox = Checkbox(
      value: item.selected,
      onChanged: _exporting
          ? null
          : (value) {
              if (value == null) {
                return;
              }
              _updateState(() {
                item.selected = value;
              });
            },
    );
    final nameText = Text(
      item.fileName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final playButton = IconButton(
      onPressed: () => _togglePlaybackForPath(item.path),
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
    );
    final saveButton = TextButton(
      onPressed: _exporting ? null : () => _saveSingleStem(item),
      child: Text(l10n.saveAsButton),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  checkbox,
                  Expanded(child: nameText),
                ],
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[playButton, saveButton],
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            checkbox,
            Expanded(child: nameText),
            playButton,
            const SizedBox(width: 4),
            saveButton,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final separationProgress = _latestProgress?.progress ?? 0.0;
    final separationProgressText =
        '${(separationProgress * 100).toStringAsFixed(1)}%';
    final prepareProgress = _latestPrepareProgress?.progress ?? 0.0;
    final canStart =
        _nativeRuntimeSupported &&
        !_running &&
        !_exporting &&
        _previewState == InputPreviewState.ready &&
        !_loadingModelDefaults;
    final canPlayInput =
        _previewState == InputPreviewState.ready && _previewInfo != null;
    final preparing = _previewState == InputPreviewState.loading;
    final hasResults = _stemItems.isNotEmpty;
    final selectedCount = _stemItems.where((item) => item.selected).length;
    final defaults = _modelDefaults;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_nativeRuntimeSupported)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _nativeUnsupportedMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _modelPathController,
                  decoration: InputDecoration(labelText: l10n.modelPathLabel),
                  onSubmitted: (value) {
                    unawaited(_settingsStore.writeLastModelPath(value));
                    _updateState(() {
                      _modelDefaults = null;
                      _modelDefaultsPath = null;
                    });
                    if (_nativeRuntimeSupported) {
                      unawaited(_loadModelDefaultsIfNeeded(force: true));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _running ? null : _pickModelFile,
                child: Text(l10n.selectModelButton),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loadingModelDefaults)
            Text(l10n.loadingModelDefaults)
          else if (defaults != null)
            Text(
              l10n.modelDefaultsSummary(
                '${defaults.chunkSize}',
                '${defaults.overlap}',
                '${defaults.sampleRate}',
              ),
            )
          else
            Text(l10n.modelDefaultsNotLoaded),
          const SizedBox(height: 12),
          TextField(
            controller: _inputPathController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: l10n.selectedSourceAudioPathLabel,
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: (_running || !_nativeRuntimeSupported)
                    ? null
                    : _pickInputFile,
                child: Text(l10n.selectSourceButton),
              ),
              OutlinedButton(
                onPressed: canPlayInput && _previewInfo != null
                    ? () => _togglePlaybackForPath(_previewInfo!.canonicalPath)
                    : null,
                child: Text(
                  (_previewInfo != null &&
                          _activePlaybackPath == _previewInfo!.canonicalPath &&
                          _previewPlaying)
                      ? l10n.pauseInputButton
                      : l10n.playInputButton,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_previewStateText(l10n)),
          if (_previewInfo != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.canonicalInfo(
                _previewInfo!.canonicalPath,
                '${_previewInfo!.sampleRate}',
                '${_previewInfo!.channels}',
                '${_previewInfo!.durationMs}',
              ),
            ),
            _buildSeekBarForPath(_previewInfo!.canonicalPath),
          ],
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: preparing
                ? prepareProgress
                : (_previewState == InputPreviewState.ready ? 1.0 : 0.0),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outputPrefixController,
            decoration: InputDecoration(labelText: l10n.outputPrefixLabel),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AmsOutputFormat>(
            initialValue: _outputFormat,
            decoration: InputDecoration(labelText: l10n.outputLabel),
            items: AmsOutputFormat.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.name)),
                )
                .toList(growable: false),
            onChanged: _running
                ? null
                : (value) {
                    if (value != null) {
                      _updateState(() {
                        _outputFormat = value;
                      });
                    }
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ChunkOverlapMode>(
            initialValue: _chunkOverlapMode,
            decoration: InputDecoration(labelText: l10n.chunkOverlapModeLabel),
            items: ChunkOverlapMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(
                      mode == ChunkOverlapMode.auto
                          ? l10n.chunkOverlapModeAuto
                          : l10n.chunkOverlapModeCustom,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _running
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    _updateState(() {
                      _chunkOverlapMode = value;
                    });
                  },
          ),
          const SizedBox(height: 8),
          if (_chunkOverlapMode == ChunkOverlapMode.auto)
            Text(
              defaults == null
                  ? l10n.autoModeRequiresModel
                  : l10n.autoModeUsingDefaults(
                      '${defaults.chunkSize}',
                      '${defaults.overlap}',
                    ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _chunkSizeController,
                    decoration: InputDecoration(labelText: l10n.chunkSizeLabel),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _overlapController,
                    decoration: InputDecoration(labelText: l10n.overlapLabel),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: canStart ? _start : null,
                child: Text(l10n.startSeparationButton),
              ),
              OutlinedButton(
                onPressed: _running || preparing ? _cancel : null,
                child: Text(l10n.cancelButton),
              ),
              Text(separationProgressText),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _running ? separationProgress : 0.0),
          const SizedBox(height: 8),
          Text(_separationStatusText(l10n)),
          if (_lastInferenceElapsed != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.inferenceElapsedLabel(
                _formatInferenceElapsed(_lastInferenceElapsed!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.separationResultsTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (!hasResults)
            Text(l10n.noCachedStems)
          else ...<Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _exporting ? null : _exportAllStems,
                  child: Text(l10n.exportAllButton),
                ),
                OutlinedButton(
                  onPressed: _exporting ? null : _exportSelectedStems,
                  child: Text(l10n.exportSelectedButton('$selectedCount')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._stemItems.map((item) {
              final isPlaying =
                  _activePlaybackPath == item.path && _previewPlaying;
              return Card(
                key: ValueKey<String>(item.path),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: <Widget>[
                      _buildStemActions(
                        l10n: l10n,
                        item: item,
                        isPlaying: isPlaying,
                      ),
                      _buildSeekBarForPath(item.path),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.logsTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                reverse: false,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final entry = _logs[index];
                  return Text(entry.message, key: ValueKey<int>(entry.id));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
