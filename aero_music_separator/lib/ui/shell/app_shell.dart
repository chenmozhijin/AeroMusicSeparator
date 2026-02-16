import 'package:aero_music_separator/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../inference/inference_page.dart';
import '../settings/about_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.localeOverride,
    required this.onLocaleOverrideChanged,
  });

  final String? localeOverride;
  final Future<void> Function(String? localeCode) onLocaleOverrideChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _wideLayoutBreakpoint = 900;
  static const double _sidebarWidth = 220;

  int _index = 0;

  Widget _wrapIndexedPage({required bool active, required Widget child}) {
    return ExcludeSemantics(excluding: !active, child: child);
  }

  void _select(int value) {
    if (value == _index) {
      return;
    }
    setState(() {
      _index = value;
    });
  }

  Widget _buildNavigationPanel(
    BuildContext context,
    AppLocalizations l10n, {
    required bool closeOnTap,
  }) {
    void handleTap(int index) {
      _select(index);
      if (closeOnTap) {
        Navigator.of(context).pop();
      }
    }

    return Column(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(l10n.navInference),
          selected: _index == 0,
          onTap: () => handleTap(0),
        ),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(l10n.navSettings),
          selected: _index == 1,
          onTap: () => handleTap(1),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.navAbout),
          selected: _index == 2,
          onTap: () => handleTap(2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    final titles = <String>[l10n.navInference, l10n.navSettings, l10n.navAbout];
    final pages = <Widget>[
      _wrapIndexedPage(
        active: _index == 0,
        child: InferencePage(
          key: const ValueKey<String>('page-inference'),
          isActive: _index == 0,
        ),
      ),
      _wrapIndexedPage(
        active: _index == 1,
        child: SettingsPage(
          key: const ValueKey<String>('page-settings'),
          localeOverride: widget.localeOverride,
          onLocaleOverrideChanged: widget.onLocaleOverrideChanged,
        ),
      ),
      _wrapIndexedPage(
        active: _index == 2,
        child: const AboutPage(key: ValueKey<String>('page-about')),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: _buildNavigationPanel(context, l10n, closeOnTap: true),
              ),
            ),
      body: Row(
        children: <Widget>[
          if (isWide)
            SizedBox(
              width: _sidebarWidth,
              child: SafeArea(
                child: _buildNavigationPanel(context, l10n, closeOnTap: false),
              ),
            ),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
    );
  }
}
