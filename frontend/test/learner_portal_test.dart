import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/learner_portal_page.dart';
import 'package:mif_app/src/workspace.dart';

const student = {
  'id': '1',
  'fullName': 'Ahmad Hassan',
  'admissionNo': 'SELF',
  'currentClass': {'id': '2', 'name': 'Year 2'},
  'branch': {'name': 'Main'},
};
const summary = {
  'PRESENT': 18,
  'LATE': 1,
  'ABSENT': 2,
  'EXCUSED': 1,
  'markedDays': 22,
  'rate': 90,
};
const lesson = {
  'surahId': 67,
  'ayahFrom': 1,
  'ayahTo': 8,
  'learnedOn': '2026-09-20',
  'activity': 'MEMORIZATION',
  'observation': 'INDEPENDENT',
  'teacher': {'fullName': 'Ustadh Ahmad'},
};
const slot = {
  'date': '2026-09-28',
  'startsAt': '08:00',
  'endsAt': '08:40',
  'subject': 'Quran',
  'room': 'Room 1',
};
const report = {
  'id': '3',
  'publishedOn': '2026-09-28',
  'snapshot': {
    'school': 'Test School',
    'period': {
      'name': 'September report',
      'startsOn': '2026-09-01',
      'endsOn': '2026-09-20',
    },
    'student': student,
    'className': 'Year 2',
    'teacher': 'Ustadh Ahmad',
    'feedback': 'Keep revising at home.',
    'policy': 'Published records only',
    'assessments': [],
    'attendance': {'recorded': 22, 'rate': 90},
    'quran': {'memorisedAyahs': 8, 'sessions': 4},
  },
};
Future<dynamic> load(String path) async {
  if (path.endsWith('/overview')) {
    return {
      'student': student,
      'today': '2026-09-28',
      'month': '2026-09',
      'attendance': summary,
      'quran': {'percent': 0.1, 'memorisedAyahs': 8},
      'academics': {
        'average': 80,
        'year': 2026,
        'subjects': [
          {'name': 'Fiqh', 'average': 80},
        ],
      },
      'sessions': [slot],
      'latestReport': report,
      'announcements': [
        {
          'title': 'School notice',
          'message': 'Bring your books.',
          'publishAt': '2026-09-28',
        },
      ],
    };
  }
  if (path.contains('/classes?')) {
    return {
      'student': student,
      'today': '2026-09-28',
      'weekStart': '2026-09-28',
      'weekEnd': '2026-10-04',
      'sessions': [slot],
    };
  }
  if (path.contains('/attendance?')) {
    return {
      'summary': summary,
      'records': [
        {
          'date': '2026-09-01',
          'status': 'PRESENT',
          'checkInTime': '08:00',
          'class': {'name': 'Year 2'},
        },
        {
          'date': '2026-09-02',
          'status': 'ABSENT',
          'reason': 'School-recorded note',
        },
      ],
    };
  }
  if (path.contains('/quran?')) {
    return {
      'memorisedAyahs': 8,
      'totalAyahs': 6236,
      'percent': 0.1,
      'latestSession': lesson,
      'chapters': [
        {'id': 67, 'name': 'Al-Mulk', 'ayahCount': 30, 'memorisedAyahs': 8},
      ],
      'juzs': [
        for (var n = 1; n <= 30; n++)
          {'number': n, 'memorisedAyahs': n == 29 ? 8 : 0, 'totalAyahs': 431},
      ],
      'sessions': path.endsWith('page=2') ? [] : [lesson],
      'meta': {'totalPages': 2, 'totalItems': 21},
    };
  }
  if (path.contains('/academic?')) {
    return {
      'average': 80,
      'subjects': [
        {'id': '2', 'name': 'Fiqh', 'average': 80, 'assessments': 1},
      ],
      'records': [
        {
          'id': '4',
          'title': 'Wudu practical',
          'assessedOn': '2026-09-20',
          'subject': {'name': 'Fiqh'},
          'teacher': 'Ustadh Ahmad',
          'score': 8,
          'maxScore': 10,
          'percent': 80,
          'feedback': 'Good sequence',
        },
      ],
      'policy': 'Each assessment contributes equally, not a class rank.',
    };
  }
  if (path.contains('/reports?')) {
    return {
      'items': [report],
      'meta': {'totalItems': 1},
    };
  }
  throw StateError('Unexpected path: $path');
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
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('keeps existing learner routes and adds self-only school records', () {
    final sections = sectionsForRole('LEARNER');
    expect(sections.take(5).map((s) => s.path), [
      '/api/learner/me',
      '/api/learner/courses',
      '/api/learner/progress',
      '/api/learner/finance',
      '/api/learner/announcements',
    ]);
    expect(sections.skip(5).map((s) => s.title), [
      'Classes',
      'Attendance',
      "Qur'an Progress",
      'Academic Progress',
      'Reports',
    ]);
  });
  for (final width in [390.0, 1440.0]) {
    for (final page in [0, 5, 6, 7, 8, 9]) {
      testWidgets('learner page $page is responsive at $width', (tester) async {
        screen(tester, width);
        final paths = <String>[];
        await tester.pumpWidget(
          host(
            LearnerPortalPage(
              page: page,
              load: (path) {
                paths.add(path);
                return load(path);
              },
              onOpen: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(paths, isNotEmpty);
        expect(
          paths.every((p) => p.startsWith('/api/learner/workspace/')),
          isTrue,
        );
        expect(find.textContaining('selected child'), findsNothing);
      });
    }
  }
  testWidgets('dashboard links to existing courses and new timetable', (
    tester,
  ) async {
    screen(tester, 1440);
    final opened = <int>[];
    await tester.pumpWidget(
      host(LearnerPortalPage(page: 0, load: load, onOpen: opened.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My courses'));
    await tester.tap(find.text('Timetable'));
    expect(opened, [1, 5]);
    expect(find.text('80%'), findsWidgets);
    expect(find.text('School notice'), findsOneWidget);
  });
  testWidgets(
    'calendar navigation requests the selected month and refresh reloads it',
    (tester) async {
      screen(tester, 1440);
      final paths = <String>[];
      Future<dynamic> request(String path) {
        paths.add(path);
        return load(path);
      }

      Widget page(int refresh) => host(
        LearnerPortalPage(
          page: 6,
          load: request,
          refreshToken: refresh,
          onOpen: (_) {},
        ),
      );
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      final first = paths.last;
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(paths.last, isNot(first));
      final selected = paths.last;
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(paths.last, selected);
      expect(paths.length, 3);
      expect(find.text('Unmarked: no record'), findsOneWidget);
    },
  );
  testWidgets('timetable week navigation and list view work', (tester) async {
    screen(tester, 1440);
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        LearnerPortalPage(
          page: 5,
          load: (p) {
            paths.add(p);
            return load(p);
          },
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = paths.last;
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(paths.last, isNot(first));
    await tester.tap(find.text('List view'));
    await tester.pumpAndSettle();
    expect(find.text('08:00 - 08:40'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
  });
  testWidgets('Quran switches tracker and pages history', (tester) async {
    screen(tester, 1440);
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        LearnerPortalPage(
          page: 7,
          load: (p) {
            paths.add(p);
            return load(p);
          },
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('By Surah'));
    await tester.pumpAndSettle();
    expect(find.text('67. Al-Mulk'), findsOneWidget);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(paths.last, '/api/learner/workspace/quran?page=2');
    expect(find.text('No learning sessions on this page.'), findsOneWidget);
  });
  testWidgets('learner opens a published report without parent endpoints', (
    tester,
  ) async {
    screen(tester, 1440);
    await tester.pumpWidget(
      host(LearnerPortalPage(page: 9, load: load, onOpen: (_) {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View report'));
    await tester.pumpAndSettle();
    expect(find.text('Keep revising at home.'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close report'));
    await tester.pumpAndSettle();
  });
  testWidgets('empty attendance does not fabricate a rate', (tester) async {
    screen(tester, 390);
    await tester.pumpWidget(
      host(
        LearnerPortalPage(
          page: 6,
          load: (_) async => {
            'summary': {
              'PRESENT': 0,
              'LATE': 0,
              'ABSENT': 0,
              'EXCUSED': 0,
              'markedDays': 0,
              'rate': null,
            },
            'records': [],
          },
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading and retry recover from an API error', (tester) async {
    screen(tester, 1440);
    var fail = true;
    final pending = Completer<dynamic>();
    await tester.pumpWidget(
      host(
        LearnerPortalPage(
          page: 0,
          load: (_) =>
              fail ? pending.future : load('/api/learner/workspace/overview'),
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(Exception('Offline'));
    await tester.pumpAndSettle();
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your learning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
