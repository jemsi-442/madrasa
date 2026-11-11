import 'dart:convert';

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
import 'package:mif_app/src/assessments_page.dart';
import 'package:mif_app/src/student_reports_page.dart';
import 'package:mif_app/src/school_curriculum_page.dart';
import 'package:mif_app/src/family_messages_page.dart';
import 'package:mif_app/src/parent_portal_page.dart';
import 'package:mif_app/src/teacher_students_page.dart';
import 'package:mif_app/src/teacher_quran_page.dart';
import 'package:mif_app/src/teacher_courses_page.dart';
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
  Future<http.Response> Function(http.Request)? respond,
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
              respond ??
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
  for (final role in ['ADMIN', 'TEACHER']) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('curriculum opens inside $role workspace at $width', (
        tester,
      ) async {
        final index = sectionsForRole(
          role,
        ).indexWhere((section) => section.path == '/api/school-curriculum');
        var reads = 0;
        await showWorkspace(
          tester,
          role,
          width: width,
          restoredSection: index,
          respond: (request) async {
            if (request.url.path == '/api/school-curriculum') {
              reads++;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'assignments': [], 'classes': [], 'subjects': []},
                }),
                200,
              );
            }
            return http.Response('{}', 500);
          },
        );
        expect(find.byType(SchoolCurriculumPage), findsOneWidget);
        expect(
          find.textContaining(
            role == 'ADMIN'
                ? 'No published curriculum has been assigned'
                : 'No curriculum has been adopted',
          ),
          findsOneWidget,
        );
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'course record actions retain class and return location at $width',
      (tester) async {
        await showWorkspace(tester, 'TEACHER', width: width);
        tester
            .widget<TeacherOverviewPage>(find.byType(TeacherOverviewPage))
            .onOpen(5, classId: 'class-1');
        await tester.pumpAndSettle();
        final location = TeacherCourseLocation(
          course: {'id': 'c'},
          module: {'id': 'm'},
          lessonId: 'l',
        );
        for (final target in TeacherLearningDestination.values) {
          tester
              .widget<TeacherCoursesPage>(find.byType(TeacherCoursesPage))
              .onRecordLearning!(location, target);
          await tester.pumpAndSettle();
          if (target == TeacherLearningDestination.quran) {
            expect(
              tester
                  .widget<TeacherQuranPage>(find.byType(TeacherQuranPage))
                  .initialClassId,
              'class-1',
            );
          } else {
            expect(
              tester
                  .widget<AssessmentsPage>(find.byType(AssessmentsPage))
                  .initialClassId,
              'class-1',
            );
          }
          await tap(tester, find.byKey(const ValueKey('workspace-back')));
          expect(
            tester
                .widget<TeacherCoursesPage>(find.byType(TeacherCoursesPage))
                .initialLocation,
            same(location),
          );
        }
      },
    );

    testWidgets(
      'teacher record journey preserves class and clears stale learner at $width',
      (tester) async {
        await showWorkspace(tester, 'TEACHER', width: width);
        tester
            .widget<TeacherOverviewPage>(find.byType(TeacherOverviewPage))
            .onOpen(4, classId: 'class-1');
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('next-page-3')));
        final quran = tester.widget<TeacherQuranPage>(
          find.byType(TeacherQuranPage),
        );
        expect(quran.initialClassId, 'class-1');
        quran.onContextChanged!('class-1', {
          'id': 'synthetic-learner-1',
          'fullName': 'Demo Learner',
        });
        await tap(tester, find.byKey(const ValueKey('next-page-8')));
        final assessments = tester.widget<AssessmentsPage>(
          find.byType(AssessmentsPage),
        );
        expect(assessments.initialClassId, 'class-1');
        expect(assessments.admin, isFalse);
        assessments.onClassChanged!('class-2');
        await tap(tester, find.byKey(const ValueKey('next-page-9')));
        final reports = tester.widget<StudentReportsPage>(
          find.byType(StudentReportsPage),
        );
        expect(reports.initialClassId, 'class-2');
        expect(reports.admin, isFalse);
        await tap(tester, find.byKey(const ValueKey('workspace-back')));
        expect(
          tester
              .widget<AssessmentsPage>(find.byType(AssessmentsPage))
              .initialClassId,
          'class-2',
        );
        await tap(tester, find.byKey(const ValueKey('workspace-back')));
        final restored = tester.widget<TeacherQuranPage>(
          find.byType(TeacherQuranPage),
        );
        expect(restored.initialClassId, 'class-1');
        expect(restored.initialStudent?['id'], 'synthetic-learner-1');
        restored.onContextChanged!('class-2', null);
        await tap(tester, find.byKey(const ValueKey('next-page-8')));
        await tap(tester, find.byKey(const ValueKey('workspace-back')));
        final cleared = tester.widget<TeacherQuranPage>(
          find.byType(TeacherQuranPage),
        );
        expect(cleared.initialClassId, 'class-2');
        expect(cleared.initialStudent, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('teacher next steps do not send tasks into circular navigation', () {
    void visit(int page, Set<int> trail) {
      expect(trail, isNot(contains(page)), reason: 'Circular teaching flow');
      for (final next in relatedWorkspacePages('TEACHER', page)) {
        visit(next, {...trail, page});
      }
    }

    for (var page = 0; page < sectionsForRole('TEACHER').length; page++) {
      visit(page, {});
    }
    expect(relatedWorkspacePages('TEACHER', 3), [8, 9]);
    expect(relatedWorkspacePages('TEACHER', 7), isEmpty);
    expect(relatedWorkspacePages('TEACHER', 5), isEmpty);
    final order = workspacePageOrder('TEACHER')!;
    expect(order.toSet().length, sectionsForRole('TEACHER').length);
    for (final page in order) {
      for (final next in relatedWorkspacePages('TEACHER', page)) {
        expect(order.indexOf(next), greaterThan(order.indexOf(page)));
      }
    }
  });

  testWidgets('teacher menu follows teaching order without changing page IDs', (
    tester,
  ) async {
    await showWorkspace(tester, 'TEACHER');
    tester.view.physicalSize = const Size(1440, 1800);
    await tester.pumpAndSettle();
    final sidebar = tester.widget<WorkspaceSidebar>(
      find.byType(WorkspaceSidebar),
    );
    expect(sidebar.pageOrder, [0, 1, 2, 10, 5, 4, 3, 8, 9, 6, 7]);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('nav-5'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('nav-3'))).dy),
    );
    await tap(tester, find.byKey(const ValueKey('nav-5')));
    expect(section(tester), 5);
    expect(find.byKey(const ValueKey('workspace-next-steps')), findsNothing);
  });
  for (final role in roles) {
    test('$role related pages remain inside its allowed menu', () {
      final pages = sectionsForRole(role);
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
      expect(find.text('MY TEACHING WORKSPACE'), findsNothing);
      expect(find.text('MY FINANCE WORKSPACE'), findsNothing);
      expect(find.text(sectionsForRole(role).first.purpose), findsNothing);
      expect(find.byKey(const ValueKey('workspace-trail')), findsOneWidget);
      final sidebar = find.byType(WorkspaceSidebar);
      for (final label in [
        'OVERVIEW',
        'MY LEARNERS',
        'LESSON PLANNING',
        'COLLECTIONS',
        'SCHOOL MANAGEMENT',
        'RESULTS',
      ]) {
        expect(
          find.descendant(of: sidebar, matching: find.text(label)),
          findsNothing,
        );
      }
      expect(find.byKey(const ValueKey('workspace-back')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('nav-1')));
      await tap(tester, find.byKey(const ValueKey('nav-2')));
      expect(section(tester), 2);
      expect(find.text(sectionsForRole(role)[2].purpose), findsNothing);
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
    expect(DefaultTextStyle.of(tester.element(label)).style.fontFamily, 'Lato');
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
      expect(students.openInitialProfile, isFalse);
      expect(find.byType(TeacherStudentProfile), findsNothing);
    },
  );

  testWidgets('attendance continues to Quran and Back with the latest class', (
    tester,
  ) async {
    await showWorkspace(tester, 'TEACHER');
    tester
        .widget<TeacherOverviewPage>(find.byType(TeacherOverviewPage))
        .onOpen(4, classId: 'class-1');
    await tester.pumpAndSettle();
    tester
        .widget<AttendanceRegisterPage>(find.byType(AttendanceRegisterPage))
        .onClassChanged!('class-2');
    await tap(tester, find.byKey(const ValueKey('next-page-3')));
    expect(
      tester
          .widget<TeacherQuranPage>(find.byType(TeacherQuranPage))
          .initialClassId,
      'class-2',
    );
    await tap(tester, find.byKey(const ValueKey('workspace-back')));
    expect(
      tester
          .widget<AttendanceRegisterPage>(find.byType(AttendanceRegisterPage))
          .initialClassId,
      'class-2',
    );
    expect(tester.takeException(), isNull);
  });

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
