import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aero_music_separator/main.dart';

void main() {
  testWidgets(
    'navigation behavior switch preserves inference state across width changes',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const AeroMusicSeparatorApp());
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      expect(find.text('Inference'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('About'), findsWidgets);

      await tester.enterText(find.byType(TextField).at(2), 'kept-prefix');

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inference').first);
      await tester.pumpAndSettle();

      expect(find.text('kept-prefix'), findsOneWidget);

      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inference').last);
      await tester.pumpAndSettle();

      expect(find.text('kept-prefix'), findsOneWidget);

      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      expect(find.text('kept-prefix'), findsOneWidget);
    },
  );

  testWidgets(
    'semantics tree remains stable when switching navigation behavior',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const AeroMusicSeparatorApp());
        await tester.pumpAndSettle();

        for (var round = 0; round < 12; round++) {
          await tester.tap(find.text('Settings').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Inference').first);
          await tester.pumpAndSettle();

          tester.view.physicalSize = const Size(500, 900);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('About').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Inference').last);
          await tester.pumpAndSettle();

          tester.view.physicalSize = const Size(1400, 900);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('narrow layout uses drawer navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AeroMusicSeparatorApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('language switch updates navigation text', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AeroMusicSeparatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();

    expect(find.text('推理'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
