import 'dart:async';

import 'package:aero_music_separator/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'core/licenses/third_party_licenses.dart';
import 'core/settings/app_settings_store.dart';
import 'ui/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await registerThirdPartyLicenses();
  runApp(const AeroMusicSeparatorApp());
}

class AeroMusicSeparatorApp extends StatefulWidget {
  const AeroMusicSeparatorApp({super.key});

  @override
  State<AeroMusicSeparatorApp> createState() => _AeroMusicSeparatorAppState();
}

class _AeroMusicSeparatorAppState extends State<AeroMusicSeparatorApp> {
  final AppSettingsStore _settingsStore = AppSettingsStore();
  String? _localeOverride;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocaleOverride());
  }

  Future<void> _loadLocaleOverride() async {
    final value = await _settingsStore.readLocaleOverride();
    if (!mounted) {
      return;
    }
    setState(() {
      _localeOverride = value;
    });
  }

  Future<void> _updateLocaleOverride(String? localeCode) async {
    await _settingsStore.writeLocaleOverride(localeCode);
    if (!mounted) {
      return;
    }
    setState(() {
      _localeOverride = localeCode;
    });
  }

  Locale? get _resolvedLocale {
    if (_localeOverride == null || _localeOverride!.isEmpty) {
      return null;
    }
    return Locale(_localeOverride!);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Aero Music Separator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C6EFD)),
      ),
      locale: _resolvedLocale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        localeOverride: _localeOverride,
        onLocaleOverrideChanged: _updateLocaleOverride,
      ),
    );
  }
}
