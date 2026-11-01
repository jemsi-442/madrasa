import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_funds_page.dart';
import 'package:mif_app/src/api_client.dart';

Map<String, dynamic> snapshot() => {
  'month': '2026-10',
  'currency': 'TZS',
  'page': 1,
  'total': 11,
  'generatedAt': '2026-10-31T00:00:00Z',
  'summary': {
    'donors': 1,
    'pledged': '100.00',
    'received': '40.00',
    'outstanding': '60.00',
  },
  'items': [
    {
      'donorReference': 'DON-1',
      'madrasa': 'Synthetic madrasa',
      'fund': 'Education',
      'pledged': '100.00',
      'received': '40.00',
      'status': 'Partial',
    },
  ],
};
void main() {
  testWidgets(
    'automatic updates preserve message drafts and retry transient failures',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0, offline = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformFundsPage(
              onSessionExpired: () {},
              load: (path) async {
                if (!path.startsWith('/funds?'))
                  return {'ready': true, 'hasMore': false, 'items': []};
                requests++;
                if (offline) throw Exception('offline');
                return snapshot();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Donor messages'));
      await tester.tap(find.text('Donor messages'));
      await tester.pumpAndSettle();
      final message = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Message',
      );
      await tester.ensureVisible(message);
      await tester.enterText(message, 'Synthetic unsaved draft');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Synthetic unsaved draft'), findsOneWidget);
      offline = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic unsaved draft'), findsOneWidget);
      expect(find.textContaining('Reconnecting automatically'), findsOneWidget);
      offline = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(requests, 4);
      expect(find.textContaining('Reconnecting automatically'), findsNothing);
      expect(find.text('Synthetic unsaved draft'), findsOneWidget);
    },
  );
  for (final code in [401, 403]) {
    testWidgets('access failure $code hides financial data', (tester) async {
      var expired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformFundsPage(
              load: (_) async => throw ApiException('synthetic error', code),
              onSessionExpired: () => expired = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(expired, code == 401);
      expect(find.text('Monthly donor commitments'), findsNothing);
      expect(
        find.text(
          code == 401
              ? 'Your session has expired. Sign in again.'
              : 'Your account does not have access to donor oversight.',
        ),
        findsOneWidget,
      );
    });
  }
  test('money formatting preserves exact decimals and large amounts', () {
    expect(formatFundAmount('1250000.01'), '1,250,000.01');
    expect(
      formatFundAmount('99999999999999999.99'),
      '99,999,999,999,999,999.99',
    );
    expect(formatFundAmount('-1000.05'), '-1,000.05');
    expect(formatFundAmount('0.00'), '0.00');
    expect(
      fundsSnapshotLabel('2026-10-31T03:10:11+03:00'),
      'Updated 2026-10-31 at 00:10 UTC',
    );
  });
  for (final outcome in ['saved', 'cancelled', 'failed']) {
    testWidgets('summary export handles $outcome without inventing success', (
      tester,
    ) async {
      String? exported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformFundsPage(
              load: (_) async => snapshot(),
              onSessionExpired: () {},
              saveCsv: (name, content) async {
                exported = content;
                expect(name, 'donation-summary-2026-10-TZS.csv');
                if (outcome == 'failed') throw Exception('synthetic failure');
                return outcome == 'saved';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Financial summary CSV'));
      await tester.pumpAndSettle();
      expect(exported, contains('Receipts during month,40.00'));
      expect(exported, contains('Available balance,Not available'));
      expect(
        find.text('Summary CSV export requested.'),
        outcome == 'saved' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Export failed. Please try again.'),
        outcome == 'failed' ? findsOneWidget : findsNothing,
      );
    });
  }
  testWidgets('pagination and calendar send the selected scope to backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformFundsPage(
            load: (path) async {
              calls.add(path);
              return snapshot();
            },
            onSessionExpired: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(calls.last, endsWith('page=2'));
    final calendar = find.widgetWithIcon(
      OutlinedButton,
      Icons.calendar_month_outlined,
    );
    await tester.ensureVisible(calendar);
    await tester.tap(calendar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feb'));
    await tester.pumpAndSettle();
    expect(calls.last, contains('month=${DateTime.now().year}-02'));
    expect(calls.last, endsWith('page=1'));
  });
  for (final width in [390.0, 1600.0]) {
    testWidgets('funds layout fits $width and uses read-only data', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformFundsPage(
              load: (path) async {
                calls.add(path);
                return snapshot();
              },
              onSessionExpired: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Donors & Funds'), findsOneWidget);
      expect(find.text('Monthly donor commitments'), findsOneWidget);
      expect(find.text('Financial position'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      expect(calls.single, contains('/funds?month='));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failure does not display zero balances and retry reloads', (
    tester,
  ) async {
    var fails = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformFundsPage(
            load: (_) async {
              if (fails) throw Exception('offline');
              return snapshot();
            },
            onSessionExpired: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Financial position'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Financial position'), findsOneWidget);
  });
}
