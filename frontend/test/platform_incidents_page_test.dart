import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_incidents_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Incidents unavailable state and navigation at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var audit = false;
      var health = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformIncidentsPage(
              onAudit: () => audit = true,
              onHealth: () => health = true,
            ),
          ),
        ),
      );
      expect(find.text('Not connected'), findsNWidgets(4));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Review audit logs'));
      await tester.tap(find.text('Review audit logs'));
      expect(audit, isTrue);
      await tester.ensureVisible(find.text('Check service health'));
      await tester.tap(find.text('Check service health'));
      expect(health, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
