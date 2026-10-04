import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/app.dart';
import 'package:mif_app/src/app_layout.dart';
import 'package:mif_app/src/app_state.dart';
import 'package:mif_app/src/assessments_page.dart';
import 'package:mif_app/src/attendance_register_page.dart';
import 'package:mif_app/src/browser_state.dart';
import 'package:mif_app/src/learning_record_links.dart';
import 'package:mif_app/src/student_reports_page.dart';
import 'package:mif_app/src/teacher_quran_page.dart';
import 'package:mif_app/src/workspace_chrome.dart';

class MemoryPreferences extends BrowserState {
  @override
  String? read(String key, {bool shared = false}) => null;
  @override
  void write(String key, String? value, {bool shared = false}) {}
}

class RecordsFixture {
  final reads = <Uri>[];
  final writes = <(String, Map<String, dynamic>)>[];
  final opened = <(LearningRecordPage, String)>[];
  final changed = <String>[];
  bool hasSubjects = true, hasPeriods = true;
  Map<String, dynamic>? createdAssessment;
  final classes = [
    for (final (id, name) in [('8', 'Level 1A'), ('9', 'Level 1B')])
      {
        'id': id,
        'name': name,
        'level': 'Primary',
        'academicYear': '2026',
        '_count': {'currentStudents': 0},
        'timetable': <dynamic>[],
        'branch': {'name': 'Main'},
      },
  ];

  Future<dynamic> load(String path) async {
    final uri = Uri.parse(path);
    reads.add(uri);
    if (uri.path == '/api/assessments/501') return createdAssessment!;
    if (uri.path.endsWith('/options')) {
      return {
        'classes': classes,
        'subjects': [
          if (hasSubjects) {'id': '3', 'name': 'Fiqh'},
        ],
        'periods': [
          if (hasPeriods) {'id': '20', 'name': 'September 2026'},
        ],
      };
    }
    if (uri.path.endsWith('/classes')) return classes;
    if (uri.path.endsWith('/roster')) {
      return [
        {'id': '1', 'fullName': 'Amina Hassan', 'admissionNo': 'MIF001'},
      ];
    }
    if (uri.path.endsWith('/catalog')) {
      return {
        'chapters': [
          {'id': 67, 'name': 'Al-Mulk', 'ayahCount': 30},
        ],
        'juzs': [
          {
            'number': 29,
            'ranges': [
              {'surahId': 67, 'from': 1, 'to': 30},
            ],
          },
        ],
      };
    }
    if (uri.path == '/api/attendance/register') {
      return {
        'class': classes.firstWhere(
          (c) => c['id'] == uri.queryParameters['classId'],
        ),
        'date': uri.queryParameters['date'],
        'today': attendanceDay(schoolToday()),
        'items': <dynamic>[],
        'summary': {
          'total': 0,
          'present': 0,
          'absent': 0,
          'late': 0,
          'excused': 0,
          'unmarked': 0,
        },
      };
    }
    return {
      'items': <dynamic>[],
      'meta': {'totalItems': 0},
      'stats': <dynamic>[],
    };
  }

  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add((path, body));
    if (path == '/api/assessments') {
      return createdAssessment = {
        ...body,
        'id': '501',
        'status': 'DRAFT',
        'revision': 1,
        'class': classes.firstWhere((c) => c['id'] == body['classId']),
        'subject': {'id': '3', 'name': 'Fiqh'},
        'results': <dynamic>[],
      };
    }
    return <String, dynamic>{};
  }

  void open(LearningRecordPage page, String id) => opened.add((page, id));
  List<Uri> listReads(String page) =>
      reads.where((u) => u.path == '/api/$page').toList();
}

