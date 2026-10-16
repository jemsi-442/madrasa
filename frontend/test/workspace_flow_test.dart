import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/accountant_page.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/browser_state.dart';
import 'package:mif_app/src/attendance_register_page.dart';
import 'package:mif_app/src/family_messages_page.dart';
import 'package:mif_app/src/parent_portal_page.dart';
import 'package:mif_app/src/teacher_students_page.dart';
import 'package:mif_app/src/teacher_teaching_pages.dart';
import 'package:mif_app/src/workspace.dart';
import 'package:mif_app/src/workspace_chrome.dart';
import 'package:mif_app/src/workspace_flow.dart';

class MemoryBrowserState extends BrowserState {
  final values = <String, String>{};
  @override
  String? read(String key, {bool shared = false}) => values[key];
  @override
  void write(String key, String? value, {bool shared = false}) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

const roles = ['ADMIN', 'ACCOUNTANT', 'TEACHER', 'PARENT', 'LEARNER'];

Future<AppState> showWorkspace(
  WidgetTester tester,
  String role, {
  bool mobile = false,
  double width = 1440,
  double scale = 1,
  int? restoredSection,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final state =
      AppState(
          MifApiClient(
            browserAuth: false,
            client: MockClient(
              (_) async =>
                  http.Response('{"message":"Test offline state"}', 500),
            ),
          ),
          browserState: MemoryBrowserState(),
        )
        ..session = AuthSession(
          accessToken: 'test',
          refreshToken: 'test',
          userId: '1',
          fullName: 'Test User',
          role: role,
        );
  if (restoredSection != null) {
    state.rememberSection(sectionsForRole(role)[restoredSection].path);
  }
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MifApp(state: state, layout: mobile ? AppLayout.mobile : AppLayout.website),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

int section(WidgetTester tester) =>
    tester.widget<WorkspaceSidebar>(find.byType(WorkspaceSidebar)).selected;

void main() {
  for (final role in roles) {
    test('$role related pages and groups remain inside its allowed menu', () {
      final pages = sectionsForRole(role);
      for (final group in workspaceGroups(role).keys) {
        expect(group, inInclusiveRange(0, pages.length - 1));
      }
      for (var index = 0; index < pages.length; index++) {
        final related = relatedWorkspacePages(role, index);
        expect(related.length, lessThanOrEqualTo(2));
        expect(related.toSet().length, related.length);
        for (final target in related) {
          expect(target, inInclusiveRange(0, pages.length - 1));
          expect(target, isNot(index));
        }
      }
    });

    testWidgets('$role has a visible trail, guarded Back, and Home reset', (
      tester,
    ) async {
      await showWorkspace(tester, role);
      expect(find.byKey(const ValueKey('workspace-trail')), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('nav-1')));
      await tap(tester, find.byKey(const ValueKey('nav-2')));
      expect(section(tester), 2);
      await tap(tester, find.byKey(const ValueKey('workspace-back')));
      expect(section(tester), 1);
      await tap(tester, find.byKey(const ValueKey('workspace-home')));
      expect(section(tester), 0);
      expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
    });
  }

  testWidgets(
    'native Back closes the drawer first, then returns to previous page',
    (tester) async {
      await showWorkspace(tester, 'ACCOUNTANT', mobile: true, width: 390);
      await tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Invoices'),
        ),
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Payments'),
        ),
      );
      await tap(tester, find.byTooltip('Open navigation'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(
        tester
            .widget<AccountantPage>(find.byType(AccountantPage))
            .destination
            .page,
        2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AccountantPage>(find.byType(AccountantPage))
            .destination
            .page,
        1,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AccountantPage>(find.byType(AccountantPage))
            .destination
            .page,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a restored page has Back to Home without stale session history',
    (tester) async {
      await showWorkspace(tester, 'ACCOUNTANT', restoredSection: 2);
      expect(section(tester), 2);
      expect(find.byTooltip('Back to Home'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('workspace-back')));
      expect(section(tester), 0);
      expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
    },
  );

  testWidgets('Back retains the bundled font without external font loading', (
    tester,
  ) async {
    await showWorkspace(tester, 'ACCOUNTANT');
    await tap(tester, find.byKey(const ValueKey('nav-1')));
    final label = find.descendant(
      of: find.byKey(const ValueKey('workspace-back')),
      matching: find.text('Back'),
    );
    expect(
      DefaultTextStyle.of(tester.element(label)).style.fontFamily,
      'Lato',
    );
  });

  testWidgets('reselecting a destination does not duplicate the Back trail', (
    tester,
  ) async {
    await showWorkspace(tester, 'ACCOUNTANT');
    await tap(tester, find.byKey(const ValueKey('nav-1')));
    await tap(tester, find.byKey(const ValueKey('nav-1')));
    await tap(tester, find.byKey(const ValueKey('workspace-back')));
    expect(section(tester), 0);
    expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
  });

  testWidgets('finance Back restores passed filters and invoice scope', (
    tester,
  ) async {
    await showWorkspace(tester, 'ACCOUNTANT');
    AccountantPage page() => tester.widget(find.byType(AccountantPage));
    page().onOpen(const FinanceDestination(1, status: 'OVERDUE'));
    await tester.pumpAndSettle();
    page().onOpen(
      const FinanceDestination(2, invoiceId: '99', invoiceNo: 'INV-99'),
    );
    await tester.pumpAndSettle();
    page().onOpen(const FinanceDestination(3));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('workspace-back')));
    expect(page().destination.invoiceId, '99');
    expect(page().destination.invoiceNo, 'INV-99');
    await tap(tester, find.byKey(const ValueKey('workspace-back')));
    expect(page().destination.status, 'OVERDUE');
    expect(section(tester), 1);
  });

  testWidgets(
    'teacher Back restores the class and learner passed through a flow',
    (tester) async {
      await showWorkspace(tester, 'TEACHER');
      tester
          .widget<TeacherOverviewPage>(find.byType(TeacherOverviewPage))
          .onOpen(
            2,
            classId: 'class-1',
            student: {'id': 'student-1', 'fullName': 'Amina'},
          );
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester
          .widget<TeacherStudentsPage>(find.byType(TeacherStudentsPage))
          .onOpen(4, classId: 'class-1');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AttendanceRegisterPage>(find.byType(AttendanceRegisterPage))
            .initialClassId,
        'class-1',
      );
      await tap(tester, find.byKey(const ValueKey('workspace-back')));
      final students = tester.widget<TeacherStudentsPage>(
        find.byType(TeacherStudentsPage),
      );
      expect(students.initialClassId, 'class-1');
      expect(students.initialStudent?['id'], 'student-1');
    },
  );

