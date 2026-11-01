import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_audit_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Audit events searchable and read-only at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAuditPage(
              records: [
                {
                  'id': 'synthetic-event',
                  'action': 'platform.login.failed',
                  'actorRole': 'IT_SECURITY',
                  'createdAt': '2026-11-01T08:00:00Z',
                },
              ],
              busy: false,
              error: null,
              filters: const Text('Filters'),
              page: 1,
              onPage: (_) {},
              onRefresh: () {},
              onDetails: (_) => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      expect(opened, isTrue);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('No audit events match this view.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('platform.login.failed'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
