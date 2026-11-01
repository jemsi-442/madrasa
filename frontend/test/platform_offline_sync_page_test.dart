import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_offline_sync_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Offline metadata is honest and responsive at $width', (
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
            body: PlatformOfflineSyncPage(
              onAudit: () => audit = true,
              onIncidents: () => incidents = true,
            ),
          ),
        ),
      );
      expect(
        find.text('Device sync reporting is not connected'),
        findsOneWidget,
      );
      expect(find.text('Conflict records are not connected'), findsOneWidget);
      expect(find.text('Synced'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Review audit logs'));
      await tester.tap(find.text('Review audit logs'));
      expect(audit, isTrue);
      await tester.ensureVisible(find.text('Open security incidents'));
      await tester.tap(find.text('Open security incidents'));
      expect(incidents, isTrue);
      await tester.ensureVisible(find.text('Synchronization safeguards'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
