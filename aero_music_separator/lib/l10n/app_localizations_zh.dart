// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Aero 音乐分离器';

  @override
  String get navInference => '推理';

  @override
  String get navSettings => '设置';

  @override
  String get navAbout => '关于';

  @override
  String get modelPathLabel => '模型路径 (.gguf)';

  @override
  String get selectModelButton => '选择模型';

  @override
  String get loadingModelDefaults => '正在加载模型默认参数...';

  @override
  String modelDefaultsSummary(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  ) {
    return '模型默认值: chunk=$chunkSize, overlap=$overlap, sampleRate=$sampleRate';
  }

  @override
  String get modelDefaultsNotLoaded => '模型默认参数未加载';

  @override
  String get selectedSourceAudioPathLabel => '已选源音频路径';

  @override
  String get selectSourceButton => '选择音频';

  @override
  String get playInputButton => '播放输入';

  @override
  String get pauseInputButton => '暂停输入';

  @override
  String get previewStateNoInput => '尚未选择输入文件';

  @override
  String get previewStateReady => '输入已准备完成，可试听与分离';

  @override
  String get previewStateFailed => '预处理失败';

  @override
  String canonicalInfo(
    Object path,
    Object sampleRate,
    Object channels,
    Object durationMs,
  ) {
    return '标准化文件: $path | ${sampleRate}Hz $channels声道 | ${durationMs}ms';
  }

  @override
  String get outputPrefixLabel => '输出前缀';

  @override
  String get outputLabel => '输出格式';

  @override
  String get chunkOverlapModeLabel => 'Chunk/Overlap 模式';

  @override
  String get chunkOverlapModeAuto => '自动（模型默认）';

  @override
  String get chunkOverlapModeCustom => '自定义（高级）';

  @override
  String get autoModeRequiresModel => '自动模式需要有效的模型文件。';

  @override
  String autoModeUsingDefaults(Object chunkSize, Object overlap) {
    return '使用模型默认值: chunk=$chunkSize, overlap=$overlap';
  }

  @override
  String get chunkSizeLabel => 'Chunk Size';

  @override
  String get overlapLabel => 'Overlap';

  @override
  String get startSeparationButton => '开始分离';

  @override
  String get cancelButton => '取消';

  @override
  String get separationResultsTitle => '分离结果';

  @override
  String get noCachedStems => '暂无缓存 stem 结果。';

  @override
  String get exportAllButton => '全部导出';

  @override
  String exportSelectedButton(Object count) {
    return '导出所选 ($count)';
  }

  @override
  String get saveAsButton => '另存为';

  @override
  String get logsTitle => '日志';

  @override
  String get statusIdle => '空闲';

  @override
  String get statusPreparing => '准备中';

  @override
  String get statusDone => '完成';

  @override
  String get statusCancelled => '已取消';

  @override
  String get statusFailed => '失败';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusDecodingResampling => '正在解码并重采样音频';

  @override
  String get statusRunningInference => '正在执行模型推理';

  @override
  String get statusEncodingOutput => '正在编码输出 stem';

  @override
  String inferenceElapsedLabel(Object elapsed) {
    return '推理耗时：$elapsed';
  }

  @override
  String get prepareStatusLoadingInput => '正在加载输入音频';

  @override
  String get prepareStatusDecodingInput => '正在解码输入音频';

  @override
  String get prepareStatusNormalizing => '正在统一采样率与声道';

  @override
  String get prepareStatusWritingCanonical => '正在写入标准化预览文件';

  @override
  String get prepareStatusReady => '已可预览';

  @override
  String logModelSelectionFailed(Object error) {
    return '模型选择失败: $error';
  }

  @override
  String logInputSelectionFailed(Object error) {
    return '输入选择失败: $error';
  }

  @override
  String get logPreparingInput => '正在准备输入，用于预览和分离...';

  @override
  String logInputReady(Object path) {
    return '输入预处理完成: $path';
  }

  @override
  String logPrepareFailed(Object error) {
    return '预处理失败: $error';
  }

  @override
  String logPlaybackFailed(Object error) {
    return '播放失败: $error';
  }

  @override
  String logLoadedModelDefaults(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  ) {
    return '已加载模型默认值: chunk=$chunkSize, overlap=$overlap, sampleRate=$sampleRate';
  }

  @override
  String logFailedReadModelDefaults(Object error) {
    return '读取模型默认值失败: $error';
  }

  @override
  String get logModelPathRequired => '模型路径不能为空。';

  @override
  String get logPrepareWaitRequired => '请选择输入文件并等待预处理完成。';

  @override
  String get logUnableLoadDefaults => '无法加载模型默认值，不能开始任务。';

  @override
  String get logInvalidChunkOverlap => 'Chunk Size 和 Overlap 必须是正整数。';

  @override
  String get logStartingTask => '正在使用缓存输出目录启动分离任务...';

  @override
  String get logTaskFinished => '任务完成，结果已缓存，可试听和导出。';

  @override
  String logInferenceElapsed(Object elapsed) {
    return '推理耗时：$elapsed';
  }

  @override
  String logTaskFailed(Object error) {
    return '任务失败: $error';
  }

  @override
  String logModelInput(Object path) {
    return '模型输入文件: $path';
  }

  @override
  String logCanonicalInput(Object path) {
    return '标准化输入文件: $path';
  }

  @override
  String get logCancellingTask => '正在取消分离任务...';

  @override
  String get logCancellingPrepare => '正在取消输入预处理...';

  @override
  String get logTaskCancelled => '分离任务已取消。';

  @override
  String get logPrepareCancelled => '输入预处理已取消。';

  @override
  String logSaveCancelled(Object name) {
    return '已取消保存 $name。';
  }

  @override
  String logSavedStem(Object path) {
    return '已保存 stem: $path';
  }

  @override
  String logSaveStemFailed(Object name, Object error) {
    return '保存 $name 失败: $error';
  }

  @override
  String get logNoStemsSelected => '没有选择需要导出的 stem。';

  @override
  String get logDirectoryExportUnavailable => '当前平台不支持目录导出，已回退为逐个另存为。';

  @override
  String get logExportCancelled => '导出已取消。';

  @override
  String logExportFailed(Object error) {
    return '导出失败: $error';
  }

  @override
  String logExportedStem(Object path) {
    return '已导出 stem: $path';
  }

  @override
  String logSkippedStem(Object name) {
    return '已跳过 stem: $name';
  }

  @override
  String get nativeRuntimeUnsupported => '当前构建不包含原生分离运行时支持。';

  @override
  String get settingsInferenceGroup => '推理';

  @override
  String get settingsUseCpuInference => '使用 CPU 推理';

  @override
  String get settingsOpenMpPreset => 'OpenMP 预设';

  @override
  String get settingsOpenMpNextTaskHint => '仅对下一次任务生效，不影响当前运行中的任务。';

  @override
  String get settingsOpenMpUnavailableIos => 'iOS 当前不支持 OpenMP，将保持禁用。';

  @override
  String get openMpPresetAuto => '自动';

  @override
  String get openMpPresetDisabled => '禁用';

  @override
  String get openMpPresetConservative => '保守';

  @override
  String get openMpPresetBalanced => '平衡';

  @override
  String get openMpPresetPerformance => '激进';

  @override
  String get settingsLanguageGroup => '语言';

  @override
  String get settingsLanguageSystem => '系统跟随';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsOtherGroup => '其他';

  @override
  String get settingsNavigateAboutHint => '应用信息与许可证请前往导航中的“关于”页面。';

  @override
  String aboutVersionLabel(Object version, Object buildNumber) {
    return '版本 $version ($buildNumber)';
  }

  @override
  String get aboutVersionUnknown => '版本信息不可用';

  @override
  String get aboutComponentsTitle => '核心组件';

  @override
  String get aboutComponentFfmpeg => 'FFmpeg：音频解码、编码与重采样';

  @override
  String get aboutComponentBsr => 'BSRoformer.cpp：音源分离推理核心';

  @override
  String get aboutComponentFfi => 'Flutter FFI：应用与原生桥接';

  @override
  String get aboutRepositoryTitle => '开源仓库';

  @override
  String get aboutLicenseButton => '开源许可证';
}
