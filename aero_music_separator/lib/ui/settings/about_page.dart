import 'dart:async';

import 'package:aero_music_separator/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _repositoryUrl =
      'https://github.com/chenmozhijin/AeroMusicSeparator';

  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = info;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = _packageInfo;
    final versionText = info == null
        ? l10n.aboutVersionUnknown
        : l10n.aboutVersionLabel(info.version, info.buildNumber);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          l10n.appTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(versionText),
        const SizedBox(height: 16),
        Text(
          l10n.aboutComponentsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.aboutComponentFfmpeg),
        const SizedBox(height: 4),
        Text(l10n.aboutComponentBsr),
        const SizedBox(height: 4),
        Text(l10n.aboutComponentFfi),
        const SizedBox(height: 16),
        Text(
          l10n.aboutRepositoryTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SelectableText(_repositoryUrl),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: info == null
                  ? null
                  : '${info.version} (${info.buildNumber})',
            );
          },
          child: Text(l10n.aboutLicenseButton),
        ),
      ],
    );
  }
}
