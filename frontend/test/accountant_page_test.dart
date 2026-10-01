import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/accountant_components.dart';
import 'package:mif_app/src/accountant_page.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/dashboard_components.dart';

const _report = <String, dynamic>{
  'finance': {
    'invoices': {
      'total': 48,
      'pending': 12,
      'overdue': 3,
      'paid': 30,
      'amountDue': '7200000.00',
      'amountPaid': '5400000.00',
      'outstandingBalance': '1800000.00',
    },
    'collections': {'completedPayments': 36, 'collectedAmount': '5400000.00'},
    'expenses': {'total': 8, 'amount': '850000.00'},
    'netCashFlow': '4550000.00',
  },
};
const _invoice = <String, dynamic>{
  'id': '11',
  'invoiceNo': 'INV-2026-0011',
  'amountDue': '150000.00',
  'amountPaid': '50000.00',
  'currency': 'TZS',
  'status': 'PARTIALLY_PAID',
  'dueDate': '2026-10-15',
  'issuedAt': '2026-09-25T10:00:00Z',
  'student': {'fullName': 'Amina Hassan', 'admissionNo': 'AFQ-001'},
  'feeStructure': {'name': 'Term tuition'},
};
const _payment = <String, dynamic>{
  'id': '21',
  'reference': 'PAY-2026-0021',
  'amount': '50000.00',
  'currency': 'TZS',
  'status': 'COMPLETED',
  'channel': 'mpesa',
  'providerTxnRef': 'TEST-ONLY-REF',
  'createdAt': '2026-09-26T08:00:00Z',
  'paidAt': '2026-09-26T08:02:00Z',
  'invoice': _invoice,
};
const _request = <String, dynamic>{
  'id': '31',
  'status': 'NEW',
  'createdAt': '2026-09-27T10:00:00Z',
  'course': {'title': 'Arabic for Beginners'},
  'student': null,
  'learnerUser': {'fullName': 'Yusuf Ali', 'email': 'yusuf@example.test'},
  'invoice': _invoice,
};

Map<String, dynamic> _list(List<dynamic> items, {int pages = 1}) => {
  'items': items,
  'meta': {
    'page': 1,
    'pageSize': 10,
    'totalItems': items.length,
    'totalPages': pages,
  },
};

Future<dynamic> _load(String path) async {
  final uri = Uri.parse(path);
  return switch (uri.path) {
    '/api/reports/finance/home' => _report,
    '/api/invoices' => _list([
      _invoice,
      {
        ..._invoice,
        'id': '12',
        'invoiceNo': 'INV-2026-0012',
        'status': 'OVERDUE',
      },
    ]),
    '/api/payments' => _list([
      _payment,
      {
        ..._payment,
        'id': '22',
        'reference': 'PAY-2026-0022',
        'status': 'PENDING',
      },
    ]),
    '/api/payments/21' => _payment,
    '/api/payments/21/receipt' => {
      'receiptNo': 'RCP-20260926-000021',
      'payment': _payment,
      'organization': {'name': 'Example Madrasa'},
      'student': _invoice['student'],
      'invoice': {..._invoice, 'balanceRemaining': '100000.00'},
    },
    '/api/courses/access-requests' => [_request],
    _ => throw StateError('Unexpected request: $path'),
  };
}

