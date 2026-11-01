import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_sync_register.dart';

void main() {
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
