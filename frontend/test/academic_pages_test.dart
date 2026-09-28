import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/attendance_page.dart';
import 'package:mif_app/src/classes_page.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/student_registry_page.dart';
import 'package:mif_app/src/workspace.dart';

const schoolClasses = [
  {
    'id': '2',
    'name': 'Noor One',
    'level': 'Primary',
    'academicYear': '2026',
    'teacherId': '7',
    'teacher': {'fullName': 'Salma Hassan', 'phone': '255700000001'},
    'branch': {'name': 'Main Campus'},
    'stats': {'currentStudents': 12},
  },
  {
    'id': '3',
    'name': 'Noor Two',
    'level': 'Secondary',
    'academicYear': '2026',
    'teacherId': '8',
    'teacher': {'fullName': 'Omar Ali'},
    'branch': {'name': 'Main Campus'},
    'stats': {'currentStudents': 8},
  },
];

const student = {
  'id': '1',
  'fullName': 'Ali Hassan',
  'admissionNo': 'MIF-001',
  'status': 'ACTIVE',
  'gender': 'male',
  'dob': '2016-01-12',
  'currentClass': {'name': 'Noor One'},
  'branch': {'name': 'Main Campus'},
  'primaryGuardian': {'fullName': 'Amina Hassan', 'phone': '255700000002'},
};

