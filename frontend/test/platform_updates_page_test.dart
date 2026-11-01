import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_updates_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Update readiness without invented evidence at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var audit = false;
      var incidents = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformUpdatesPage(
              onAudit: () => audit = true,
              onIncidents: () => incidents = true,
            ),
          ),
        ),
      );
      expect(find.text('Evidence not connected'), findsNWidgets(4));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Review audit logs'));
      await tester.tap(find.text('Review audit logs'));
      expect(audit, isTrue);
      await tester.ensureVisible(find.text('Open incidents'));
      await tester.tap(find.text('Open incidents'));
      expect(incidents, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
