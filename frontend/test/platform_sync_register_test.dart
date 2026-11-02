import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_sync_register.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'Empty received updates have distinct metadata and navigation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformSyncRegister(
                onAudit: () {},
                onIncidents: () {},
                request: (_) async => {
                  'items': [],
                  'total': 0,
                  'capturedAt': '2026-11-02T05:04:00Z',
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Last checked (UTC)'), findsOneWidget);
        expect(find.text('0 received events'), findsOneWidget);
        expect(find.text('Page 1 of 1'), findsOneWidget);
        expect(find.text('Existing version'), findsNothing);
        await tester.ensureVisible(find.text('Check updates'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final status in [401, 403, 409]) {
    testWidgets('Access failure $status clears metadata and stops polling', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformSyncRegister(
              onAudit: () {},
              onIncidents: () {},
              request: (_) async {
                if (++calls > 1) {
                  throw ApiException('Synthetic access failure', status);
                }
                return {
                  'items': [
                    {
                      'receiptId': 'private-receipt',
                      'madrasaId': 'synthetic',
                      'receivedAt': '2026-01-01T00:00:00Z',
                    },
                  ],
                  'total': 1,
                  'capturedAt': '2026-01-01T00:00:00Z',
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private-receipt'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('private-receipt'), findsNothing);
      expect(find.textContaining('Last checked (UTC)'), findsNothing);
      expect(
        find.text(
          'Access could not be verified. Sign in again or check your permissions.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Sync polling pauses in background and checks on resume', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformSyncRegister(
            onAudit: () {},
            onIncidents: () {},
            request: (_) async {
              calls++;
              return {
                'items': [],
                'total': 0,
                'capturedAt': '2026-01-01T00:00:00Z',
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loads received metadata and retains it on refresh failure', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformSyncRegister(
            onAudit: () {},
            onIncidents: () {},
            request: (_) async {
              if (++calls > 1) throw Exception('Synthetic failure');
              return {
                'items': [
                  {
                    'receiptId': 'synthetic-receipt',
                    'madrasaId': '2',
                    'receivedAt': '2026-01-01T00:00:00Z',
                  },
                ],
                'total': 1,
                'capturedAt': '2026-01-01T01:00:00Z',
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('synthetic-receipt'), findsOneWidget);
    await tester.ensureVisible(find.text('Check updates'));
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-receipt'), findsOneWidget);
    expect(find.textContaining('Previously loaded records'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
