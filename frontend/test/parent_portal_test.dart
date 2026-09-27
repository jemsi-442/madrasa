import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/parent_portal_page.dart';
import 'package:mif_app/src/workspace.dart';

final child = <String, dynamic>{
  'id': '1',
  'fullName': 'Amina Hassan',
  'admissionNo': 'AFQ001',
  'gender': 'FEMALE',
  'status': 'ACTIVE',
  'dob': '2017-03-15',
  'joinedOn': '2023-09-01',
  'currentClass': {
    'id': '8',
    'name': 'Level 1A',
    'academicYear': '2026',
    'teacher': {'fullName': 'Teacher Ayesha'},
  },
  'branch': {'name': 'Main campus'},
  'attendance': {
    'PRESENT': 1,
    'ABSENT': 1,
    'LATE': 1,
    'EXCUSED': 1,
    'rate': 67,
    'markedDays': 4,
  },
  'quran': {'percent': 0.1, 'memorisedAyahs': 8, 'totalAyahs': 6236},
};
final sibling = {
  ...child,
  'id': '2',
  'fullName': 'Yusuf Hassan',
  'attendance': {'rate': null},
  'admissionNo': 'AFQ002',
};
const notice = {
  'title': 'Family notice',
  'message': 'Please contact the office for term dates.',
  'publishAt': '2026-09-01',
};
const guardian = {
  'fullName': 'Mariam Hassan',
  'phone': '255700000000',
  'relationship': 'Mother',
};
final session = {
  'surahId': 67,
  'ayahFrom': 1,
  'ayahTo': 8,
  'activity': 'MEMORIZATION',
  'observation': 'INDEPENDENT',
  'learnedOn': '2026-09-20',
  'teacher': {'fullName': 'Teacher Ahmad'},
};

