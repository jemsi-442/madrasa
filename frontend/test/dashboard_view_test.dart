import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/dashboard_views.dart';
import 'package:mif_app/src/foundation_ui.dart';
import 'package:mif_app/src/workspace.dart';

void main() {
  test('accountant record pages do not reuse home totals', () {
    expect(metricsFor('ACCOUNTANT', 'Invoices', {'items': []}), isEmpty);
    expect(metricsFor('ACCOUNTANT', 'Payments', {'items': []}), isEmpty);
  });

  const adminReport = {
    'students': {
      'total': 37,
      'active': 32,
      'inactive': 3,
      'suspended': 1,
      'graduated': 1,
    },
    'attendance': {
      'totalRecords': 25,
      'present': 20,
      'absent': 3,
      'late': 1,
      'excused': 1,
      'attendanceRate': '80.00',
    },
    'hifdh': {'totalAssessments': 9},
    'finance': {
      'invoices': {'outstandingBalance': '125000.00'},
    },
  };

  testWidgets('admin home uses report values and opens a real page', (
    tester,
  ) async {
    var opened = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardView(
              role: 'ADMIN',
              data: adminReport,
              onOpenSection: (index) => opened = index,
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(DashboardMetric),
        matching: find.text('37'),
      ),
      findsOneWidget,
    );
    expect(find.text('80.00%'), findsOneWidget);
    expect(find.text('Student admissions'), findsOneWidget);
    await tester.ensureVisible(find.text('Classes').last);
    await tester.tap(find.text('Classes').last);
    expect(opened, 2);
  });

  testWidgets('mobile workspace has bottom navigation and more pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      final data = request.url.path == '/api/admin/overview'
          ? adminReport
          : <dynamic>[];
      return http.Response(jsonEncode({'success': true, 'data': data}), 200);
    });
    final state = AppState(
      MifApiClient(client: client, baseUrl: 'https://school.test'),
    );
    state.session = const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: '1',
      fullName: 'Office Admin',
      role: 'ADMIN',
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(MifApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DashboardMetric), findsNWidgets(6));
    expect(
      tester.getSize(find.byType(DashboardMetric).first).width,
      lessThan(190),
    );
    expect(find.text('More'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Course access'), findsOneWidget);
  });

  testWidgets(
    'desktop sidebar stays fixed, collapses, and searches real pages',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      final state = AppState(
        MifApiClient(
          baseUrl: 'https://school.test',
          client: MockClient((request) async {
            requests.add(request.url.path);
            final data = request.url.path == '/api/admin/overview'
                ? adminReport
                : <dynamic>[];
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
            );
          }),
        ),
      );
      state.session = const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        userId: '1',
        fullName: 'Office Admin',
        role: 'ADMIN',
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(MifApp(state: state));
      await tester.pumpAndSettle();
      final nav = find.byKey(const ValueKey('nav-0'));
      final before = tester.getTopLeft(nav);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(nav), before);
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find a page...'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Attendance');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ListTile, 'Attendance'),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, contains('/api/reports/attendance/summary'));
      expect(find.text('Daily register'), findsOneWidget);
      expect(find.text('Student admissions'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
