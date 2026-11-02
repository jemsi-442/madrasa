import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_system_health_page.dart';

void main() {
  testWidgets('Only fresh verified failures can open investigation drafts', (
    tester,
  ) async {
    final checked = DateTime.utc(2026, 11, 2);
    var now = checked;
    String? draft;
    Future<void> render({bool busy = false, String? error}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformSystemHealthPage(
              snapshot: {
                'checkedAt': checked.toIso8601String(),
                'checks': [
                  {
                    'name': 'database',
                    'status': 'unavailable',
                    'detail': 'private-sentinel',
                  },
                  {
                    'name': 'unexpected-private-service',
                    'status': 'unavailable',
                  },
                ],
              },
              busy: busy,
              error: error,
              now: () => now,
              onRefresh: () {},
              onInvestigate: (value) => draft = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final button = find.widgetWithText(
      OutlinedButton,
      'Investigate failed checks',
    );
    await render();
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(draft, contains('Unavailable services: Database'));
    expect(draft, isNot(contains('private')));
    expect(find.text('0 / 1'), findsOneWidget);
    await render(error: 'Connection failed');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    now = checked.add(const Duration(seconds: 61));
    await render();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty checks do not imply healthy services', (tester) async {
    final now = DateTime.utc(2026, 11, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformSystemHealthPage(
            snapshot: {'checkedAt': now.toIso8601String(), 'checks': []},
            busy: false,
            error: null,
            now: () => now,
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(
      find.textContaining('No connectivity checks were returned'),
      findsOneWidget,
    );
    expect(find.text('No failed connectivity checks.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('System health layout and freshness at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026, 11, 1);
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformSystemHealthPage(
              snapshot: {
                'checkedAt': now.toIso8601String(),
                'checks': [
                  {'name': 'database', 'status': 'available', 'latencyMs': 4},
                  {'name': 'redis', 'status': 'unavailable'},
                ],
              },
              busy: false,
              error: null,
              now: () => now,
              onRefresh: () => refreshes++,
            ),
          ),
        ),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Not measured'), findsWidgets);
      expect(find.text('Shared services'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Refresh status'));
      expect(refreshes, 1);
      if (width > 1000) {
        await tester.ensureVisible(find.text('Details').first);
        await tester.tap(find.text('Details').first);
        await tester.pumpAndSettle();
        expect(find.text('Status at opening'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
      now = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('1 / 2'), findsNothing);
      expect(find.text('Not current'), findsWidgets);
      expect(
        find.textContaining('Current availability is unknown'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