void _viewport(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _page(
  WidgetTester tester,
  int section, {
  PageLoader load = _load,
  ValueChanged<FinanceDestination>? onOpen,
  FinanceDestination? destination,
  int refresh = 0,
}) async {
  final target = destination ?? FinanceDestination(section);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AccountantPage(
            key: ValueKey(target.key),
            load: load,
            destination: target,
            onOpen: onOpen ?? (_) {},
            refreshToken: refresh,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'money formatting uses exact cents and does not invent missing amounts',
    () {
      expect(
        financeMoney('9007199254740993.01', currency: 'TZS'),
        'TZS 9,007,199,254,740,993.01',
      );
      expect(financeMoney('-1500.5', currency: 'USD'), 'USD -1,500.50');
      expect(financeMoney('0'), '0.00');
      expect(financeMoney(null), 'Not available');
      expect(financeMoney('1.234'), 'Not available');
      expect(
        financeBalance({
          'amountDue': '0.30',
          'amountPaid': '0.10',
          'currency': 'USD',
        }),
        'USD 0.20',
      );
      expect(
        financeBalance({'amountDue': '0.10', 'amountPaid': '0.30'}),
        '-0.20',
      );
      expect(financeBalance({}), 'Not available');
    },
  );

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1440, 1000), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 740), 2.0),
  ]) {
    for (var section = 0; section < 4; section++) {
      testWidgets('finance page $section fits $size at text scale $scale', (
        tester,
      ) async {
        _viewport(tester, size, scale: scale);
        await _page(tester, section);
        expect(tester.takeException(), isNull);
        if (section != 0) {
          await _tap(
            tester,
            find.text(size.width > 900 ? 'Details' : 'View details').first,
          );
          expect(tester.takeException(), isNull);
          await _tap(tester, find.byTooltip('Close details'));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('overview actions route to correct filtered records', (
    tester,
  ) async {
    FinanceDestination? target;
    await _page(tester, 0, onOpen: (d) => target = d);
    expect(find.text('1,800,000.00'), findsOneWidget);
    expect(find.textContaining('currency unspecified'), findsOneWidget);
    expect(find.textContaining('TZS'), findsNothing);
    await _tap(tester, find.text('Follow up overdue invoices'));
    expect(target?.page, 1);
    expect(target?.status, 'OVERDUE');
    await _tap(tester, find.text('Check pending payments'));
    expect(target?.page, 2);
    expect(target?.status, 'PENDING');
    await _tap(tester, find.text('Follow up course requests'));
    expect(target?.page, 3);
    expect(target?.status, 'NEW');
  });

  testWidgets(
    'search, status and pagination use server filters and reset page',
    (tester) async {
      final paths = <Uri>[];
      Future<dynamic> load(String path) async {
        paths.add(Uri.parse(path));
        return _list([_invoice], pages: 3);
      }

      await _page(
        tester,
        1,
        load: load,
        destination: const FinanceDestination(1, status: 'OVERDUE'),
      );
      expect(paths.last.queryParameters['status'], 'OVERDUE');
      await _tap(tester, find.text('Next'));
      expect(paths.last.queryParameters['page'], '2');
      await tester.enterText(find.byType(TextField), 'Amina & Ali');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(paths.last.queryParameters['search'], 'Amina & Ali');
      expect(paths.last.queryParameters['page'], '1');
      expect(paths.last.queryParameters['status'], 'OVERDUE');
      await _tap(tester, find.text('Clear filters'));
      expect(paths.last.queryParameters.containsKey('search'), isFalse);
      expect(paths.last.queryParameters.containsKey('status'), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
    },
  );

  testWidgets(
    'invoice details link payments by invoice id without claiming paid',
    (tester) async {
      FinanceDestination? target;
      await _page(tester, 1, onOpen: (d) => target = d);
      await _tap(tester, find.text('View details').first);
      expect(find.text('Invoice details'), findsOneWidget);
      expect(find.text('TZS 100,000.00'), findsOneWidget);
      expect(find.text('View receipt'), findsNothing);
      await _tap(tester, find.text('View linked payments'));
      expect(target?.page, 2);
      expect(target?.invoiceId, '11');
      expect(find.text('Invoice details'), findsNothing);
    },
  );

  testWidgets('payment filters retain invoice scope until explicitly cleared', (
    tester,
  ) async {
    final paths = <Uri>[];
    await _page(
      tester,
      2,
      destination: const FinanceDestination(
        2,
        invoiceId: '11',
        invoiceNo: 'INV-11',
      ),
      load: (path) async {
        paths.add(Uri.parse(path));
        return _list([]);
      },
    );
    expect(paths.last.queryParameters['invoiceId'], '11');
    await _tap(tester, find.text('All channels'));
    await _tap(tester, find.text('Airtel Money').last);
    expect(paths.last.queryParameters['channel'], 'airtel_money');
    expect(paths.last.queryParameters['invoiceId'], '11');
    await _tap(tester, find.text('All statuses'));
    await _tap(tester, find.text('Failed').last);
    expect(paths.last.queryParameters['status'], 'FAILED');
    await _tap(tester, find.text('Clear filters'));
    expect(paths.last.queryParameters['invoiceId'], '11');
    expect(paths.last.queryParameters.containsKey('channel'), isFalse);
    await _tap(tester, find.text('All invoices'));
    expect(paths.last.queryParameters.containsKey('invoiceId'), isFalse);
  });

  testWidgets('completed payment loads fresh details and an in-app receipt', (
    tester,
  ) async {
    final paths = <String>[];
    await _page(
      tester,
      2,
      load: (path) {
        paths.add(path);
        return _load(path);
      },
    );
    await _tap(tester, find.text('View details').first);
    expect(paths, contains('/api/payments/21'));
    await _tap(tester, find.text('View receipt'));
    expect(paths, contains('/api/payments/21/receipt'));
    expect(find.text('Payment receipt'), findsOneWidget);
    expect(find.text('RCP-20260926-000021'), findsOneWidget);
    await _tap(tester, find.text('Back to payment'));
    expect(paths.last, '/api/payments/21');
    expect(find.text('View receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['PENDING', 'FAILED', 'EXPIRED', 'VOIDED']) {
    testWidgets(
      '$status fresh payment cannot open a receipt even if list was completed',
      (tester) async {
        await _page(
          tester,
          2,
          load: (path) async => Uri.parse(path).path == '/api/payments'
              ? _list([_payment])
              : {..._payment, 'status': status, 'paidAt': null},
        );
        await _tap(tester, find.text('View details'));
        expect(find.text('View receipt'), findsNothing);
        expect(
          find.text(
            'This payment is not confirmed. No receipt can be issued yet.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'receipt failures can retry and do not fabricate receipt content',
    (tester) async {
      var receiptCalls = 0;
      await _page(
        tester,
        2,
        load: (path) {
          if (path.endsWith('/receipt') && receiptCalls++ == 0) {
            return Future.error(Exception('Offline'));
          }
          return _load(path);
        },
      );
      await _tap(tester, find.text('View details').first);
      await _tap(tester, find.text('View receipt'));
      expect(find.text('Payment receipt'), findsNothing);
      await _tap(tester, find.text('Try again'));
      expect(find.text('RCP-20260926-000021'), findsOneWidget);
    },
  );

  testWidgets(
    'independent learner course search is local and keeps server status',
    (tester) async {
      final paths = <Uri>[];
      FinanceDestination? target;
      await _page(
        tester,
        3,
        destination: const FinanceDestination(3, status: 'NEW'),
        onOpen: (d) => target = d,
        load: (path) async {
          paths.add(Uri.parse(path));
          return [_request];
        },
      );
      expect(paths.single.queryParameters, {'status': 'NEW'});
      await tester.enterText(find.byType(TextField), 'yusuf@example.test');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(paths.length, 1);
      expect(find.text('Yusuf Ali'), findsOneWidget);
      await _tap(tester, find.text('View details'));
      expect(
        find.descendant(
          of: find.byType(FinanceFacts),
          matching: find.text('yusuf@example.test'),
        ),
        findsOneWidget,
      );
      expect(find.text('Approve'), findsNothing);
      await _tap(tester, find.text('View linked payments'));
      expect(target?.invoiceId, '11');
    },
  );

  testWidgets(
    'request without invoice and missing summary are honest empty states',
    (tester) async {
      await _page(
        tester,
        3,
        load: (_) async => [
          {..._request, 'invoice': null},
        ],
      );
      await _tap(tester, find.text('View details'));
      expect(find.text('View linked payments'), findsNothing);
      expect(find.textContaining('No invoice is linked'), findsOneWidget);
      await _tap(tester, find.byTooltip('Close details'));
      await _page(tester, 0, load: (_) async => <String, dynamic>{});
      expect(
        find.text('The finance summary is not available yet.'),
        findsOneWidget,
      );
      expect(find.text('0.00'), findsNothing);
    },
  );

  testWidgets(
    'loading, retry and external refresh preserve server filter context',
    (tester) async {
      final pending = Completer<dynamic>();
      final paths = <Uri>[];
      Future<dynamic> load(String path) {
        paths.add(Uri.parse(path));
        return paths.length == 1 ? pending.future : _load(path);
      }

      const target = FinanceDestination(1, status: 'OVERDUE');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountantPage(
                load: load,
                destination: target,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(Exception('Offline'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Try again'));
      expect(paths.last.queryParameters['status'], 'OVERDUE');
      await _page(tester, 1, load: load, destination: target);
      final count = paths.length;
      await _page(tester, 1, load: load, destination: target, refresh: 1);
      expect(paths.length, count + 1);
      expect(paths.last.queryParameters['status'], 'OVERDUE');
    },
  );

  testWidgets(
    'workspace follows home to overdue invoice to scoped payment and resets tab scope',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final paths = <Uri>[];
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          browserAuth: false,
          client: MockClient((request) async {
            paths.add(request.url);
            return http.Response(
              jsonEncode({'data': await _load(request.url.toString())}),
              200,
            );
          }),
        ),
      );
      state.session = const AuthSession(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        userId: '1',
        fullName: 'Amina Accountant',
        role: 'ACCOUNTANT',
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Follow up overdue invoices'));
      expect(paths.last.queryParameters['status'], 'OVERDUE');
      await _tap(tester, find.text('View details').first);
      await _tap(tester, find.text('View linked payments'));
      expect(paths.last.path, '/api/payments');
      expect(paths.last.queryParameters['invoiceId'], '11');
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Payments'),
        ),
      );
      expect(paths.last.queryParameters.containsKey('invoiceId'), isFalse);
      expect(find.textContaining('Payments for INV-'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  if (const bool.fromEnvironment('ACCOUNTANT_PREVIEWS')) {
    for (final (name, size, layout) in [
      ('mobile', const Size(390, 844), AppLayout.mobile),
      ('desktop', const Size(1580, 1180), AppLayout.website),
    ]) {
      testWidgets('preview $name accountant workspace', (tester) async {
        _viewport(tester, size);
        final state = AppState(
          MifApiClient(
            baseUrl: 'https://school.test',
            browserAuth: false,
            client: MockClient(
              (request) async => http.Response(
                jsonEncode({'data': await _load(request.url.toString())}),
                200,
              ),
            ),
          ),
        );
        state.session = const AuthSession(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          userId: '1',
          fullName: 'Amina Accountant',
          role: 'ACCOUNTANT',
        );
        addTearDown(state.dispose);
        await tester.pumpWidget(MifApp(state: state, layout: layout));
        await tester.runAsync(() async {
          final families =
              jsonDecode(await rootBundle.loadString('FontManifest.json'))
                  as List;
          for (final family in families) {
            final loader = FontLoader(family['family'] as String);
            for (final font in family['fonts'] as List) {
              loader.addFont(rootBundle.load(font['asset'] as String));
            }
            await loader.load();
          }
        });
        await tester.pumpAndSettle();
        for (final tab in ['Home', 'Invoices', 'Payments', 'Course access']) {
          if (tab != 'Home') {
            if (layout == AppLayout.mobile && tab == 'Course access') {
              await _tap(
                tester,
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('More'),
                ),
              );
              await _tap(
                tester,
                find.descendant(
                  of: find.byType(Drawer),
                  matching: find.text(tab),
                ),
              );
            } else {
              final finder = layout == AppLayout.mobile
                  ? find.descendant(
                      of: find.byType(NavigationBar),
                      matching: find.text(tab),
                    )
                  : find.text(tab).first;
              await _tap(tester, finder);
            }
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              Uri.file(
                '/tmp/accountant-$name-${tab.toLowerCase().replaceAll(' ', '-')}.png',
              ),
            ),
          );
        }
      });
    }
  }
}
