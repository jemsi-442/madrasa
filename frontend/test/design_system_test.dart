import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/design_theme.dart';
import 'package:mif_app/src/design_tokens.dart';
import 'package:mif_app/src/foundation_ui.dart';
import 'package:mif_app/src/platform_office_dashboard.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';
import 'package:mif_app/src/workspace_chrome.dart';
import 'package:mif_app/src/status_badge.dart';
import 'package:mif_app/src/accountant_components.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/teacher_ui.dart';
import 'package:mif_app/src/shared_feedback.dart';
import 'package:mif_app/src/public_shell.dart';

void main() {
  testWidgets(
    'shared refresh keeps its place and blocks repeat requests while loading',
    (tester) async {
      var calls = 0;
      for (final loading in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkspaceRefreshButton(
                onRefresh: () => calls++,
                loading: loading,
              ),
            ),
          ),
        );
        await tester.pump();
        final button = tester.widget<IconButton>(find.byType(IconButton));
        expect(button.onPressed == null, loading);
        if (!loading) {
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          await tester.tap(find.byTooltip('Refresh page'));
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
      }
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final admin in [true, false]) {
    testWidgets('platform sidebar controls open and close for admin=$admin', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      Widget shell() => MaterialApp(
        theme: buildAfaqTheme(),
        home: PlatformWorkspaceShell(
          isAdmin: admin,
          name: 'Operator',
          page: PlatformPage.home,
          busy: false,
          actions: const [],
          onNavigate: (_) {},
          child: const Text('Workspace content'),
        ),
      );
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(shell());
      expect(
        tester.getSize(find.byType(WorkspaceDesktopSidebar)).width,
        AfaqDesign.sidebarWidth,
      );
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkspaceSidebar>(find.byType(WorkspaceSidebar))
            .collapsed,
        isTrue,
      );
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(
        tester.getSize(find.byType(WorkspaceDesktopSidebar)).width,
        AfaqDesign.sidebarRailWidth,
      );
      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkspaceSidebar>(find.byType(WorkspaceSidebar))
            .collapsed,
        isFalse,
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close navigation'), findsOneWidget);
      await tester.tap(find.byTooltip('Close navigation'));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
        isFalse,
      );
      expect(find.text('Workspace content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all notice wrappers and teacher tags reuse shared widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: Column(
              children: [
                FinanceNotice('Payment information'),
                TeacherNotice('Class information', warning: true),
                FormNotice('Invalid credentials'),
                TeacherTag('Independent'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AfaqNotice), findsNWidgets(3));
    expect(find.byType(AfaqStatusBadge), findsOneWidget);
    final error = tester.widget<AfaqNotice>(
      find.descendant(
        of: find.byType(FormNotice),
        matching: find.byType(AfaqNotice),
      ),
    );
    expect(error.liveRegion, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared action tiles wrap and respect disabled actions', (
    tester,
  ) async {
    var calls = 0;
    for (final enabled in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAfaqTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: AfaqActionTile(
                  title: 'Review company access',
                  subtitle: 'Open authorized actions for this workspace.',
                  icon: Icons.badge_outlined,
                  onTap: enabled ? () => calls++ : null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review company access'));
      expect(calls, enabled ? 1 : 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('record tables inherit the global table theme', (tester) async {
    final theme = buildAfaqTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: RecordTable(
            columns: ['Name'],
            rows: [
              DataRow(cells: [DataCell(Text('Afaq'))]),
            ],
          ),
        ),
      ),
    );
    final table = tester.widget<DataTable>(find.byType(DataTable));
    final inherited = DataTableTheme.of(tester.element(find.byType(DataTable)));
    expect(table.headingRowColor, isNull);
    expect(table.headingRowHeight, isNull);
    expect(inherited.headingRowHeight, AfaqDesign.tableHeadingHeight);
    expect(inherited.headingRowColor!.resolve({}), AfaqDesign.tableHeader);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow record tables scroll to their final action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAfaqTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RecordTable(
              columns: const ['Name', 'Action'],
              rows: [
                DataRow(
                  cells: [
                    const DataCell(Text('Afaq')),
                    DataCell(
                      TextButton(
                        onPressed: () => opened = true,
                        child: const Text('View record'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final scroll = find.descendant(
      of: find.byType(RecordTable),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(scroll, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SingleChildScrollView>(scroll).controller!.offset,
      greaterThan(0),
    );
    await tester.ensureVisible(find.text('View record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View record'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher metrics reuse the common dashboard card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TeacherMetric(
            'Classes',
            '7',
            'Assigned this term',
            Icons.school,
            Colors.blue,
          ),
        ),
      ),
    );
    expect(find.byType(DashboardMetric), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Assigned this term'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance school and platform statuses share one badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FinanceStatus('PAID'),
              StatusPill('ABSENT'),
              PlatformAccountStatus(status: 'DISABLED'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AfaqStatusBadge), findsNWidgets(3));
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared badge wraps long labels with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: AfaqStatusBadge(
                  label: 'Awaiting independent review',
                  color: Colors.blue,
                  icon: Icons.schedule,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Awaiting independent review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'platform uses shared navigation and header with busy protection',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selections = 0;
      for (final busy in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformWorkspaceShell(
              isAdmin: true,
              name: 'Office',
              page: PlatformPage.home,
              busy: busy,
              actions: const [],
              onNavigate: (_) => selections++,
              child: const SizedBox(),
            ),
          ),
        );
        expect(find.byType(WorkspaceSidebar), findsOneWidget);
        expect(find.byType(WorkspaceHeaderSurface), findsOneWidget);
        expect(find.text('System health'), findsNothing);
        await tester.tap(find.text('Company accounts'));
        await tester.pump();
        expect(selections, busy ? 0 : 1);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('legacy palette and admin controls use the shared design system', () {
    expect(ink, AfaqDesign.ink);
    expect(gold, AfaqDesign.gold);
    expect(line, AfaqDesign.border);
    final base = ThemeData();
    expect(
      adminTheme(base).filledButtonTheme.style,
      afaqControlTheme(base).filledButtonTheme.style,
    );
    expect(
      afaqControlTheme(
        base,
      ).filledButtonTheme.style!.backgroundColor!.resolve({}),
      AfaqDesign.actionGold,
    );
  });

  testWidgets('school surface and office panels share decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SurfacePanel(child: Text('School panel'))),
      ),
    );
    final school = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SurfacePanel),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(school.decoration, AfaqDesign.panelDecoration());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformOfficeDashboard(
            name: 'Office',
            snapshot: null,
            busy: false,
            error: null,
            onRefresh: () {},
            onApplications: () {},
            onAccounts: () {},
            onHistory: () {},
          ),
        ),
      ),
    );
    final panels = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((widget) => widget.decoration == AfaqDesign.panelDecoration());
    expect(panels.length, greaterThanOrEqualTo(6));
    expect(tester.takeException(), isNull);
  });
}
