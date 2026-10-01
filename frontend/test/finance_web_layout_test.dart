import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/finance_monthly_chart.dart';
import 'package:mif_app/src/finance_presentation.dart';
import 'package:mif_app/src/workspace_chrome.dart';

const months = [
  {
    'month': 1,
    'label': 'January',
    'collectedAmount': '1234.56',
    'expenseAmount': '100.00',
  },
  {
    'month': 2,
    'label': 'February',
    'collectedAmount': '0.00',
    'expenseAmount': null,
  },
  {
    'month': 3,
    'label': 'March',
    'collectedAmount': '-25.00',
    'expenseAmount': '50.00',
  },
];

Future<void> show(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, scale) in [(320.0, 2.0), (768.0, 1.0), (1440.0, 1.0)]) {
    testWidgets('finance header, long filters and chart fit $width at $scale', (
      tester,
    ) async {
      await show(
        tester,
        Column(
          children: [
            FinanceSectionHeading(
              'Expense register',
              subtitle: 'Record school costs and supporting information.',
              eyebrow: 'School expenditure',
              icon: Icons.payments_outlined,
              action: FilledButton(
                onPressed: () {},
                child: const Text('Record expense'),
              ),
            ),
            FinanceFilterSummary(
              count: '12 matching records',
              filters: [
                'Search: ${'VeryLongReference' * 8}',
                'Status: Completed',
              ],
            ),
            const FinanceMonthlyChart(months: months),
          ],
        ),
        width: width,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      if (width == 1440) {
        expect(
          tester.getTopLeft(find.text('Record expense')).dx,
          greaterThan(width / 2),
        );
      } else if (width == 320) {
        expect(
          tester.getTopLeft(find.text('Record expense')).dy,
          greaterThan(tester.getBottomLeft(find.text('Expense register')).dy),
        );
      }
    });
  }

  testWidgets(
    'chart selection keeps zero, missing and negative amounts distinct',
    (tester) async {
      await show(tester, const FinanceMonthlyChart(months: months));
      expect(find.text('1,234.56'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('finance-chart-month-1')));
      await tester.pumpAndSettle();
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('finance-chart-month-2')));
      await tester.pumpAndSettle();
      expect(find.text('-25.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chart month controls are keyboard accessible', (tester) async {
    await show(tester, const FinanceMonthlyChart(months: months));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('February'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('chart describes exact amounts to assistive technology', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await show(tester, const FinanceMonthlyChart(months: months));
    expect(
      find.bySemanticsLabel('January. Collected: 1,234.56. Expenses: 100.00.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('twelve-month chart can scroll to the last month on a phone', (
    tester,
  ) async {
    final all = List.generate(
      12,
      (i) => <String, dynamic>{
        'month': i + 1,
        'label': i == 11 ? 'December' : 'Month ${i + 1}',
        'collectedAmount': '${(i + 1) * 100}.00',
        'expenseAmount': '25.00',
      },
    );
    await show(tester, FinanceMonthlyChart(months: all), width: 390);
    final last = find.byKey(const ValueKey('finance-chart-month-11'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('December'), findsOneWidget);
    expect(find.text('1,200.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart handles empty, zero and very large fixed-point amounts', (
    tester,
  ) async {
    await show(tester, const FinanceMonthlyChart(months: []));
    expect(find.text('Collections and expenses'), findsNothing);
    for (final amount in ['0.00', '999999999999999999999999.99']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanceMonthlyChart(
              months: [
                {
                  'label': 'January',
                  'collectedAmount': amount,
                  'expenseAmount': '0.00',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'sidebar group headings preserve navigation and hide when collapsed',
    (tester) async {
      var selected = -1;
      Widget sidebar(bool collapsed) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: collapsed ? 76 : 260,
            child: WorkspaceSidebar(
              items: const [
                ('Home', Icons.home),
                ('Invoices', Icons.receipt_long),
              ],
              selected: 0,
              onSelect: (value) => selected = value,
              roleLabel: 'Finance',
              collapsed: collapsed,
              groups: const {0: 'Overview', 1: 'Collections'},
            ),
          ),
        ),
      );
      await tester.pumpWidget(sidebar(false));
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('COLLECTIONS'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      expect(selected, 1);
      await tester.pumpWidget(sidebar(true));
      expect(find.text('OVERVIEW'), findsNothing);
      expect(find.text('COLLECTIONS'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
