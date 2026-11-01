import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_backups_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Backup evidence remains unverified at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var auditOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformBackupsPage(onAudit: () => auditOpened = true),
          ),
        ),
      );
      expect(find.text('Backup records are not connected'), findsOneWidget);
      expect(find.text('No verified restore result'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final evidence = find.widgetWithText(
        OutlinedButton,
        'View test evidence',
      );
      expect(tester.widget<OutlinedButton>(evidence).onPressed, isNull);
      await tester.ensureVisible(find.text('Review audit logs'));
      await tester.tap(find.text('Review audit logs'));
      expect(auditOpened, isTrue);
      await tester.ensureVisible(find.text('Restore & verify'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