  testWidgets(
    'parent Back restores the child context of the previous destination',
    (tester) async {
      await showWorkspace(tester, 'PARENT');
      ParentPortalPage page() => tester.widget(find.byType(ParentPortalPage));
      page().onOpen(2, childId: 'child-1');
      await tester.pumpAndSettle();
      page().onOpen(8, childId: 'child-2');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('workspace-back')));
      expect(page().page, 2);
      expect(page().childId, 'child-1');
    },
  );

  testWidgets(
    'Back and Home respect unsent messages without adding duplicate dialogs',
    (tester) async {
      await showWorkspace(tester, 'PARENT');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('nav-7')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(WorkspaceSidebar),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(tester, find.byKey(const ValueKey('nav-7')));
      final messages = tester.state<FamilyMessagesPageState>(
        find.byType(FamilyMessagesPage),
      );
      messages.composer.text = 'Do not discard this draft';
      final back = tester.widget<TextButton>(
        find.byKey(const ValueKey('workspace-back')),
      );
      back.onPressed!();
      back.onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Leave this message?'), findsOneWidget);
      await tap(tester, find.text('Keep draft'));
      expect(section(tester), 7);
      expect(messages.composer.text, 'Do not discard this draft');
      await tap(tester, find.byKey(const ValueKey('workspace-home')));
      await tap(tester, find.text('Discard draft'));
      expect(section(tester), 0);
      expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
    },
  );

  testWidgets('native Back preserves the current page when a draft is kept', (
    tester,
  ) async {
    await showWorkspace(tester, 'PARENT', mobile: true, width: 390);
    tester.widget<ParentPortalPage>(find.byType(ParentPortalPage)).onOpen(7);
    await tester.pumpAndSettle();
    final messages = tester.state<FamilyMessagesPageState>(
      find.byType(FamilyMessagesPage),
    );
    messages.composer.text = 'Keep my message';
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this message?'), findsOneWidget);
    await tap(tester, find.text('Keep draft'));
    expect(messages.composer.text, 'Keep my message');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Discard draft'));
    expect(find.byType(FamilyMessagesPage), findsNothing);
    expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
  });

  for (final mobile in [false, true]) {
    for (final role in roles) {
      testWidgets(
        '$role uses direct navigation without page search, mobile=$mobile',
        (tester) async {
          await showWorkspace(
            tester,
            role,
            mobile: mobile,
            width: mobile ? 390 : 1440,
          );
          expect(find.textContaining('Find a page'), findsNothing);
          expect(find.byTooltip('Find a page'), findsNothing);
          if (mobile) {
            await tap(tester, find.byTooltip('Open navigation'));
            await tap(tester, find.byTooltip('Close navigation'));
            expect(find.byType(Drawer), findsNothing);
            await tap(tester, find.byTooltip('Open navigation'));
          }
          final sidebar = tester.widget<WorkspaceSidebar>(
            find.byType(WorkspaceSidebar),
          );
          expect(
            sidebar.items.map((item) => item.$1),
            sectionsForRole(role).map((page) => page.title),
          );
          expect(
            find.descendant(
              of: find.byType(WorkspaceSidebar),
              matching: find.byIcon(Icons.search),
            ),
            findsNothing,
          );
          expect(find.byTooltip('Find a page'), findsNothing);
          await tap(tester, find.byKey(const ValueKey('nav-1')));
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byKey(const ValueKey('workspace-back')), findsOneWidget);
          final title = sectionsForRole(role)[1].title;
          if (mobile) {
            expect(find.byType(Drawer), findsNothing);
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.text(title),
              ),
              findsOneWidget,
            );
          } else {
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const ValueKey('workspace-page-label')),
                  )
                  .data,
              title,
            );
          }
          await tap(tester, find.byKey(const ValueKey('workspace-back')));
          expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('related pages navigate to real destinations', (tester) async {
    await showWorkspace(tester, 'ACCOUNTANT');
    await tap(tester, find.byKey(const ValueKey('nav-1')));
    await tap(tester, find.byKey(const ValueKey('next-page-2')));
    expect(section(tester), 2);
    await tap(tester, find.byKey(const ValueKey('workspace-back')));
    expect(section(tester), 1);
  });

  testWidgets(
    'small phone trail and drawer support large text without page search',
    (tester) async {
      await showWorkspace(
        tester,
        'ACCOUNTANT',
        mobile: true,
        width: 320,
        scale: 2,
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Invoices'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Find a page'), findsNothing);
      await tap(tester, find.byTooltip('Open navigation'));
      expect(tester.takeException(), isNull);
    },
  );
}
