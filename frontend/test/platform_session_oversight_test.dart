import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_sessions_page.dart';

void main() {
  for (final width in [360.0, 1440.0]) {
    testWidgets('IT sees account and IP metadata at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? source;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformSessionsPage(
              oversight: true,
              source: 'platform',
              onSource: (value) => source = value,
              records: const [
                {
                  'id': 'synthetic',
                  'accountName': 'Synthetic operator',
                  'role': 'IT_SECURITY',
                  'scope': 'Platform',
                  'ipAddress': '192.0.2.12',
                  'current': false,
                },
              ],
              busy: false,
              error: null,
              page: 1,
              onPage: (_) {},
              onRefresh: () {},
              details: (_) => const Text('Synthetic review'),
            ),
          ),
        ),
      );
      expect(find.text('Synthetic operator'), findsOneWidget);
      expect(find.textContaining('192.0.2.12'), findsOneWidget);
      await tester.ensureVisible(find.text('Review').first);
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic review'), findsOneWidget);
      await tester.ensureVisible(find.text('Platform accounts'));
      await tester.tap(find.text('Platform accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All madrasa accounts').last);
      await tester.pumpAndSettle();
      expect(source, 'madrasa');
      expect(find.text('Synthetic review'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