Future<void> showPage(
  WidgetTester tester,
  Widget page, {
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [page]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('student search uses server filters and resets pagination', (
    tester,
  ) async {
    final requests = <Uri>[];
    Future<dynamic> load(String path) async {
      final uri = Uri.parse(path);
      requests.add(uri);
      if (uri.path == '/api/classes') return schoolClasses;
      return {
        'items': uri.queryParameters.containsKey('search') ? [] : [student],
        'meta': {'totalItems': 11, 'totalPages': 2},
      };
    }

    await showPage(tester, StudentRegistryPage(load: load));
    expect(find.text('Student directory'), findsOneWidget);
    expect(find.byType(RecordTable), findsOneWidget);
    final next = find.byTooltip('Next page');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      requests
          .where((u) => u.path == '/api/students')
          .last
          .queryParameters['page'],
      '2',
    );
    final search = find.byKey(const ValueKey('student-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Fatma & Ali');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final query = requests
        .where((u) => u.path == '/api/students')
        .last
        .queryParameters;
    expect(query['search'], 'Fatma & Ali');
    expect(query['page'], '1');
    expect(query['pageSize'], '10');
    expect(find.text('No students match these filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student status and class filters are scoped server requests', (
    tester,
  ) async {
    final requests = <Uri>[];
    Future<dynamic> load(String path) async {
      final uri = Uri.parse(path);
      requests.add(uri);
      return uri.path == '/api/classes'
          ? schoolClasses
          : {
              'items': [student],
              'meta': {'totalItems': 1, 'totalPages': 1},
            };
    }

    await showPage(tester, StudentRegistryPage(load: load));
    await tester.tap(find.text('All statuses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspended').last);
    await tester.pumpAndSettle();
    final picker = find.text('All classes');
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noor Two').last);
    await tester.pumpAndSettle();
    final query = requests
        .where((u) => u.path == '/api/students')
        .last
        .queryParameters;
    expect(query['status'], 'SUSPENDED');
    expect(query['classId'], '3');
    expect(query['page'], '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('student record opens real details', (tester) async {
    Future<dynamic> load(String path) async => path == '/api/classes'
        ? schoolClasses
        : {
            'items': [student],
            'meta': {'totalItems': 1, 'totalPages': 1},
          };
    await showPage(tester, StudentRegistryPage(load: load));
    final open = find.byTooltip('View Ali Hassan');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('255700000002'), findsOneWidget);
    expect(find.text('2016-01-12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('class search filters the directory without inventing progress', (
    tester,
  ) async {
    await showPage(tester, ClassesPage(load: (_) async => schoolClasses));
    expect(find.byType(ColumnChart), findsOneWidget);
    expect(find.byType(RingChart), findsOneWidget);
    final search = find.byKey(const ValueKey('class-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Salma');
    await tester.pumpAndSettle();
    expect(find.text('Noor One'), findsOneWidget);
    expect(find.text('Noor Two'), findsNothing);
    expect(find.text('1 of 2 classes'), findsOneWidget);
    expect(find.text('92%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance period and class changes fetch new summaries', (
    tester,
  ) async {
    final requests = <Uri>[];
    Future<dynamic> load(String path) async {
      final uri = Uri.parse(path);
      requests.add(uri);
      if (uri.path == '/api/classes') return schoolClasses;
      return {
        'filters': uri.queryParameters,
        'totals': {
          'totalRecords': 10,
          'present': 8,
          'absent': 1,
          'late': 1,
          'excused': 0,
          'attendanceRate': '80.00',
        },
        'timeline': [
          {
            'date': '2026-09-25',
            'totalRecords': 10,
            'present': 8,
            'absent': 1,
            'late': 1,
            'excused': 0,
          },
        ],
      };
    }

    await showPage(tester, AttendancePage(load: load));
    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 days').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All classes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noor One').last);
    await tester.pumpAndSettle();
    final query = requests
        .where((u) => u.path.contains('/reports/'))
        .last
        .queryParameters;
    expect(query['classId'], '2');
    expect(
      DateTime.parse(
        query['dateTo']!,
      ).difference(DateTime.parse(query['dateFrom']!)).inDays,
      29,
    );
    expect(find.text('80.00%'), findsOneWidget);
    expect(find.text('Take Attendance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('academic pages render without overflow at $width', (
      tester,
    ) async {
      Future<dynamic> load(String path) async {
        if (path == '/api/classes') return schoolClasses;
        if (path.contains('/students')) {
          return {
            'items': [student],
            'meta': {'totalItems': 1, 'totalPages': 1},
          };
        }
        return {
          'totals': {'totalRecords': 0},
          'timeline': [],
          'filters': {'dateFrom': '2026-09-19', 'dateTo': '2026-09-25'},
        };
      }

      for (final page in [
        StudentRegistryPage(load: load),
        ClassesPage(load: load),
        AttendancePage(load: load),
      ]) {
        await showPage(tester, page, width: width);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('failed load shows retry and recovers', (tester) async {
    var attempts = 0;
    await showPage(
      tester,
      ClassesPage(
        load: (_) async {
          if (attempts++ == 0) throw Exception('Internal database details');
          return [];
        },
      ),
    );
    expect(find.textContaining('Internal database'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('navigation keeps administrative records out of other roles', () {
    for (final role in ['ACCOUNTANT', 'TEACHER', 'PARENT', 'LEARNER']) {
      expect(
        sectionsForRole(role).map((s) => s.title),
        isNot(contains('Students')),
      );
      expect(
        sectionsForRole(role).map((s) => s.title),
        ['TEACHER', 'PARENT', 'LEARNER'].contains(role)
            ? contains('Attendance')
            : isNot(contains('Attendance')),
      );
    }
    expect(
      sectionsForRole(
        'LEARNER',
      ).firstWhere((s) => s.title == 'Attendance').path,
      '/api/learner/workspace/attendance',
    );
    expect(
      sectionsForRole('LEARNER').any(
        (s) => s.path.startsWith('/api/admin') || s.path == '/api/attendance',
      ),
      isFalse,
    );
    expect(
      sectionsForRole('PARENT').firstWhere((s) => s.title == 'Attendance').path,
      '/family/attendance',
    );
    expect(
      sectionsForRole('PARENT').any(
        (s) =>
            s.path.startsWith('/api/reports/') ||
            s.path.startsWith('/api/attendance/'),
      ),
      isFalse,
    );
    expect(sectionsForRole('ADMIN').first.title, 'Overview');
  });
}
