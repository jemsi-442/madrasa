import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/attendance_register_page.dart';
import 'package:mif_app/src/teacher_teaching_pages.dart';
import 'package:mif_app/src/teacher_students_page.dart';
import 'package:mif_app/src/teacher_quran_page.dart';
import 'package:mif_app/src/workspace.dart';

final learner = <String, dynamic>{
  'id': '1',
  'fullName': 'Amina Hassan',
  'admissionNo': 'MIF001',
  'classId': '8',
  'currentClass': {'id': '8', 'name': 'Level 1A'},
  'supportNotes': [
    {'id': '3', 'note': 'Revision practice'},
  ],
  'quranSessions': [
    {'surahId': 67, 'ayahFrom': 1, 'ayahTo': 10},
  ],
};
final classes = <Map<String, dynamic>>[
  {
    'id': '8',
    'name': 'Level 1A',
    'level': 'Foundation',
    'academicYear': '2026',
    'branch': {'name': 'Main campus'},
    '_count': {'currentStudents': 16},
    'timetable': [
      {
        'id': '1',
        'weekday': DateTime.now().weekday,
        'startsAt': '08:00',
        'endsAt': '08:45',
        'subject': 'Quran',
        'focus': 'Recitation and revision',
        'room': 'Room 01',
      },
    ],
  },
];
const meta = {'page': 1, 'totalPages': 1, 'totalItems': 1};

Future<dynamic> teacherLoad(String path) async {
  if (path == '/api/teacher-workspace/classes') return classes;
  if (path.contains('/overview')) {
    return {
      'date': attendanceDay(DateTime.now()),
      'classes': classes,
      'students': 16,
      'followUpCount': 1,
      'sessionsToday': 2,
      'followUps': [learner],
      'recentSessions': [],
    };
  }
  if (path.endsWith('/quran/catalog')) {
    return {
      'chapters': [
        {'id': 67, 'name': 'Al-Mulk', 'ayahCount': 30},
        {'id': 112, 'name': 'Al-Ikhlas', 'ayahCount': 4},
      ],
      'juzs': [
        {
          'number': 29,
          'ranges': [
            {'surahId': 67, 'from': 1, 'to': 30},
          ],
        },
        {
          'number': 30,
          'ranges': [
            {'surahId': 112, 'from': 1, 'to': 4},
          ],
        },
      ],
    };
  }
  if (path.contains('/quran?')) {
    return {
      'student': learner,
      'memorisedAyahs': [1, 2, 3, 4, 5],
      'sessions': [],
      'meta': {'page': 1, 'totalPages': 0, 'totalItems': 0},
    };
  }
  if (path.contains('/students?')) {
    return {
      'items': [learner],
      'meta': meta,
      'summary': {
        'assignedStudents': 16,
        'classes': 1,
        'followUps': 1,
        'withLearningRecords': 1,
      },
    };
  }
  if (path.endsWith('/students/1')) {
    return {'student': learner, 'supportNotes': [], 'sessions': []};
  }
  if (path.contains('/attendance/register?')) {
    return {
      'class': {
        'id': '8',
        'name': 'Level 1A',
        'teacher': {'fullName': 'Teacher Ahmad'},
      },
      'date': attendanceDay(schoolToday()),
      'today': attendanceDay(schoolToday()),
      'items': [
        {
          ...learner,
          'current': true,
          'editable': true,
          'attendance': {
            'status': 'LATE',
            'version': 1,
            'checkInTime': '08:15',
          },
        },
        {
          ...learner,
          'id': '2',
          'fullName': 'Bilal',
          'current': true,
          'editable': true,
          'attendance': null,
        },
      ],
      'summary': {
        'present': 0,
        'late': 1,
        'absent': 0,
        'excused': 0,
        'total': 1,
        'unmarked': 1,
      },
      'timeline': [
        {
          'date': attendanceDay(schoolToday()),
          'present': 0,
          'late': 1,
          'total': 1,
        },
      ],
    };
  }
  throw StateError('Unexpected path $path');
}

Widget host(Widget child) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);
void screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void navigate(int page, {String? classId, Map<String, dynamic>? student}) {}

