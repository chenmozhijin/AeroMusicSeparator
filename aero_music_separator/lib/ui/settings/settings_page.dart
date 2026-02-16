import 'dart:async';

import 'package:aero_music_separator/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings_store.dart';
import '../../core/settings/openmp_preset.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.localeOverride,
    required this.onLocaleOverrideChanged,
  });

  final String? localeOverride;
  final Future<void> Function(String? localeCode) onLocaleOverrideChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppSettingsStore _settingsStore = AppSettingsStore();

  bool _loading = true;
  bool _forceCpu = false;
  OpenMpPreset _openMpPreset = OpenMpPreset.auto;
  String? _localeOverride;

  bool get _openMpUnavailableOnIos =>
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _localeOverride = widget.localeOverride;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeOverride != widget.localeOverride) {
      setState(() {
        _localeOverride = widget.localeOverride;
      });
    }
  }

  Future<void> _load() async {
    final forceCpu = await _settingsStore.readForceCpuEnabled();
    final preset = await _settingsStore.readOpenMpPreset();
    if (!mounted) {
      return;
    }
    setState(() {
      _forceCpu = forceCpu;
      _openMpPreset = preset;
      _loading = false;
    });
  }

  Future<void> _updateForceCpu(bool value) async {
    setState(() {
      _forceCpu = value;
    });
    await _settingsStore.writeForceCpuEnabled(value);
  }

  Future<void> _updatePreset(OpenMpPreset value) async {
    setState(() {
      _openMpPreset = value;
    });
    await _settingsStore.writeOpenMpPreset(value);
  }

  String _presetLabel(AppLocalizations l10n, OpenMpPreset preset) {
    switch (preset) {
      case OpenMpPreset.auto:
        return l10n.openMpPresetAuto;
      case OpenMpPreset.disabled:
        return l10n.openMpPresetDisabled;
      case OpenMpPreset.conservative:
        return l10n.openMpPresetConservative;
      case OpenMpPreset.balanced:
        return l10n.openMpPresetBalanced;
      case OpenMpPreset.performance:
        return l10n.openMpPresetPerformance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.settingsInferenceGroup,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsUseCpuInference),
                  value: _forceCpu,
                  onChanged: _updateForceCpu,
                ),
                DropdownButtonFormField<OpenMpPreset>(
                  initialValue: _openMpPreset,
                  decoration: InputDecoration(labelText: l10n.settingsOpenMpPreset),
                  items: OpenMpPreset.values
                      .map(
                        (preset) => DropdownMenuItem<OpenMpPreset>(
                          value: preset,
                          child: Text(_presetLabel(l10n, preset)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _openMpUnavailableOnIos
                      ? null
                      : (value) {
                          if (value != null) {
                            unawaited(_updatePreset(value));
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _openMpUnavailableOnIos
                      ? l10n.settingsOpenMpUnavailableIos
                      : l10n.settingsOpenMpNextTaskHint,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.settingsLanguageGroup,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _localeOverride,
                  decoration: const InputDecoration(),
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.settingsLanguageSystem),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'zh',
                      child: Text(l10n.settingsLanguageChinese),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'en',
                      child: Text(l10n.settingsLanguageEnglish),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _localeOverride = value;
                    });
                    await widget.onLocaleOverrideChanged(value);
                  },
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.settingsOtherGroup,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.settingsNavigateAboutHint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
