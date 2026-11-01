import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/donation_messages_panel.dart';

void main() {
  testWidgets(
    'disabled service previews sample activity without changing live state',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DonationMessagesPanel(
                onSessionExpired: () {},
                load: (_) async {
                  calls++;
                  return {'enabled': false, 'items': []};
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Messages & reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Demo preview'), findsOneWidget);
      expect(
        find.text('Sample activity only. No SMS will be sent.'),
        findsOneWidget,
      );
      expect(find.text('DEMO-RECEIPT-002'), findsOneWidget);
      await tester.tap(find.text('View live status'));
      await tester.pumpAndSettle();
      expect(find.text('Live status'), findsOneWidget);
      expect(find.text('DEMO-RECEIPT-002'), findsNothing);
      expect(find.text('No notification records to show.'), findsOneWidget);
      expect(calls, 1);
    },
  );
  for (final width in [320.0, 1400.0]) {
    testWidgets('message cards and status reasons fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DonationMessagesPanel(
                onSessionExpired: () {},
                load: (_) async => {
                  'enabled': true,
                  'items': [
                    {
                      'reference': 'DON-00000002',
                      'status': 'SKIPPED',
                      'reason': 'PHONE_UNAVAILABLE',
                      'updatedAt': '2026-10-31T12:00:00Z',
                    },
                    {
                      'reference': 'DON-00000003',
                      'status': 'UNKNOWN',
                      'reason': 'NETWORK_UNCERTAIN',
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Messages & reminders'));
      await tester.pumpAndSettle();
      expect(
        find.text('A valid donor phone number is needed.'),
        findsOneWidget,
      );
      expect(find.text('Needs delivery check'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'messages load only on expansion and distinguish accepted from delivered',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DonationMessagesPanel(
                onSessionExpired: () {},
                load: (path) async {
                  expect(path, '/funds/messages');
                  calls++;
                  return {
                    'enabled': true,
                    'items': [
                      {'reference': 'DON-00000001', 'status': 'ACCEPTED'},
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Messages & reminders'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Accepted by Meseji'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('Pledge reminders'), findsOneWidget);
    },
  );
}
