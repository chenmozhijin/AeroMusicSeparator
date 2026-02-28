import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aero Music Separator'**
  String get appTitle;

  /// No description provided for @navInference.
  ///
  /// In en, this message translates to:
  /// **'Inference'**
  String get navInference;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @modelPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Model Path (.gguf)'**
  String get modelPathLabel;

  /// No description provided for @selectModelButton.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModelButton;

  /// No description provided for @loadingModelDefaults.
  ///
  /// In en, this message translates to:
  /// **'Loading model defaults...'**
  String get loadingModelDefaults;

  /// No description provided for @modelDefaultsSummary.
  ///
  /// In en, this message translates to:
  /// **'Model defaults: chunk={chunkSize}, overlap={overlap}, sampleRate={sampleRate}'**
  String modelDefaultsSummary(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  );

  /// No description provided for @modelDefaultsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Model defaults not loaded'**
  String get modelDefaultsNotLoaded;

  /// No description provided for @selectedSourceAudioPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected Source Audio Path'**
  String get selectedSourceAudioPathLabel;

  /// No description provided for @selectSourceButton.
  ///
  /// In en, this message translates to:
  /// **'Select Source'**
  String get selectSourceButton;

  /// No description provided for @playInputButton.
  ///
  /// In en, this message translates to:
  /// **'Play Input'**
  String get playInputButton;

  /// No description provided for @pauseInputButton.
  ///
  /// In en, this message translates to:
  /// **'Pause Input'**
  String get pauseInputButton;

  /// No description provided for @previewStateNoInput.
  ///
  /// In en, this message translates to:
  /// **'No input selected'**
  String get previewStateNoInput;

  /// No description provided for @previewStateReady.
  ///
  /// In en, this message translates to:
  /// **'Input ready for preview and separation'**
  String get previewStateReady;

  /// No description provided for @previewStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Prepare failed'**
  String get previewStateFailed;

  /// No description provided for @canonicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Canonical: {path} | {sampleRate}Hz {channels}ch | {durationMs}ms'**
  String canonicalInfo(
    Object path,
    Object sampleRate,
    Object channels,
    Object durationMs,
  );

  /// No description provided for @outputPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Prefix'**
  String get outputPrefixLabel;

  /// No description provided for @outputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get outputLabel;

  /// No description provided for @chunkOverlapModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Chunk/Overlap Mode'**
  String get chunkOverlapModeLabel;

  /// No description provided for @chunkOverlapModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (model defaults)'**
  String get chunkOverlapModeAuto;

  /// No description provided for @chunkOverlapModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom (advanced)'**
  String get chunkOverlapModeCustom;

  /// No description provided for @autoModeRequiresModel.
  ///
  /// In en, this message translates to:
  /// **'Auto mode requires a valid model file.'**
  String get autoModeRequiresModel;

  /// No description provided for @autoModeUsingDefaults.
  ///
  /// In en, this message translates to:
  /// **'Using model defaults: chunk={chunkSize}, overlap={overlap}'**
  String autoModeUsingDefaults(Object chunkSize, Object overlap);

  /// No description provided for @chunkSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Chunk Size'**
  String get chunkSizeLabel;

  /// No description provided for @overlapLabel.
  ///
  /// In en, this message translates to:
  /// **'Overlap'**
  String get overlapLabel;

  /// No description provided for @startSeparationButton.
  ///
  /// In en, this message translates to:
  /// **'Start Separation'**
  String get startSeparationButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @separationResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Separation Results'**
  String get separationResultsTitle;

  /// No description provided for @noCachedStems.
  ///
  /// In en, this message translates to:
  /// **'No cached stems yet.'**
  String get noCachedStems;

  /// No description provided for @exportAllButton.
  ///
  /// In en, this message translates to:
  /// **'Export All'**
  String get exportAllButton;

  /// No description provided for @exportSelectedButton.
  ///
  /// In en, this message translates to:
  /// **'Export Selected ({count})'**
  String exportSelectedButton(Object count);

  /// No description provided for @saveAsButton.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get saveAsButton;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get statusPreparing;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusDecodingResampling.
  ///
  /// In en, this message translates to:
  /// **'Decoding and resampling audio'**
  String get statusDecodingResampling;

  /// No description provided for @statusRunningInference.
  ///
  /// In en, this message translates to:
  /// **'Running model inference'**
  String get statusRunningInference;

  /// No description provided for @statusEncodingOutput.
  ///
  /// In en, this message translates to:
  /// **'Encoding output stems'**
  String get statusEncodingOutput;

  /// No description provided for @inferenceElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Inference elapsed: {elapsed}'**
  String inferenceElapsedLabel(Object elapsed);

  /// No description provided for @prepareStatusLoadingInput.
  ///
  /// In en, this message translates to:
  /// **'Loading input audio'**
  String get prepareStatusLoadingInput;

  /// No description provided for @prepareStatusDecodingInput.
  ///
  /// In en, this message translates to:
  /// **'Decoding input audio'**
  String get prepareStatusDecodingInput;

  /// No description provided for @prepareStatusNormalizing.
  ///
  /// In en, this message translates to:
  /// **'Normalizing sample rate and channels'**
  String get prepareStatusNormalizing;

  /// No description provided for @prepareStatusWritingCanonical.
  ///
  /// In en, this message translates to:
  /// **'Writing canonical preview file'**
  String get prepareStatusWritingCanonical;

  /// No description provided for @prepareStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for preview'**
  String get prepareStatusReady;

  /// No description provided for @logModelSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Model selection failed: {error}'**
  String logModelSelectionFailed(Object error);

  /// No description provided for @logInputSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Input selection failed: {error}'**
  String logInputSelectionFailed(Object error);

  /// No description provided for @logPreparingInput.
  ///
  /// In en, this message translates to:
  /// **'Preparing input for preview and separation...'**
  String get logPreparingInput;

  /// No description provided for @logInputReady.
  ///
  /// In en, this message translates to:
  /// **'Input ready for preview: {path}'**
  String logInputReady(Object path);

  /// No description provided for @logPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Prepare failed: {error}'**
  String logPrepareFailed(Object error);

  /// No description provided for @logPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String logPlaybackFailed(Object error);

  /// No description provided for @logLoadedModelDefaults.
  ///
  /// In en, this message translates to:
  /// **'Loaded model defaults: chunk={chunkSize}, overlap={overlap}, sampleRate={sampleRate}'**
  String logLoadedModelDefaults(
    Object chunkSize,
    Object overlap,
    Object sampleRate,
  );

  /// No description provided for @logFailedReadModelDefaults.
  ///
  /// In en, this message translates to:
  /// **'Failed to read model defaults: {error}'**
  String logFailedReadModelDefaults(Object error);

  /// No description provided for @logModelPathRequired.
  ///
  /// In en, this message translates to:
  /// **'Model path is required.'**
  String get logModelPathRequired;

  /// No description provided for @logPrepareWaitRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select an input file and wait until prepare is ready.'**
  String get logPrepareWaitRequired;

  /// No description provided for @logUnableLoadDefaults.
  ///
  /// In en, this message translates to:
  /// **'Unable to load model defaults. Cannot start.'**
  String get logUnableLoadDefaults;

  /// No description provided for @logInvalidChunkOverlap.
  ///
  /// In en, this message translates to:
  /// **'Chunk size and overlap must both be positive integers.'**
  String get logInvalidChunkOverlap;

  /// No description provided for @logStartingTask.
  ///
  /// In en, this message translates to:
  /// **'Starting separation task with cached output...'**
  String get logStartingTask;

  /// No description provided for @logTaskFinished.
  ///
  /// In en, this message translates to:
  /// **'Task finished. Results are cached and ready to preview/export.'**
  String get logTaskFinished;

  /// No description provided for @logAndroidCpuOnlyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Android CPU-only policy is active. Vulkan is disabled.'**
  String get logAndroidCpuOnlyPolicy;

  /// No description provided for @logInferenceElapsed.
  ///
  /// In en, this message translates to:
  /// **'Inference elapsed: {elapsed}'**
  String logInferenceElapsed(Object elapsed);

  /// No description provided for @logTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Task failed: {error}'**
  String logTaskFailed(Object error);

  /// No description provided for @logModelInput.
  ///
  /// In en, this message translates to:
  /// **'Model input: {path}'**
  String logModelInput(Object path);

  /// No description provided for @logCanonicalInput.
  ///
  /// In en, this message translates to:
  /// **'Canonical input: {path}'**
  String logCanonicalInput(Object path);

  /// No description provided for @logCancellingTask.
  ///
  /// In en, this message translates to:
  /// **'Cancelling separation task...'**
  String get logCancellingTask;

  /// No description provided for @logCancellingPrepare.
  ///
  /// In en, this message translates to:
  /// **'Cancelling input prepare...'**
  String get logCancellingPrepare;

  /// No description provided for @logTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Separation task cancelled.'**
  String get logTaskCancelled;

  /// No description provided for @logPrepareCancelled.
  ///
  /// In en, this message translates to:
  /// **'Input prepare cancelled.'**
  String get logPrepareCancelled;

  /// No description provided for @logSaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Save cancelled for {name}.'**
  String logSaveCancelled(Object name);

  /// No description provided for @logSavedStem.
  ///
  /// In en, this message translates to:
  /// **'Saved stem: {path}'**
  String logSavedStem(Object path);

  /// No description provided for @logSaveStemFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save {name}: {error}'**
  String logSaveStemFailed(Object name, Object error);

  /// No description provided for @logNoStemsSelected.
  ///
  /// In en, this message translates to:
  /// **'No stems selected for export.'**
  String get logNoStemsSelected;

  /// No description provided for @logDirectoryExportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Directory export is unavailable on this platform. Falling back to save dialogs.'**
  String get logDirectoryExportUnavailable;

  /// No description provided for @logExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get logExportCancelled;

  /// No description provided for @logExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String logExportFailed(Object error);

  /// No description provided for @logExportedStem.
  ///
  /// In en, this message translates to:
  /// **'Exported stem: {path}'**
  String logExportedStem(Object path);

  /// No description provided for @logSkippedStem.
  ///
  /// In en, this message translates to:
  /// **'Skipped stem: {name}'**
  String logSkippedStem(Object name);

  /// No description provided for @nativeRuntimeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Native separation runtime is unavailable in this build.'**
  String get nativeRuntimeUnsupported;

  /// No description provided for @settingsInferenceGroup.
  ///
  /// In en, this message translates to:
  /// **'Inference'**
  String get settingsInferenceGroup;

  /// No description provided for @settingsUseCpuInference.
  ///
  /// In en, this message translates to:
  /// **'Use CPU Inference'**
  String get settingsUseCpuInference;

  /// No description provided for @settingsAndroidCpuOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Android uses CPU-only inference. Vulkan is disabled for stability and better overall performance.'**
  String get settingsAndroidCpuOnlyNotice;

  /// No description provided for @settingsOpenMpPreset.
  ///
  /// In en, this message translates to:
  /// **'OpenMP Preset'**
  String get settingsOpenMpPreset;

  /// No description provided for @settingsOpenMpNextTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to the next task. Running tasks are not affected.'**
  String get settingsOpenMpNextTaskHint;

  /// No description provided for @settingsOpenMpUnavailableIos.
  ///
  /// In en, this message translates to:
  /// **'OpenMP is unavailable on iOS and will stay disabled.'**
  String get settingsOpenMpUnavailableIos;

  /// No description provided for @openMpPresetAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get openMpPresetAuto;

  /// No description provided for @openMpPresetDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get openMpPresetDisabled;

  /// No description provided for @openMpPresetConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative'**
  String get openMpPresetConservative;

  /// No description provided for @openMpPresetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get openMpPresetBalanced;

  /// No description provided for @openMpPresetPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get openMpPresetPerformance;

  /// No description provided for @settingsLanguageGroup.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageGroup;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsOtherGroup.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsOtherGroup;

  /// No description provided for @settingsNavigateAboutHint.
  ///
  /// In en, this message translates to:
  /// **'Use the About page in navigation for app information and licenses.'**
  String get settingsNavigateAboutHint;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String aboutVersionLabel(Object version, Object buildNumber);

  /// No description provided for @aboutVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get aboutVersionUnknown;

  /// No description provided for @aboutComponentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Core Components'**
  String get aboutComponentsTitle;

  /// No description provided for @aboutComponentFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg: audio decode/encode and resample'**
  String get aboutComponentFfmpeg;

  /// No description provided for @aboutComponentBsr.
  ///
  /// In en, this message translates to:
  /// **'BSRoformer.cpp: source separation inference core'**
  String get aboutComponentBsr;

  /// No description provided for @aboutComponentFfi.
  ///
  /// In en, this message translates to:
  /// **'Flutter FFI: app-native bridge'**
  String get aboutComponentFfi;

  /// No description provided for @aboutRepositoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Repository'**
  String get aboutRepositoryTitle;

  /// No description provided for @aboutLicenseButton.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get aboutLicenseButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
