import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_sessions_page.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('Session selection and removal at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget page(List<Map<String, dynamic>> rows) => MaterialApp(
        home: Scaffold(
          body: PlatformSessionsPage(
            records: rows,
            busy: false,
            error: null,
            page: 1,
            onPage: (_) {},
            onRefresh: () {},
            details: (row) => Text('Selected ${row['id']}'),
          ),
        ),
      );
      await tester.pumpWidget(
        page([
          {
            'id': 'synthetic',
            'current': true,
            'createdAt': '2026-11-01T08:00:00Z',
            'expiresAt': '2026-11-02T08:00:00Z',
          },
        ]),
      );
      expect(find.text('Sessions & Devices'), findsOneWidget);
      expect(find.text('Selected synthetic'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Selected synthetic'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Close review'));
      await tester.tap(find.text('Close review'));
      await tester.pumpAndSettle();
      expect(find.text('Selected synthetic'), findsNothing);
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Selected synthetic'), findsOneWidget);
      await tester.pumpWidget(page([]));
      expect(find.text('Selected synthetic'), findsNothing);
      expect(
        find.text('Select a session to review its details.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
