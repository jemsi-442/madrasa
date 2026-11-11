import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/attendance_register_page.dart';
import 'package:mif_app/src/teacher_teaching_pages.dart';
import 'package:mif_app/src/teacher_students_page.dart';
import 'package:mif_app/src/teacher_quran_page.dart';
import 'package:mif_app/src/teacher_ui.dart';
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
  if (path.contains('/quran/roster?')) {
    return {
      'items': [],
      'total': 1,
      'recorded': 1,
      'remaining': 0,
      'nextStudent': null,
      'meta': meta,
    };
  }
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
  for (final providerAvailable in [true, false]) {
    testWidgets(
      'reader preserves session draft without saving (provider $providerAvailable)',
      (tester) async {
        screen(tester, 1672);
        final saves = <Map<String, dynamic>>[];
        final readerRequests = <String>[];
        await tester.pumpWidget(
          host(
            TeacherQuranPage(
              teacherId: '9',
              initialClassId: '8',
              initialStudent: learner,
              load: (path) async {
                if (!path.contains('/quran/content/')) return teacherLoad(path);
                readerRequests.add(path);
                if (!providerAvailable) {
                  throw const ApiException('Provider unavailable', 503);
                }
                if (path.endsWith('/chapters')) {
                  return {
                    'limitedContent': false,
                    'chapters': [
                      {'id': 67, 'name_simple': 'Al-Mulk', 'verses_count': 30},
                    ],
                  };
                }
                throw const ApiException('Provider unavailable', 503);
              },
              submit: (_, body) async {
                saves.add(Map.of(body));
                return {'id': 'synthetic-session'};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await choosePassage(tester);
        await tester.ensureVisible(find.text('Open Quran Reader'));
        await tester.tap(find.text('Open Quran Reader'));
        await tester.pumpAndSettle();
        expect(find.text("Qur'an Reader"), findsOneWidget);
        expect(saves, isEmpty);
        expect(readerRequests.length, providerAvailable ? 2 : 1);
        expect(
          readerRequests.every(
            (path) => !path.contains('studentId') && !path.contains('classId'),
          ),
          isTrue,
        );
        if (providerAvailable) {
          expect(
            readerRequests.last,
            endsWith('/67/verses?page=2&per_page=10'),
          );
        }
        expect(find.text('Tracker passage: 67:11 - 67:15'), findsOneWidget);
        await tester.tap(find.text('Close reader'));
        await tester.pumpAndSettle();
        expect(saves, isEmpty);
        await tester.ensureVisible(find.text('Save progress'));
        await tester.tap(find.text('Save progress'));
        await tester.pumpAndSettle();
        expect(saves, hasLength(1));
        expect(saves.single, containsPair('ayahFrom', 11));
        expect(saves.single, containsPair('ayahTo', 15));
        expect(saves.single, containsPair('observation', 'INDEPENDENT'));
        expect(saves.single, containsPair('studentId', '1'));
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    await tester.ensureVisible(find.text('View class').first);
    await tester.tap(find.text('View class').first);
    expect(destination, 2);
    expect(selected, '8');
    await tester.tap(find.text('Attendance'));
    expect(destination, 4);
    expect(selected, '8');
    await tester.tap(find.text('My courses'));
    expect(destination, 5);
    expect(selected, '8');
  });
  testWidgets(
    'classes summary uses timetable data and quick actions navigate',
    (tester) async {
      screen(tester, 1672);
      int? destination;
      String? scope;
      await tester.pumpWidget(
        host(
          TeacherClassesPage(
            load: teacherLoad,
            onOpen: (page, {classId, student}) {
              destination = page;
              scope = classId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total classes'), findsOneWidget);
      expect(find.text('Total learners'), findsOneWidget);
      expect(find.text('Timetabled subjects'), findsOneWidget);
      expect(find.text('Weekly periods'), findsOneWidget);
      expect(find.text('Assigned courses'), findsNothing);
      expect(find.text('16'), findsOneWidget);
      for (final (label, page) in [
        ('Record attendance', 4),
        ('Manage my courses', 5),
        ('View curriculum', 10),
        ('Class reports', 9),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        expect(destination, page);
        expect(scope, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Record next student'), findsNothing);
    expect(saves.single, containsPair('ayahFrom', 11));
    expect(saves.single, containsPair('ayahTo', 15));
    expect(saves.single, containsPair('observation', 'INDEPENDENT'));
    expect(saves.single, containsPair('studentId', '1'));
    expect(saves.single['clientId'], isA<String>());
    expect(saves.single['clientId'], isNotEmpty);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('ayah-11')))
          .onPressed,
      isNull,
      reason: 'An unconfirmed save must keep the original passage locked.',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('observation-INDEPENDENT')),
          )
          .onChanged,
      isNull,
    );
    await tester.ensureVisible(find.text('Retry save'));
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(saves, hasLength(2));
    expect(saves[1], saves[0]);
    expect(find.text('Learning session saved.'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
  });
  testWidgets('timetable opens a dated period without creating a record', (
    tester,
  ) async {
    screen(tester, 1672);
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      host(
        TeacherOverviewPage(
          load: teacherLoad,
          onOpen: (_, {classId, student}) {},
          onOpenPeriod: (value) => selected = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('record-period-1')));
    await tester.tap(find.byKey(const ValueKey('record-period-1')));
    expect(selected!['id'], '1');
    expect(selected!['classId'], '8');
    expect(selected!['learnedOn'], attendanceDay(DateTime.now()));
  });
  for (final width in [390.0, 1672.0]) {
    testWidgets(
      'scheduled Quran save retains period and reveals form at $width',
      (tester) async {
        screen(tester, width);
        final key = GlobalKey<TeacherQuranPageState>();
        Map<String, dynamic>? saved;
        await tester.pumpWidget(
          host(
            TeacherQuranPage(
              key: key,
              teacherId: '9',
              initialClassId: '8',
              initialStudent: learner,
              initialPeriod: {
                'id': '44',
                'classId': '8',
                'learnedOn': '2026-09-01',
                'subject': 'Synthetic lesson',
                'startsAt': '08:00',
                'endsAt': '09:00',
              },
              load: teacherLoad,
              submit: (_, body) async {
                saved = Map.of(body);
                return {};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await choosePassage(tester);
        await key.currentState!.save();
        await tester.pumpAndSettle();
        final formTop = tester
            .getTopLeft(find.byKey(key.currentState!.formAnchor))
            .dy;
        expect(formTop, greaterThanOrEqualTo(0));
        expect(formTop, lessThan(300));
        expect(saved!['timetableSlotId'], '44');
        expect(saved!['learnedOn'], '2026-09-01');
        expect(
          Uri.parse(
            passageRosterPath(saved!, 1),
          ).queryParameters['timetableSlotId'],
          '44',
        );
        await key.currentState!.changeClass('');
        await tester.pumpAndSettle();
        expect(key.currentState!.period, isNull);
      },
    );
  }
  testWidgets('next student retains passage but never copies results', (
    tester,
  ) async {
    screen(tester, 1672);
    final nextLearner = {...learner, 'id': '2', 'fullName': 'Demo Learner Two'};
    final saves = <Map<String, dynamic>>[];
    final key = GlobalKey<TeacherQuranPageState>();
    await tester.pumpWidget(
      host(
        TeacherQuranPage(
          key: key,
          teacherId: '9',
          initialClassId: '8',
          initialStudent: learner,
          load: (path) async {
            if (path.contains('/quran/roster?')) {
              expect(Uri.parse(path).queryParameters['classId'], '8');
              return {
                'items': [
                  {...nextLearner, 'recorded': false},
                ],
                'total': 2,
                'recorded': 1,
                'remaining': 1,
                'nextStudent': nextLearner,
                'meta': meta,
              };
            }
            if (path.contains('/students?')) {
              expect(Uri.parse(path).queryParameters['classId'], '8');
              return {
                'items': [nextLearner],
                'meta': meta,
              };
            }
            final data = await teacherLoad(path);
            if (path.contains('/quran?') &&
                Uri.parse(path).queryParameters['studentId'] == '2') {
              return {...data as Map<String, dynamic>, 'student': nextLearner};
            }
            return data;
          },
          submit: (path, body) async {
            saves.add(Map.of(body));
            return {'id': 'synthetic-session'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choosePassage(tester);
    key.currentState!.note.text = 'Synthetic first learner note';
    await tester.ensureVisible(find.text('Save progress'));
    await tester.tap(find.text('Save progress'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record next student'));
    expect(find.text('1 recorded / 2 students | 1 remaining'), findsOneWidget);
    await tester.tap(find.text('Record next student'));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    expect(state.classId, '8');
    expect(state.student!['id'], '2');
    expect(state.from, 11);
    expect(state.to, 15);
    expect(state.observation, isNull);
    expect(state.note.text, isEmpty);
    expect(state.pending, isNull);
    expect(saves, hasLength(1));
    await state.save();
    expect(saves, hasLength(1), reason: 'A fresh observation is required.');
  });
  testWidgets(
    'skip confirms draft loss, advances without writing and can revisit',
    (tester) async {
      screen(tester, 1672);
      final key = GlobalKey<TeacherQuranPageState>();
      var writes = 0;
      final paths = <String>[];
      final second = {...learner, 'id': '2', 'fullName': 'Demo Learner Two'};
      await tester.pumpWidget(
        host(
          TeacherQuranPage(
            key: key,
            teacherId: '9',
            initialClassId: '8',
            initialStudent: learner,
            load: (path) async {
              if (path.contains('/quran/roster?')) {
                paths.add(path);
                final skip = Uri.parse(path).queryParameters['skipIds'];
                return {
                  'total': 2,
                  'recorded': 0,
                  'remaining': 2,
                  'nextStudent': skip == null ? learner : second,
                };
              }
              if (path.contains('/quran?') &&
                  Uri.parse(path).queryParameters['studentId'] == '2') {
                return {
                  ...await teacherLoad(path) as Map<String, dynamic>,
                  'student': second,
                };
              }
              return teacherLoad(path);
            },
            submit: (_, _) async {
              writes++;
              return {};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choosePassage(tester);
      await tester.ensureVisible(find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay here'));
      await tester.pumpAndSettle();
      expect(paths, isEmpty);
      expect(key.currentState!.observation, 'INDEPENDENT');
      await tester.ensureVisible(find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave session'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.single).queryParameters['skipIds'], '1');
      expect(key.currentState!.student!['id'], '2');
      expect(key.currentState!.from, 11);
      expect(key.currentState!.observation, isNull);
      expect(writes, 0);
      await tester.ensureVisible(find.text('Review skipped students'));
      await tester.tap(find.text('Review skipped students'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave session'));
      await tester.pumpAndSettle();
      expect(
        Uri.parse(paths.last).queryParameters.containsKey('skipIds'),
        isFalse,
      );
      expect(key.currentState!.student!['id'], '1');
      expect(writes, 0);
    },
  );

  testWidgets(
    'period summary reads all passages and opens student history without saving',
    (tester) async {
      screen(tester, 390);
      final key = GlobalKey<TeacherQuranPageState>();
      var writes = 0;
      await tester.pumpWidget(
        host(
          TeacherQuranPage(
            key: key,
            teacherId: '9',
            initialClassId: '8',
            initialStudent: learner,
            load: (path) async {
              if (path.contains('/quran/roster?')) {
                expect(Uri.parse(path).queryParameters['summary'], 'true');
                return {
                  'total': 1,
                  'recorded': 1,
                  'remaining': 0,
                  'needsSupport': 1,
                  'meta': meta,
                  'items': [
                    {
                      ...learner,
                      'fullName': 'Demo Summary Learner',
                      'recorded': true,
                      'needsSupport': true,
                      'latestSession': {'id': '42', 'surahId': 112},
                    },
                  ],
                };
              }
              return teacherLoad(path);
            },
            submit: (_, _) async {
              writes++;
              return {};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period summary'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 student has at least one'), findsOneWidget);
      await tester.ensureVisible(find.text('Demo Summary Learner'));
      await tester.tap(find.text('Demo Summary Learner'));
      await tester.pumpAndSettle();
      expect(key.currentState!.surah, 112);
      expect(key.currentState!.juz, 0);
      final historyTop = tester
          .getTopLeft(find.byKey(key.currentState!.historyAnchor))
          .dy;
      expect(historyTop, greaterThanOrEqualTo(0));
      expect(historyTop, lessThan(300));
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'roster expansion storage does not read the workspace scroll offset',
    (tester) async {
      final bucket = PageStorageBucket();
      await tester.pumpWidget(
        host(
          PageStorage(
            bucket: bucket,
            child: Builder(
              key: const PageStorageKey('teacher-workspace-scroll'),
              builder: (context) {
                bucket.writeState(context, 440.0);
                return PassageRoster(
                  load: teacherLoad,
                  passage: const {
                    'classId': '8',
                    'learnedOn': '2026-09-01',
                    'surahId': 67,
                    'ayahFrom': 11,
                    'ayahTo': 15,
                    'activity': 'READING',
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Class recording list'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final unavailable in [false, true]) {
    testWidgets(
      'next student handles ${unavailable ? 'unavailable roster' : 'completed roster'} without saving',
      (tester) async {
        screen(tester, 1672);
        final key = GlobalKey<TeacherQuranPageState>();
        var saves = 0;
        await tester.pumpWidget(
          host(
            TeacherQuranPage(
              key: key,
              teacherId: '9',
              initialClassId: '8',
              initialStudent: learner,
              load: (path) async {
                if (unavailable && path.contains('/quran/roster?')) {
                  throw const ApiException('Access changed', 404);
                }
                return teacherLoad(path);
              },
              submit: (_, _) async {
                saves++;
                return {};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        key.currentState!.savedPassage = {
          'studentId': '1',
          'classId': '8',
          'surahId': 67,
          'ayahFrom': 11,
          'ayahTo': 15,
          'activity': 'READING',
          'learnedOn': '2026-09-01',
        };
        await key.currentState!.recordNextStudent();
        await tester.pumpAndSettle();
        expect(key.currentState!.student!['id'], '1');
        expect(key.currentState!.busy, isFalse);
        expect(saves, 0);
        expect(
          find.text(
            unavailable
                ? 'Could not refresh the class roster. Try again.'
                : 'All current students have a record for this passage and date.',
          ),
          findsOneWidget,
        );
      },
    );
  }
  for (final status in [403, 404, 422]) {
    testWidgets('Quran retry handles a definitive $status response', (
      tester,
    ) async {
      screen(tester, 1672);
      final saves = <Map<String, dynamic>>[];
      final key = GlobalKey<TeacherQuranPageState>();
      await tester.pumpWidget(
        host(
          TeacherQuranPage(
            key: key,
            load: teacherLoad,
            teacherId: '9',
            initialClassId: '8',
            initialStudent: learner,
            submit: (_, body) async {
              saves.add(Map.of(body));
              throw ApiException(
                'Synthetic failure',
                saves.length == 1 ? 0 : status,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choosePassage(tester);
      await tester.ensureVisible(find.text('Save progress'));
      await tester.tap(find.text('Save progress'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry save'));
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(saves, hasLength(2));
      expect(saves[1], saves[0]);
      expect(find.text('Retry save'), findsNothing);
      expect(find.text('Learning session saved.'), findsNothing);
      final saveButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Save progress'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      if (status == 422) {
        expect(find.textContaining('Check the session date'), findsOneWidget);
        expect(saveButton.onPressed, isNotNull);
      } else {
        expect(find.textContaining('no longer available'), findsOneWidget);
        expect(
          find.textContaining('Keep this page open until your save'),
          findsNothing,
        );
        expect(saveButton.onPressed, isNull);
        await key.currentState!.save();
        expect(
          saves,
          hasLength(2),
          reason: 'The save guard must also block direct callbacks.',
        );
        await tester.ensureVisible(find.text('Refresh class list'));
        await tester.tap(find.text('Refresh class list'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Check the learning history'),
          findsOneWidget,
        );
        await tester.tap(find.text('Stay here'));
        await tester.pumpAndSettle();
        expect(key.currentState!.from, 11);
        expect(key.currentState!.to, 15);
        expect(key.currentState!.saveAccessDenied, isTrue);
        expect(saves, hasLength(2));
        await tester.ensureVisible(find.text('Refresh class list'));
        await tester.tap(find.text('Refresh class list'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave session'));
        await tester.pumpAndSettle();
        expect(key.currentState!.classId, isEmpty);
        expect(key.currentState!.student, isNull);
        expect(key.currentState!.progress, isNull);
        expect(key.currentState!.from, isNull);
        expect(find.text('Choose a class'), findsOneWidget);
        expect(find.text('Save progress'), findsNothing);
        expect(saves, hasLength(2));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'voided learning history exposes read-only correction details at $width',
      (tester) async {
        screen(tester, width);
        var corrections = 0;
        const reason =
            'Synthetic correction: the selected passage belonged to a different practice session.';
        await tester.pumpWidget(
          host(
            LearningHistory(
              [
                {
                  'id': '91',
                  'teacherId': '9',
                  'surahId': 67,
                  'ayahFrom': 11,
                  'ayahTo': 15,
                  'activity': 'MEMORIZATION',
                  'observation': 'INDEPENDENT',
                  'learnedOn': '2026-09-01',
                  'voidedAt': '2026-09-02T10:00:00.000Z',
                  'voidReason': reason,
                  'teacher': {'fullName': 'Synthetic Teacher'},
                },
              ],
              teacherId: '9',
              onVoid: (_) => corrections++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Correct this record'), findsNothing);
        final details = find.byTooltip('View correction details');
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.text('Learning record correction'), findsOneWidget);
        expect(find.text('Surah 67 | 11-15'), findsOneWidget);
        expect(find.text(reason), findsOneWidget);
        expect(find.text('Original observation'), findsOneWidget);
        expect(find.text('Void this entry'), findsNothing);
        expect(corrections, 0);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Learning record correction'), findsNothing);
      },
    );
  }

  testWidgets(
    'mobile history keeps observations and permitted actions in view',
    (tester) async {
      screen(tester, 390);
      String? corrected;
      await tester.pumpWidget(
        host(
          LearningHistory(
            [
              for (final id in ['91', '92'])
                {
                  'id': id,
                  'teacherId': id == '91' ? '9' : '10',
                  'learnedOn': '2026-09-01',
                  'activity': 'MEMORIZATION',
                  'ayahFrom': 11,
                  'ayahTo': 15,
                  'observation': 'NEEDS_PRACTICE',
                  'teacher': {'fullName': 'Synthetic Teacher'},
                  'timetableSlot': {'startsAt': '08:00', 'endsAt': '08:45'},
                },
            ],
            teacherId: '9',
            onVoid: (record) => corrected = record['id'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('08:00-08:45'), findsNWidgets(2));
      final action = find.byTooltip('Correct this record');
      expect(action, findsOneWidget);
      final bounds = tester.getRect(action);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(390));
      await tester.tap(action);
      expect(corrected, '91');
      expect(tester.takeException(), isNull);
    },
  );

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
