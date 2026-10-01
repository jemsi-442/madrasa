import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/public_entry_visuals.dart';

const _previews = bool.fromEnvironment('ENTRY_PREVIEWS');

Future<void> _loadPreviewAssets(WidgetTester tester) async {
  if (!_previews) return;
  await tester.runAsync(() async {
    final families =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in families) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    await precacheImage(
      const AssetImage('assets/learning-hero.png'),
      tester.element(find.byType(MaterialApp)),
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, layout, size) in [
    ('mobile', AppLayout.mobile, const Size(390, 844)),
    ('desktop', AppLayout.website, const Size(1440, 1000)),
  ]) {
    testWidgets('$name entry has artwork and working account navigation', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MifApp(layout: layout));
      await _loadPreviewAssets(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LearningPortrait), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (_previews) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(Uri.file('/tmp/mif-$name-home-v2.png')),
        );
      }

      final login = find.byKey(
        ValueKey(layout == AppLayout.mobile ? 'mobile-login' : 'header-login'),
      );
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      if (_previews) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(Uri.file('/tmp/mif-$name-login-v2.png')),
        );
      }

      final password = find.byKey(const ValueKey('login-password'));
      await tester.enterText(password, 'private-test-password');
      final reveal = find.byTooltip('Show password');
      await tester.ensureVisible(reveal);
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: password,
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isFalse,
      );
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: password,
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('public entry respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: EntryReveal(child: Text('Ready to learn')),
        ),
      ),
    );
    expect(find.text('Ready to learn'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EntryReveal),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(EntryReveal),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
  });

  for (final width in [1024.0, 1152.0, 1440.0]) {
    testWidgets('web entry supports large text at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 768);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const MifApp(layout: AppLayout.website));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Open menu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('header-login')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
