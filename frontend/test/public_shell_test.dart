import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/public_shell.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('public bars share logo blue and full width at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MifApp(layout: AppLayout.website));

      final header = find.byKey(const ValueKey('public-header'));
      final footer = find.byKey(const ValueKey('public-footer'));
      void expectMatchingBars() {
        expect(tester.widget<Material>(header).color, publicBrandBlue);
        expect(tester.widget<Material>(footer).color, publicBrandBlue);
        expect(tester.getSize(header).width, size.width);
        expect(tester.getSize(footer).width, size.width);
        expect(find.textContaining('All rights reserved.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      expectMatchingBars();
      final headerTop = tester.getTopLeft(header);
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header), headerTop);

      await tester.tap(find.byKey(const ValueKey('header-login')));
      await tester.pumpAndSettle();
      expectMatchingBars();
      expect(tester.getBottomRight(footer).dy, size.height);

      await tester.ensureVisible(find.text('Register here'));
      await tester.tap(find.text('Register here'));
      await tester.pumpAndSettle();
      expectMatchingBars();
      expect(tester.getBottomRight(footer).dy, size.height);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.byType(PublicBrand), findsOneWidget);
    });
  }

  testWidgets('auth form scrolls clear of the header, footer and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MifApp(layout: AppLayout.website));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('public-header'))).dy,
      0,
    );
    await tester.tap(find.byKey(const ValueKey('header-login')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Register here'));
    await tester.tap(find.text('Register here'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('public-header'));
    final footer = find.byKey(const ValueKey('public-footer'));
    expect(
      tester.getTopLeft(create).dy,
      greaterThanOrEqualTo(tester.getBottomRight(header).dy),
    );
    expect(
      tester.getBottomRight(create).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
