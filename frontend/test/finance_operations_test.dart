import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/finance_operations_page.dart';
import 'package:mif_app/src/finance_reports_page.dart';
import 'package:mif_app/src/workspace.dart';

const _fee = <String, dynamic>{
  'id': '4',
  'name': 'Term tuition',
  'amount': '150000.00',
  'billingCycle': 'TERMLY',
  'isActive': true,
  'branch': {'name': 'Kibada'},
  'createdAt': '2026-09-25T08:00:00Z',
};
const _expense = <String, dynamic>{
  'id': '5',
  'title': 'Learning materials',
  'amount': '45000.00',
  'currency': 'TZS',
  'expenseDate': '2026-09-25',
  'description': 'Books and classroom supplies',
  'recordedBy': {'fullName': 'Amina Accountant'},
};
const _inquiry = <String, dynamic>{
  'id': '7',
  'inquiryType': 'FINANCE',
  'status': 'NEW',
  'fullName': 'Mariam Hassan',
  'phone': '0712345678',
  'email': 'mariam@example.test',
  'preferredContact': 'email',
  'subject': 'Term fee clarification',
  'message': 'Please confirm the tuition invoice for this term.',
  'createdAt': '2026-09-26T08:00:00Z',
};
const _month = <String, dynamic>{
  'month': 1,
  'label': 'January',
  'invoicesIssued': 4,
  'paymentsCollected': 3,
  'invoicedAmount': '600000.00',
  'collectedAmount': '450000.00',
  'expenseAmount': '45000.00',
  'netCashFlow': '405000.00',
  'expensesRecorded': 1,
};
const _report = <String, dynamic>{
  'year': 2026,
  'totals': _month,
  'months': [_month],
};

Map<String, dynamic> _list(List<dynamic> rows, {int page = 1, int pages = 1}) =>
    {
      'items': rows,
      'meta': {
        'page': page,
        'pageSize': 10,
        'totalItems': rows.length,
        'totalPages': pages,
      },
    };

Future<dynamic> _load(String path) async => switch (Uri.parse(path).path) {
  '/api/fee-structures' => _list([_fee]),
  '/api/expenses' => _list([_expense]),
  '/api/public-inquiries' => [_inquiry],
  '/api/reports/finance/monthly-summary' => _report,
  _ => <String, dynamic>{},
};
Future<dynamic> _submit(String path, Map<String, dynamic> body) async => {
  'id': '10',
  ...body,
};

