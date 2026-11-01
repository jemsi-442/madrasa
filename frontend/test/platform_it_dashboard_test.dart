import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_it_dashboard.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    for (final busy in [false, true]) {
      testWidgets('IT overview width=$width busy=$busy', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        var now = DateTime.utc(2026, 10, 31, 8);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: const TextScaler.linear(1.2),
                ),
                child: PlatformItDashboard(
                  now: () => now,
                  busy: busy,
                  error: null,
                  onRefresh: () => actions.add('check'),
                  onHealth: () => actions.add('health'),
                  onSetup: () => actions.add('setup'),
                  onAccounts: () => actions.add('accounts'),
                  onAudit: () => actions.add('audit'),
                  onSessions: () => actions.add('sessions'),
                  snapshot: {
                    'checkedAt': now.toIso8601String(),
                    'status': 'degraded',
                    'checks': [
                      {
                        'name': 'database',
                        'status': 'available',
                        'latencyMs': 5,
                      },
                      {
                        'name': 'redis',
                        'status': 'unavailable',
                        'latencyMs': null,
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        );
        expect(find.text('IT & Security Overview'), findsOneWidget);
        expect(find.text('Review Redis connectivity'), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('Recovery readiness'), findsOneWidget);
        expect(find.text('Not measured'), findsNWidgets(2));
        for (final entry in {
          'Madrasa setup': 'setup',
          'Company accounts': 'accounts',
          'Audit trail': 'audit',
          'My sessions': 'sessions',
        }.entries) {
          await tester.ensureVisible(find.text(entry.key));
          await tester.tap(find.text(entry.key));
          await tester.pump();
          expect(actions.contains(entry.value), !busy);
        }
        expect(tester.takeException(), isNull);
        now = now.add(const Duration(seconds: 61));
        await tester.pump(const Duration(seconds: 61));
        expect(find.text('Not current'), findsNWidgets(3));
        expect(find.text('1 / 2'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
