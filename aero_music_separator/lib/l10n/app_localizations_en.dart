// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aero Music Separator';

  @override
  String get navInference => 'Inference';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAbout => 'About';

  @override
  String get modelPathLabel => 'Model Path (.gguf)';

  @override
  String get selectModelButton => 'Select Model';

  @override
  String get loadingModelDefaults => 'Loading model defaults...';

  @override
  String modelDefaultsSummary(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  ) {
    return 'Model defaults: chunk=$chunkSize, overlap=$overlap, sampleRate=$sampleRate';
  }

  @override
  String get modelDefaultsNotLoaded => 'Model defaults not loaded';

  @override
  String get selectedSourceAudioPathLabel => 'Selected Source Audio Path';

  @override
  String get selectSourceButton => 'Select Source';

  @override
  String get playInputButton => 'Play Input';

  @override
  String get pauseInputButton => 'Pause Input';

  @override
  String get previewStateNoInput => 'No input selected';

  @override
  String get previewStateReady => 'Input ready for preview and separation';

  @override
  String get previewStateFailed => 'Prepare failed';

  @override
  String canonicalInfo(
    Object path,
    Object sampleRate,
    Object channels,
    Object durationMs,
  ) {
    return 'Canonical: $path | ${sampleRate}Hz ${channels}ch | ${durationMs}ms';
  }

  @override
  String get outputPrefixLabel => 'Output Prefix';

  @override
  String get outputLabel => 'Output';

  @override
  String get chunkOverlapModeLabel => 'Chunk/Overlap Mode';

  @override
  String get chunkOverlapModeAuto => 'Auto (model defaults)';

  @override
  String get chunkOverlapModeCustom => 'Custom (advanced)';

  @override
  String get autoModeRequiresModel => 'Auto mode requires a valid model file.';

  @override
  String autoModeUsingDefaults(Object chunkSize, Object overlap) {
    return 'Using model defaults: chunk=$chunkSize, overlap=$overlap';
  }

  @override
  String get chunkSizeLabel => 'Chunk Size';

  @override
  String get overlapLabel => 'Overlap';

  @override
  String get startSeparationButton => 'Start Separation';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get separationResultsTitle => 'Separation Results';

  @override
  String get noCachedStems => 'No cached stems yet.';

  @override
  String get exportAllButton => 'Export All';

  @override
  String exportSelectedButton(Object count) {
    return 'Export Selected ($count)';
  }

  @override
  String get saveAsButton => 'Save As';

  @override
  String get logsTitle => 'Logs';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusDone => 'Done';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusDecodingResampling => 'Decoding and resampling audio';

  @override
  String get statusRunningInference => 'Running model inference';

  @override
  String get statusEncodingOutput => 'Encoding output stems';

  @override
  String inferenceElapsedLabel(Object elapsed) {
    return 'Inference elapsed: $elapsed';
  }

  @override
  String get prepareStatusLoadingInput => 'Loading input audio';

  @override
  String get prepareStatusDecodingInput => 'Decoding input audio';

  @override
  String get prepareStatusNormalizing => 'Normalizing sample rate and channels';

  @override
  String get prepareStatusWritingCanonical => 'Writing canonical preview file';

  @override
  String get prepareStatusReady => 'Ready for preview';

  @override
  String logModelSelectionFailed(Object error) {
    return 'Model selection failed: $error';
  }

  @override
  String logInputSelectionFailed(Object error) {
    return 'Input selection failed: $error';
  }

  @override
  String get logPreparingInput =>
      'Preparing input for preview and separation...';

  @override
  String logInputReady(Object path) {
    return 'Input ready for preview: $path';
  }

  @override
  String logPrepareFailed(Object error) {
    return 'Prepare failed: $error';
  }

  @override
  String logPlaybackFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String logLoadedModelDefaults(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  ) {
    return 'Loaded model defaults: chunk=$chunkSize, overlap=$overlap, sampleRate=$sampleRate';
  }

  @override
  String logFailedReadModelDefaults(Object error) {
    return 'Failed to read model defaults: $error';
  }

  @override
  String get logModelPathRequired => 'Model path is required.';

  @override
  String get logPrepareWaitRequired =>
      'Please select an input file and wait until prepare is ready.';

  @override
  String get logUnableLoadDefaults =>
      'Unable to load model defaults. Cannot start.';

  @override
  String get logInvalidChunkOverlap =>
      'Chunk size and overlap must both be positive integers.';

  @override
  String get logStartingTask =>
      'Starting separation task with cached output...';

  @override
  String get logTaskFinished =>
      'Task finished. Results are cached and ready to preview/export.';

  @override
  String get logAndroidCpuOnlyPolicy =>
      'Android CPU-only policy is active. Vulkan is disabled.';

  @override
  String logInferenceElapsed(Object elapsed) {
    return 'Inference elapsed: $elapsed';
  }

  @override
  String logTaskFailed(Object error) {
    return 'Task failed: $error';
  }

  @override
  String logModelInput(Object path) {
    return 'Model input: $path';
  }

  @override
  String logCanonicalInput(Object path) {
    return 'Canonical input: $path';
  }

  @override
  String get logCancellingTask => 'Cancelling separation task...';

  @override
  String get logCancellingPrepare => 'Cancelling input prepare...';

  @override
  String get logTaskCancelled => 'Separation task cancelled.';

  @override
  String get logPrepareCancelled => 'Input prepare cancelled.';

  @override
  String logSaveCancelled(Object name) {
    return 'Save cancelled for $name.';
  }

  @override
  String logSavedStem(Object path) {
    return 'Saved stem: $path';
  }

  @override
  String logSaveStemFailed(Object name, Object error) {
    return 'Failed to save $name: $error';
  }

  @override
  String get logNoStemsSelected => 'No stems selected for export.';

  @override
  String get logDirectoryExportUnavailable =>
      'Directory export is unavailable on this platform. Falling back to save dialogs.';

  @override
  String get logExportCancelled => 'Export cancelled.';

  @override
  String logExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String logExportedStem(Object path) {
    return 'Exported stem: $path';
  }

  @override
  String logSkippedStem(Object name) {
    return 'Skipped stem: $name';
  }

  @override
  String get nativeRuntimeUnsupported =>
      'Native separation runtime is unavailable in this build.';

  @override
  String get settingsInferenceGroup => 'Inference';

  @override
  String get settingsUseCpuInference => 'Use CPU Inference';

  @override
  String get settingsAndroidCpuOnlyNotice =>
      'Android uses CPU-only inference. Vulkan is disabled for stability and better overall performance.';

  @override
  String get settingsOpenMpPreset => 'OpenMP Preset';

  @override
  String get settingsOpenMpNextTaskHint =>
      'Applies to the next task. Running tasks are not affected.';

  @override
  String get settingsOpenMpUnavailableIos =>
      'OpenMP is unavailable on iOS and will stay disabled.';

  @override
  String get openMpPresetAuto => 'Auto';

  @override
  String get openMpPresetDisabled => 'Disabled';

  @override
  String get openMpPresetConservative => 'Conservative';

  @override
  String get openMpPresetBalanced => 'Balanced';

  @override
  String get openMpPresetPerformance => 'Performance';

  @override
  String get settingsLanguageGroup => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsOtherGroup => 'Other';

  @override
  String get settingsNavigateAboutHint =>
      'Use the About page in navigation for app information and licenses.';

  @override
  String aboutVersionLabel(Object version, Object buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get aboutVersionUnknown => 'Version unavailable';

  @override
  String get aboutComponentsTitle => 'Core Components';

  @override
  String get aboutComponentFfmpeg => 'FFmpeg: audio decode/encode and resample';

  @override
  String get aboutComponentBsr =>
      'BSRoformer.cpp: source separation inference core';

  @override
  String get aboutComponentFfi => 'Flutter FFI: app-native bridge';

  @override
  String get aboutRepositoryTitle => 'Open Source Repository';

  @override
  String get aboutLicenseButton => 'Open Source Licenses';
}