void _size(WidgetTester tester, Size size, {double scale = 1}) {
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
  int page, {
  PageLoader load = _load,
  PageSubmitter submit = _submit,
  PageSubmitter update = _submit,
  FinanceCsvLoader? export,
  FinanceCsvSaver? save,
  int refresh = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: page == 6
              ? FinanceReportsPage(
                  load: load,
                  exportCsv:
                      export ?? (_) async => 'Month,Amount\nJanuary,1250.00',
                  saveCsv: save,
                  refreshToken: refresh,
                )
              : FinanceOperationsPage(
                  key: ValueKey(page),
                  page: page,
                  load: load,
                  submit: submit,
                  update: update,
                  refreshToken: refresh,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  test(
    'accountant has eight actual destinations, no admin-only management pages',
    () {
      final sections = sectionsForRole('ACCOUNTANT');
      expect(sections.length, 8);
      expect(sections.map((s) => s.title), [
        'Home',
        'Invoices',
        'Payments',
        'Course access',
        'Fee structures',
        'Expenses',
        'Financial reports',
        'Finance inbox',
      ]);
      expect(sections.any((s) => s.path.startsWith('/api/admin')), isFalse);
    },
  );

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1440, 1000), 1.0),
    (const Size(320, 740), 2.0),
  ]) {
    for (final page in [4, 5, 6, 7]) {
      testWidgets('finance operations $page fits $size at scale $scale', (
        tester,
      ) async {
        _size(tester, size, scale: scale);
        await _page(tester, page);
        expect(tester.takeException(), isNull);
        if (page == 4 || page == 5) {
          await _tap(
            tester,
            find.text(page == 4 ? 'Add fee structure' : 'Record expense'),
          );
          expect(tester.takeException(), isNull);
          await _tap(tester, find.text('Cancel'));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('fee search, active filter and pagination use backend query', (
    tester,
  ) async {
    final paths = <Uri>[];
    await _page(
      tester,
      4,
      load: (path) async {
        final uri = Uri.parse(path);
        paths.add(uri);
        return _list(
          [_fee],
          pages: 3,
          page: int.parse(uri.queryParameters['page']!),
        );
      },
    );
    await _tap(tester, find.byTooltip('Next page'));
    expect(paths.last.queryParameters['page'], '2');
    await tester.enterText(find.byType(TextField), 'Term & fees');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(paths.last.queryParameters['page'], '1');
    expect(paths.last.queryParameters['search'], 'Term & fees');
    await _tap(tester, find.text('All statuses'));
    await _tap(tester, find.text('Inactive').last);
    expect(paths.last.queryParameters['isActive'], 'false');
    await _tap(tester, find.text('Clear filters'));
    expect(paths.last.queryParameters.containsKey('isActive'), isFalse);
    expect(paths.last.queryParameters.containsKey('search'), isFalse);
  });

  testWidgets(
    'fee form validates money and saves exact decimal with scope delegated to server',
    (tester) async {
      final writes = <(String, Map<String, dynamic>)>[];
      var reads = 0;
      await _page(
        tester,
        4,
        load: (path) {
          reads++;
          return _load(path);
        },
        submit: (path, body) async {
          writes.add((path, body));
          return {'id': '55', ...body};
        },
      );
      await _tap(tester, find.text('Add fee structure'));
      await tester.enterText(_field('Fee name'), 'Tuition');
      await tester.enterText(_field('Amount (TZS)'), '0');
      await _tap(tester, find.text('Save entry'));
      expect(writes, isEmpty);
      expect(find.textContaining('Enter a positive amount'), findsOneWidget);
      await tester.enterText(_field('Amount (TZS)'), '12500.25');
      await _tap(tester, find.text('Save entry'));
      expect(writes.single.$1, '/api/fee-structures');
      expect(writes.single.$2, {
        'name': 'Tuition',
        'amount': '12500.25',
        'billingCycle': 'TERMLY',
        'isActive': true,
      });
      expect(reads, 2);
      expect(find.text('Fee structure created.'), findsOneWidget);
    },
  );

  testWidgets('expense form requires a date and records expense not payment', (
    tester,
  ) async {
    String? endpoint;
    Map<String, dynamic>? payload;
    await _page(
      tester,
      5,
      submit: (path, body) async {
        endpoint = path;
        payload = body;
        return {'id': '88', ...body};
      },
    );
    await _tap(tester, find.text('Record expense'));
    await tester.enterText(_field('Expense title'), 'Books');
    await tester.enterText(_field('Amount (TZS)'), '45000.00');
    await _tap(tester, find.text('Save entry'));
    expect(endpoint, isNull);
    expect(find.text('Choose the expense date.'), findsOneWidget);
    await _tap(tester, _field('Expense date'));
    await _tap(tester, find.text('OK'));
    await _tap(tester, find.text('Save entry'));
    expect(endpoint, '/api/expenses');
    expect(payload?['currency'], 'TZS');
    expect(payload?['expenseDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(payload?.containsKey('branchId'), isFalse);
    expect(find.text('Expense recorded.'), findsOneWidget);
  });

  testWidgets(
    'failed unconfirmed create cannot be submitted twice and reloads register',
    (tester) async {
      var writes = 0, reads = 0;
      await _page(
        tester,
        4,
        load: (p) {
          reads++;
          return _load(p);
        },
        submit: (_, _) async {
          writes++;
          throw const ApiException('Offline', 0);
        },
      );
      await _tap(tester, find.text('Add fee structure'));
      await tester.enterText(_field('Fee name'), 'Tuition');
      await tester.enterText(_field('Amount (TZS)'), '10.00');
      await _tap(tester, find.text('Save entry'));
      expect(find.textContaining('avoid duplicates'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save entry'),
            )
            .onPressed,
        isNull,
      );
      expect(writes, 1);
      await _tap(tester, find.text('Check register'));
      expect(reads, 2);
      expect(find.text('Fee structure created.'), findsNothing);
    },
  );

  testWidgets(
    'busy form blocks double submission and dirty cancel asks before discarding',
    (tester) async {
      final pending = Completer<dynamic>();
      var writes = 0;
      await _page(
        tester,
        4,
        submit: (_, _) {
          writes++;
          return pending.future;
        },
      );
      await _tap(tester, find.text('Add fee structure'));
      await tester.enterText(_field('Fee name'), 'Tuition');
      await _tap(tester, find.text('Cancel'));
      expect(find.text('Discard this entry?'), findsOneWidget);
      await _tap(tester, find.text('Keep editing'));
      expect(find.text('Tuition'), findsOneWidget);
      await tester.enterText(_field('Amount (TZS)'), '10.00');
      await _tap(tester, find.text('Save entry'));
      expect(writes, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Saving...'),
            )
            .onPressed,
        isNull,
      );
      pending.complete({'id': '10'});
      await tester.pumpAndSettle();
      expect(find.text('Fee structure created.'), findsOneWidget);
    },
  );

  testWidgets(
    'timed-out save requires a register check even after a late response',
    (tester) async {
      final pending = Completer<dynamic>();
      var writes = 0;
      await _page(
        tester,
        4,
        submit: (_, _) {
          writes++;
          return pending.future;
        },
      );
      await _tap(tester, find.text('Add fee structure'));
      await tester.enterText(_field('Fee name'), 'Tuition');
      await tester.enterText(_field('Amount (TZS)'), '10.00');
      await _tap(tester, find.text('Save entry'));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Check register'), findsOneWidget);
      expect(writes, 1);
      pending.complete({'id': '10'});
      await tester.pumpAndSettle();
      expect(find.text('Fee structure created.'), findsNothing);
      expect(find.text('Check register'), findsOneWidget);
      await _tap(tester, find.text('Check register'));
    },
  );

  testWidgets('rejected fee save stays editable without claiming success', (
    tester,
  ) async {
    await _page(
      tester,
      4,
      submit: (_, _) async {
        throw const ApiException('Forbidden', 403);
      },
    );
    await _tap(tester, find.text('Add fee structure'));
    await tester.enterText(_field('Fee name'), 'Tuition');
    await tester.enterText(_field('Amount (TZS)'), '10.00');
    await _tap(tester, find.text('Save entry'));
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Fee structure created.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save entry'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('rejected inquiry update retains the original status', (
    tester,
  ) async {
    var reads = 0;
    await _page(
      tester,
      7,
      load: (path) {
        reads++;
        return _load(path);
      },
      update: (_, _) async {
        throw const ApiException('Forbidden', 403);
      },
    );
    await _tap(tester, find.text('Term fee clarification'));
    await _tap(tester, find.byType(DropdownButtonFormField<String>).last);
    await _tap(tester, find.text('Closed').last);
    await _tap(tester, find.text('Save status'));
    expect(reads, 1);
    expect(find.text('You cannot update this inquiry.'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inbox only requests FINANCE and updates status without contacting anyone',
    (tester) async {
      final paths = <Uri>[], writes = <(String, Map<String, dynamic>)>[];
      await _page(
        tester,
        7,
        load: (path) {
          paths.add(Uri.parse(path));
          return _load(path);
        },
        update: (path, body) async {
          writes.add((path, body));
          return {..._inquiry, ...body};
        },
      );
      expect(paths.single.queryParameters['inquiryType'], 'FINANCE');
      await _tap(tester, find.text('Term fee clarification'));
      expect(find.textContaining('does not send a message'), findsOneWidget);
      await _tap(tester, find.byType(DropdownButtonFormField<String>).last);
      await _tap(tester, find.text('Contacted').last);
      await _tap(tester, find.text('Save status'));
      expect(writes.single.$1, '/api/public-inquiries/7/status');
      expect(writes.single.$2, {'status': 'CONTACTED'});
      expect(paths.last.queryParameters['inquiryType'], 'FINANCE');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monthly report year applies to read and exact CSV export, cancel does not report saved',
    (tester) async {
      final reads = <Uri>[], exports = <Uri>[];
      String? filename, content;
      await _page(
        tester,
        6,
        load: (path) async {
          reads.add(Uri.parse(path));
          return _report;
        },
        export: (path) async {
          exports.add(Uri.parse(path));
          return 'Month,Amount\nJanuary,450000.00';
        },
        save: (name, csv) async {
          filename = name;
          content = csv;
          return false;
        },
      );
      await _tap(tester, find.byType(DropdownButtonFormField<int>));
      await _tap(tester, find.text('2025').last);
      expect(reads.last.queryParameters['year'], '2025');
      await _tap(tester, find.text('Save CSV'));
      expect(exports.single.queryParameters['year'], '2025');
      expect(filename, 'finance-monthly-summary-2025.csv');
      expect(content, contains('January,450000.00'));
      expect(find.textContaining('CSV saved'), findsNothing);
      expect(find.textContaining('not a debtor balance'), findsOneWidget);
    },
  );

  testWidgets(
    'CSV preview stays in app and failure is not a download success',
    (tester) async {
      var fail = true;
      await _page(
        tester,
        6,
        export: (_) async {
          if (fail) throw const ApiException('Forbidden', 403);
          return 'Month,Amount\nJan,25.00';
        },
      );
      await _tap(tester, find.text('View CSV'));
      expect(find.textContaining('could not be completed'), findsOneWidget);
      expect(find.text('Copy CSV'), findsNothing);
      fail = false;
      await _tap(tester, find.text('View CSV'));
      expect(find.text('Month,Amount\nJan,25.00'), findsOneWidget);
      expect(find.text('Copy CSV'), findsOneWidget);
    },
  );

  testWidgets('CSV copy failure stays in the preview and reports no success', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'CLIPBOARD_UNAVAILABLE');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _page(tester, 6, export: (_) async => 'Month,Amount\\nJan,25.00');
    await _tap(tester, find.text('View CSV'));
    await _tap(tester, find.text('Copy CSV'));
    expect(find.textContaining('could not be copied'), findsOneWidget);
    expect(find.text('CSV copied to clipboard.'), findsNothing);
    expect(find.text('Month,Amount\\nJan,25.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('CSV save reports actual platform outcome: failure=$fails', (
      tester,
    ) async {
      var saves = 0;
      await _page(
        tester,
        6,
        export: (_) async => 'Month,Amount\\nJan,25.00',
        save: (_, _) async {
          saves++;
          if (fails) {
            throw PlatformException(code: 'SAVE_FAILED');
          }
          return true;
        },
      );
      await _tap(tester, find.text('Save CSV'));
      expect(saves, 1);
      expect(
        find.text('CSV saved to your chosen location.'),
        fails ? findsNothing : findsOneWidget,
      );
      expect(
        find.textContaining('could not be completed'),
        fails ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('register request failure can retry into an honest empty state', (
    tester,
  ) async {
    var reads = 0;
    await _page(
      tester,
      5,
      load: (_) async {
        reads++;
        if (reads == 1) throw const ApiException('Offline', 0);
        return _list([]);
      },
    );
    expect(find.text('Learning materials'), findsNothing);
    await _tap(tester, find.text('Try again'));
    expect(reads, 2);
    expect(find.text('No records match this view.'), findsOneWidget);
    expect(find.text('0 matching records'), findsOneWidget);
  });

  testWidgets('More exposes each new accountant page on a phone', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final paths = <String>[];
    final state =
        AppState(
            MifApiClient(
              baseUrl: 'https://school.test',
              browserAuth: false,
              client: MockClient((request) async {
                paths.add(request.url.path);
                return http.Response(
                  jsonEncode({'data': await _load(request.url.toString())}),
                  200,
                );
              }),
            ),
          )
          ..session = const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            userId: '9',
            fullName: 'Amina Accountant',
            role: 'ACCOUNTANT',
          );
    addTearDown(state.dispose);
    await tester.pumpWidget(MifApp(state: state, layout: AppLayout.mobile));
    await tester.pumpAndSettle();
    for (final (name, path) in [
      ('Fee structures', '/api/fee-structures'),
      ('Expenses', '/api/expenses'),
      ('Financial reports', '/api/reports/finance/monthly-summary'),
      ('Finance inbox', '/api/public-inquiries'),
    ]) {
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await _tap(
        tester,
        find.descendant(of: find.byType(Drawer), matching: find.text(name)),
      );
      expect(paths.last, path);
      expect(find.byType(Drawer), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  if (const bool.fromEnvironment('FINANCE_OPERATIONS_PREVIEWS')) {
    for (final (name, size, layout) in [
      ('mobile', const Size(390, 844), AppLayout.mobile),
      ('desktop', const Size(1580, 1180), AppLayout.website),
    ]) {
      testWidgets('preview extended finance $name', (tester) async {
        _size(tester, size);
        final state =
            AppState(
                MifApiClient(
                  baseUrl: 'https://school.test',
                  browserAuth: false,
                  client: MockClient(
                    (r) async => http.Response(
                      jsonEncode({'data': await _load(r.url.toString())}),
                      200,
                    ),
                  ),
                ),
              )
              ..session = const AuthSession(
                accessToken: 'access',
                refreshToken: 'refresh',
                userId: '9',
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
        for (final tab in [
          'Fee structures',
          'Expenses',
          'Financial reports',
          'Finance inbox',
        ]) {
          if (layout == AppLayout.mobile) {
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
            await _tap(tester, find.text(tab).first);
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              Uri.file(
                '/tmp/finance-$name-${tab.toLowerCase().replaceAll(' ', '-')}.png',
              ),
            ),
          );
        }
      });
    }
  }
}
