import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/office_help_page.dart';
import 'package:mif_app/src/public_information_page.dart';
import 'package:mif_app/src/public_shell.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('footer links and divider work at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MifApp());

      expect(find.text('Get in Touch'), findsNothing);
      final telegram = tester.widget<IconButton>(
        find.byKey(const ValueKey('footer-telegram')),
      );
      expect(telegram.onPressed, isNull);
      expect(telegram.tooltip, 'Telegram link coming soon');
      expect(find.byIcon(Icons.telegram), findsOneWidget);

      final divider = find.byKey(const ValueKey('public-footer-divider'));
      await tester.ensureVisible(divider);
      await tester.pumpAndSettle();
      expect(tester.widget<Divider>(divider).thickness, 1);
      expect(tester.getSize(divider).width, size.width);
      expect(
        tester.getTopLeft(find.textContaining('All rights reserved.')).dy,
        greaterThan(tester.getBottomRight(divider).dy),
      );
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('public-footer')))
            .color,
        publicBrandBlue,
      );
      expect(tester.takeException(), isNull);

      for (final (path, title) in [
        ('/terms', 'Terms & Conditions'),
        ('/privacy', 'Privacy Policy'),
      ]) {
        final link = find.byKey(ValueKey('footer-link-$path'));
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(PublicInformationScreen), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Publication Pending'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
      }

      final support = find.byKey(const ValueKey('footer-link-/contact'));
      await tester.ensureVisible(support);
      await tester.tap(support);
      await tester.pumpAndSettle();
      expect(find.byType(OfficeHelpScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('public-footer-divider')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