void viewport(WidgetTester t, {double width = 1200, double scale = 1}) {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget recordPage(
  RecordsFixture f,
  bool reports, {
  String? classId = '8',
  bool admin = false,
}) => reports
    ? StudentReportsPage(
        load: f.load,
        submit: f.submit,
        admin: admin,
        initialClassId: classId,
        onClassChanged: f.changed.add,
        onOpenRecord: f.open,
      )
    : AssessmentsPage(
        load: f.load,
        submit: f.submit,
        admin: admin,
        initialClassId: classId,
        onClassChanged: f.changed.add,
        onOpenRecord: f.open,
      );

Widget host(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansDisplay'),
  home: Scaffold(
    body: SingleChildScrollView(
      primary: true,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

Finder filled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> nav(WidgetTester t, int index) async {
  final target = find.byKey(ValueKey('nav-$index'));
  await t.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(WorkspaceSidebar),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tap(t, target);
}

Future<void> workspace(WidgetTester t, RecordsFixture f, String role) async {
  viewport(t, width: 1440);
  final state =
      AppState(
          MifApiClient(
            browserAuth: false,
            client: MockClient(
              (r) async => http.Response(
                jsonEncode({
                  'data': r.method == 'GET'
                      ? await f.load(r.url.toString())
                      : await f.submit(
                          r.url.path,
                          Map<String, dynamic>.from(jsonDecode(r.body) as Map),
                        ),
                }),
                200,
              ),
            ),
          ),
          browserState: MemoryPreferences(),
        )
        ..session = AuthSession(
          accessToken: 'test',
          refreshToken: 'test',
          userId: '1',
          fullName: 'Test User',
          role: role,
        );
  addTearDown(state.dispose);
  await t.pumpWidget(MifApp(state: state, layout: AppLayout.website));
  await t.pumpAndSettle();
}

void main() {
  for (final reports in [false, true]) {
    final path = reports ? 'student-reports' : 'assessments';
    testWidgets('$path carries class into API reads and related record links', (
      t,
    ) async {
      viewport(t);
      final f = RecordsFixture();
      await t.pumpWidget(host(recordPage(f, reports)));
      await t.pumpAndSettle();
      expect(f.listReads(path).last.queryParameters['classId'], '8');
      expect(find.text('Working with Level 1A'), findsOneWidget);
      final target = reports
          ? LearningRecordPage.assessments
          : LearningRecordPage.reports;
      await tap(t, find.byKey(ValueKey('learning-link-${target.name}')));
      expect(f.opened.single, (target, '8'));
      expect(f.writes, isEmpty);
    });

    testWidgets(
      '$path rejects unavailable class without querying or silently widening scope',
      (t) async {
        viewport(t);
        final f = RecordsFixture();
        await t.pumpWidget(host(recordPage(f, reports, classId: '999')));
        await t.pumpAndSettle();
        expect(find.byType(UnavailableLearningClass), findsOneWidget);
        expect(f.listReads(path), isEmpty);
        await tap(t, find.text('Show available classes'));
        expect(
          f.listReads(path).last.queryParameters.containsKey('classId'),
          isFalse,
        );
        expect(f.changed.single, '');
        expect(f.writes, isEmpty);
      },
    );

    testWidgets(
      '$path responds to a new incoming class without stale dropdown state',
      (t) async {
        viewport(t);
        final f = RecordsFixture();
        await t.pumpWidget(host(recordPage(f, reports)));
        await t.pumpAndSettle();
        await t.pumpWidget(host(recordPage(f, reports, classId: '9')));
        await t.pumpAndSettle();
        expect(f.listReads(path).last.queryParameters['classId'], '9');
        expect(find.text('Working with Level 1B'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$path connected record actions fit 320px at text scale $scale',
        (t) async {
          viewport(t, width: 320, scale: scale);
          final f = RecordsFixture();
          await t.pumpWidget(host(recordPage(f, reports)));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await tap(t, find.byKey(const ValueKey('learning-link-attendance')));
          expect(f.opened.single, (LearningRecordPage.attendance, '8'));
        },
      );
    }
  }

  testWidgets(
    'new assessment preselects the current class without creating records',
    (t) async {
      viewport(t);
      final f = RecordsFixture();
      await t.pumpWidget(host(recordPage(f, false)));
      await t.pumpAndSettle();
      await tap(t, find.text('New assessment'));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      expect(t.state<FormFieldState<String>>(fields.first).value, '8');
      expect(t.state<FormFieldState<String>>(fields.last).value, isNull);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'report preparation preselects class and period then loads that class roster',
    (t) async {
      viewport(t);
      final f = RecordsFixture();
      await t.pumpWidget(host(recordPage(f, true)));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('Periods-')));
      await tap(t, find.text('September 2026').last);
      await tap(t, find.text('Prepare report'));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      expect(t.state<FormFieldState<String>>(fields.first).value, '8');
      expect(t.state<FormFieldState<String>>(fields.last).value, '20');
      await tap(t, find.text('Choose learner'));
      expect(f.reads.last.path, '/api/student-reports/roster');
      expect(f.reads.last.queryParameters['classId'], '8');
      expect(find.text('Select learner'), findsOneWidget);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'missing setup disables teacher creation but not administrator period setup',
    (t) async {
      viewport(t);
      final f = RecordsFixture()
        ..hasPeriods = false
        ..hasSubjects = false;
      await t.pumpWidget(host(recordPage(f, false)));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(filled('New assessment')).onPressed,
        isNull,
      );
      await t.pumpWidget(host(recordPage(f, true)));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(filled('Prepare report')).onPressed,
        isNull,
      );
      expect(find.textContaining('No reporting periods yet'), findsOneWidget);
      await t.pumpWidget(host(recordPage(f, true, admin: true)));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(filled('New reporting period')).onPressed,
        isNotNull,
      );
      expect(find.byKey(const ValueKey('learning-link-quran')), findsNothing);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'saving a new assessment follows the form class and clears a published-only filter',
    (t) async {
      viewport(t);
      final f = RecordsFixture();
      await t.pumpWidget(host(recordPage(f, false)));
      await t.pumpAndSettle();
      final filters = find.byType(DropdownButtonFormField<String>);
      await tap(t, filters.last);
      await tap(t, find.text('Published').last);
      await tap(t, find.text('New assessment'));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tap(t, fields.first);
      await tap(t, find.text('Level 1B').last);
      await tap(t, fields.last);
      await tap(t, find.text('Fiqh').last);
      await t.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Assessment title',
        ),
        'Class practice',
      );
      await tap(t, find.text('Save'));
      expect(f.writes.single.$1, '/api/assessments');
      expect(f.writes.single.$2['classId'], '9');
      expect(f.createdAssessment?['status'], 'DRAFT');
      expect(f.changed.last, '9');
      await tap(t, find.byTooltip('Close assessment'));
      final request = f.listReads('assessments').last;
      expect(request.queryParameters['classId'], '9');
      expect(request.queryParameters.containsKey('status'), isFalse);
    },
  );

  for (final reports in [false, true]) {
    testWidgets(
      'unassigned teacher cannot start a new ${reports ? 'report' : 'assessment'}',
      (t) async {
        viewport(t);
        final f = RecordsFixture()..classes.clear();
        await t.pumpWidget(host(recordPage(f, reports, classId: null)));
        await t.pumpAndSettle();
        final action = reports ? 'Prepare report' : 'New assessment';
        expect(t.widget<FilledButton>(filled(action)).onPressed, isNull);
        expect(find.byType(LearningRecordLinks), findsNothing);
        expect(f.writes, isEmpty);
      },
    );
  }

  testWidgets(
    'teacher class to assessments to reports to attendance preserves latest class and Back context',
    (t) async {
      final f = RecordsFixture();
      await workspace(t, f, 'TEACHER');
      await nav(t, 1);
      await tap(t, find.byKey(const ValueKey('class-8-record-8')));
      expect(f.listReads('assessments').last.queryParameters['classId'], '8');
      await tap(t, find.byKey(const ValueKey('assessment-class-8')));
      await tap(t, find.text('Level 1B').last);
      await tap(t, find.byKey(const ValueKey('learning-link-reports')));
      expect(
        f.listReads('student-reports').last.queryParameters['classId'],
        '9',
      );
      await tap(t, find.byKey(const ValueKey('learning-link-attendance')));
      expect(
        t
            .widget<AttendanceRegisterPage>(find.byType(AttendanceRegisterPage))
            .initialClassId,
        '9',
      );
      await tap(t, find.byKey(const ValueKey('register-class-9')));
      await tap(t, find.text('Level 1A - 2026').last);
      await nav(t, 9);
      expect(
        f.listReads('student-reports').last.queryParameters['classId'],
        '8',
      );
      await tap(t, find.byKey(const ValueKey('workspace-back')));
      expect(
        t
            .widget<AttendanceRegisterPage>(find.byType(AttendanceRegisterPage))
            .initialClassId,
        '8',
      );
      await tap(t, find.byKey(const ValueKey('workspace-back')));
      expect(
        f.listReads('student-reports').last.queryParameters['classId'],
        '9',
      );
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'admin connects class review, reports and attendance without teacher-only actions',
    (t) async {
      final f = RecordsFixture();
      await workspace(t, f, 'ADMIN');
      await nav(t, 10);
      await tap(t, find.byKey(const ValueKey('assessment-class-')));
      await tap(t, find.text('Level 1A').last);
      await tap(t, find.byKey(const ValueKey('learning-link-reports')));
      expect(
        f.listReads('student-reports').last.queryParameters['classId'],
        '8',
      );
      expect(find.text('Prepare report'), findsNothing);
      expect(find.byKey(const ValueKey('learning-link-quran')), findsNothing);
      await tap(t, find.byKey(const ValueKey('learning-link-attendance')));
      final attendance = t.widget<AttendanceRegisterPage>(
        find.byType(AttendanceRegisterPage),
      );
      expect(attendance.initialClassId, '8');
      expect(attendance.teacherMode, isFalse);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'Quran class changes update shared context only after draft confirmation',
    (t) async {
      viewport(t);
      final f = RecordsFixture();
      await t.pumpWidget(
        host(
          TeacherQuranPage(
            load: f.load,
            submit: f.submit,
            teacherId: '1',
            initialClassId: '8',
            onContextChanged: (id, student) => f.changed.add(id),
          ),
        ),
      );
      await t.pumpAndSettle();
      final state = t.state<TeacherQuranPageState>(
        find.byType(TeacherQuranPage),
      );
      state.note.text = 'Unsent observation';
      state.changeClass('9');
      await t.pumpAndSettle();
      await tap(t, find.text('Stay here'));
      expect(f.changed, isEmpty);
      expect(state.classId, '8');
      state.changeClass('9');
      await t.pumpAndSettle();
      await tap(t, find.text('Leave session'));
      expect(f.changed.single, '9');
      expect(state.student, isNull);
      expect(f.writes, isEmpty);
    },
  );
}
