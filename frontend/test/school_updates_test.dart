import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/school_updates_page.dart';

void main() {
  test('publication states reflect dates, not invented archive state', () {
    final now = DateTime.utc(2026, 11, 15);
    expect(schoolUpdateStatus({'publishAt': '2026-11-14'}, now), 'Published');
    expect(schoolUpdateStatus({'publishAt': '2026-11-16'}, now), 'Scheduled');
    expect(
      schoolUpdateStatus({
        'publishAt': '2026-11-01',
        'expiresAt': '2026-11-10',
      }, now),
      'Expired',
    );
    expect(schoolUpdateStatus({}, now), 'Unknown');
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('updates fit $width and open a notice', (tester) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: adminTheme(ThemeData()),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SchoolUpdatesPage(
                  load: (path) async {
                    expect(path, '/api/announcements');
                    loads++;
                    return List.generate(
                      12,
                      (i) => {
                        'id': '$i',
                        'title': 'Synthetic notice $i',
                        'message': 'Synthetic notice content $i',
                        'audience': 'TEACHERS',
                        'publishAt': '2020-01-01',
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('New Update'), findsNothing);
      expect(find.text('Synthetic notice 10'), findsNothing);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic notice 10'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'notice 11');
      await tester.pumpAndSettle();
      expect(find.text('Synthetic notice 10'), findsNothing);
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('Synthetic notice 11'), findsOneWidget);
      await tester.ensureVisible(find.text('Synthetic notice 11'));
      await tester.tap(find.text('Synthetic notice 11'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic notice content 11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