Future<void> choosePassage(WidgetTester tester) async {
  for (final n in [11, 15]) {
    final tile = find.byKey(ValueKey('ayah-$n'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
  final observation = find.byKey(const ValueKey('observation-null'));
  await tester.ensureVisible(observation);
  await tester.tap(observation);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Independent').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unavailable student is handled while Quran filters are loading',
    (tester) async {
      screen(tester, 768);
      await tester.pumpWidget(
        host(
          TeacherQuranPage(
            load: (path) async {
              if (path.contains('/quran?')) {
                throw const ApiException('Student not found', 404);
              }
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return teacherLoad(path);
            },
            submit: (_, _) async => {},
            teacherId: '9',
            initialClassId: '8',
            initialStudent: learner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save progress'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
  testWidgets('cancelling a juz change keeps the selected passage and filter', (
    tester,
  ) async {
    screen(tester, 1672);
    await tester.pumpWidget(
      host(
        TeacherQuranPage(
          load: teacherLoad,
          submit: (_, _) async => {},
          teacherId: '9',
          initialClassId: '8',
          initialStudent: learner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ayah-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quran-juz-29-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juz 30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay here'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quran-juz-29-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('from-11-1')), findsOneWidget);
    expect(find.text('Al-Mulk'), findsOneWidget);
  });

  test('teacher pages have distinct jobs and exclude admin controls', () {
    final names = sectionsForRole('TEACHER').map((s) => s.title).toList();
    expect(names.take(5), [
      'Dashboard',
      'My Classes',
      'My Students',
      "Qur'an Tracking",
      'Attendance',
    ]);
    expect(names, containsAll(['My courses', 'School updates']));
    for (final forbidden in ['Teachers', 'Donations', 'Finance', 'Subjects']) {
      expect(names, isNot(contains(forbidden)));
    }
  });
  for (final width in [320.0, 768.0, 1672.0]) {
    testWidgets('teacher working pages fit $width without overflow', (
      tester,
    ) async {
      screen(tester, width);
      for (final page in <Widget>[
        TeacherOverviewPage(load: teacherLoad, onOpen: navigate),
        TeacherClassesPage(load: teacherLoad, onOpen: navigate),
        TeacherStudentsPage(
          load: teacherLoad,
          submit: (_, _) async => {},
          onOpen: navigate,
        ),
        TeacherQuranPage(
          load: teacherLoad,
          submit: (_, _) async => {},
          teacherId: '9',
          initialClassId: '8',
          initialStudent: learner,
        ),
        AttendanceRegisterPage(
          load: teacherLoad,
          submit: (_, _) async => {},
          teacherMode: true,
          initialClassId: '8',
        ),
      ]) {
        await tester.pumpWidget(host(page));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $width',
        );
      }
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Not yet marked'), findsOneWidget);
    });
  }
  testWidgets('class actions carry class context to the destination', (
    tester,
  ) async {
    screen(tester, 1672);
    int? destination;
    String? selected;
    await tester.pumpWidget(
      host(
        TeacherClassesPage(
          load: teacherLoad,
          onOpen: (page, {classId, student}) {
            destination = page;
            selected = classId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View class').first);
    expect(destination, 2);
    expect(selected, '8');
    await tester.tap(find.text('Attendance'));
    expect(destination, 4);
    expect(selected, '8');
  });
  testWidgets('Quran save retry keeps the exact payload and operation ID', (
    tester,
  ) async {
    screen(tester, 1672);
    final saves = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        TeacherQuranPage(
          load: teacherLoad,
          teacherId: '9',
          initialClassId: '8',
          initialStudent: learner,
          submit: (path, body) async {
            expect(path, '/api/teacher-workspace/quran/sessions');
            saves.add(Map.of(body));
            if (saves.length == 1) {
              throw const ApiException('Connection lost', 0);
            }
            return {'id': '21'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choosePassage(tester);
    await tester.ensureVisible(find.text('Save progress'));
    await tester.tap(find.text('Save progress'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not confirm this save'), findsOneWidget);
    expect(saves.single, containsPair('ayahFrom', 11));
    expect(saves.single, containsPair('ayahTo', 15));
    expect(saves.single, containsPair('observation', 'INDEPENDENT'));
    expect(saves.single, containsPair('studentId', '1'));
    await tester.ensureVisible(find.text('Retry save'));
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(saves[1], saves[0]);
    expect(find.text('Learning session saved.'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
  });
  testWidgets('unsaved Quran selection requires confirmation before leaving', (
    tester,
  ) async {
    screen(tester, 1672);
    final key = GlobalKey<TeacherQuranPageState>();
    await tester.pumpWidget(
      host(
        TeacherQuranPage(
          key: key,
          load: teacherLoad,
          submit: (_, _) async => {},
          teacherId: '9',
          initialClassId: '8',
          initialStudent: learner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ayah-11')));
    await tester.pumpAndSettle();
    final stay = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay here'));
    await tester.pumpAndSettle();
    expect(await stay, isFalse);
    final leave = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave session'));
    await tester.pumpAndSettle();
    expect(await leave, isTrue);
  });
  testWidgets('student picker searches only the selected class', (
    tester,
  ) async {
    screen(tester, 768);
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => pickTeacherStudent(context, (path) async {
              paths.add(path);
              return teacherLoad(path);
            }, '8'),
            child: const Text('Choose'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Amina');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(Uri.parse(paths.last).queryParameters, containsPair('classId', '8'));
    expect(
      Uri.parse(paths.last).queryParameters,
      containsPair('search', 'Amina'),
    );
    await tester.tap(find.text('Amina Hassan'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a student'), findsNothing);
  });
  testWidgets('empty classes give a real next step instead of fake counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TeacherClassesPage(load: (_) async => [], onOpen: navigate)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No classes assigned yet'), findsOneWidget);
    expect(find.textContaining('No teaching'), findsNothing);
    expect(find.text('16 learners'), findsNothing);
    expect(find.text('Trusted'), findsNothing);
  });
}