Future<dynamic> familyLoad(String path) async {
  if (path.endsWith('/overview')) {
    return {
      'guardian': guardian,
      'month': '2026-09',
      'children': [child, sibling],
      'announcements': [notice],
    };
  }
  if (path.endsWith('/announcements')) return [notice];
  if (path.endsWith('/profile')) {
    return {
      'student': child,
      'guardian': guardian,
      'timetable': [
        {
          'weekday': 1,
          'startsAt': '08:00',
          'endsAt': '08:45',
          'subject': 'Quran',
          'room': 'Room 1',
        },
      ],
    };
  }
  if (path.contains('/attendance?')) {
    return {
      'summary': child['attendance'],
      'records': [
        {'date': '2026-09-01', 'status': 'PRESENT'},
        {'date': '2026-09-02', 'status': 'LATE', 'reason': 'Traffic'},
        {'date': '2026-09-03', 'status': 'ABSENT'},
        {'date': '2026-09-04', 'status': 'EXCUSED'},
      ],
    };
  }
  if (path.contains('/quran?')) {
    return {
      'memorisedAyahs': 8,
      'totalAyahs': 6236,
      'percent': 0.1,
      'latestSession': session,
      'sessions': [session],
      'chapters': [
        {'id': 67, 'name': 'Al-Mulk', 'ayahCount': 30, 'memorisedAyahs': 8},
      ],
      'juzs': [
        for (var n = 1; n <= 30; n++)
          {'number': n, 'memorisedAyahs': n == 29 ? 8 : 0, 'totalAyahs': 431},
      ],
      'meta': {'totalItems': 21, 'totalPages': 2},
    };
  }
  if (path.endsWith('/finance')) {
    return [
      {
        'invoiceNo': 'INV-1',
        'dueDate': '2026-10-01',
        'amountDue': '10000',
        'amountPaid': '0',
        'balanceRemaining': '10000',
        'currency': 'TZS',
        'status': 'ISSUED',
        'payments': [
          {
            'status': 'PENDING',
            'reference': 'PAY-1',
            'amount': '10000',
            'currency': 'TZS',
          },
        ],
      },
    ];
  }
  throw StateError('Unexpected endpoint $path');
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
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ParentPortalPage portal(
  int page, {
  PageLoader load = familyLoad,
  int refresh = 0,
}) => ParentPortalPage(
  key: ValueKey('parent-$page'),
  load: load,
  page: page,
  refreshToken: refresh,
  onChildSelected: (_) {},
  onOpen: (_, {childId}) {},
);

void main() {
  test(
    'parent navigation exposes implemented pages, never admin endpoints',
    () {
      final sections = sectionsForRole('PARENT');
      expect(sections.map((s) => s.title), [
        'Dashboard',
        'My Children',
        'Attendance',
        "Qur'an Progress",
        'School updates',
        'Payments',
        'Support',
        'Messages',
      ]);
      expect(sections.any((s) => s.path.contains('/admin/')), isFalse);
    },
  );

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('all parent pages fit at $width', (tester) async {
      screen(tester, width);
      for (var page = 0; page < 7; page++) {
        await tester.pumpWidget(host(portal(page)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Page $page at $width');
      }
    });
  }

  testWidgets('calendar distinguishes unmarked from absent and holidays', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      host(
        FamilyAttendanceCalendar(
          month: DateTime(2026, 9),
          records: const [
            {'date': '2026-09-01T00:00:00.000Z', 'status': 'LATE'},
            {'date': '2026-09-02', 'status': 'ABSENT'},
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('2026-09-01: Late')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('2026-09-02: Absent')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('2026-09-03: No record')),
      findsOneWidget,
    );
    expect(find.text('No School'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'child selector changes scoped request and hides old data while loading',
    (tester) async {
      screen(tester, 1200);
      String? selected;
      final paths = <String>[];
      final waiting = Completer<dynamic>();
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => ParentPortalPage(
              page: 5,
              childId: selected,
              load: (path) {
                paths.add(path);
                return path.contains('/students/2/finance')
                    ? waiting.future
                    : familyLoad(path);
              },
              onChildSelected: (id) => setState(() => selected = id),
              onOpen: (_, {childId}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INV-1'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yusuf Hassan').last);
      await tester.pump();
      expect(paths, contains('/api/parent-portal/students/2/finance'));
      expect(find.text('INV-1'), findsNothing);
      waiting.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No invoices issued for this child.'), findsOneWidget);
    },
  );

  testWidgets(
    'profile loads safe details and timetable; child linking requires office',
    (tester) async {
      screen(tester, 1440);
      final paths = <String>[];
      await tester.pumpWidget(
        host(
          portal(
            1,
            load: (path) {
              paths.add(path);
              return familyLoad(path);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View profile').first);
      await tester.pumpAndSettle();
      expect(
        paths,
        contains('/api/parent-portal/workspace/children/1/profile'),
      );
      expect(find.text('Teacher Ayesha'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      await tester.tap(find.text('Request child link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Staff must verify'), findsOneWidget);
      expect(find.text('Save student'), findsNothing);
    },
  );

  testWidgets('Quran switches views and requests next history page', (
    tester,
  ) async {
    screen(tester, 1440);
    final paths = <String>[];
    await tester.pumpWidget(
      host(
        portal(
          3,
          load: (path) {
            paths.add(path);
            return familyLoad(path);
          },
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
    expect(paths.last, '/api/parent-portal/workspace/children/1/quran?page=2');
    expect(find.text('Save progress'), findsNothing);
  });

  testWidgets('empty family has office guidance, no invented metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        portal(
          0,
          load: (_) async => {
            'guardian': guardian,
            'children': [],
            'announcements': [],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No children are linked yet'), findsOneWidget);
    expect(find.text('96%'), findsNothing);
    expect(find.text('Request child link'), findsOneWidget);
  });

  testWidgets('overview errors can retry without showing sample records', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        portal(
          0,
          load: (path) {
            if (++calls == 1) return Future.error(StateError('offline'));
            return familyLoad(path);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Amina Hassan'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Learning overview'), findsOneWidget);
  });
}
