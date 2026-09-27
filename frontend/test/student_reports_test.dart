import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/student_reports_page.dart';
import 'package:mif_app/src/parent_reports.dart';
import 'package:mif_app/src/report_preview.dart';
import 'package:mif_app/src/workspace.dart';

Map<String, dynamic> snapshot() => {
  'school': 'Kibada Madrasa',
  'period': {
    'name': 'September 2026',
    'startsOn': '2026-09-01',
    'endsOn': '2026-09-20',
  },
  'student': {'id': '4', 'fullName': 'Amina Hassan', 'admissionNo': 'AFQ-001'},
  'className': 'Level 1A',
  'teacher': 'Ustadh Ahmad',
  'feedback': 'Keep revising at home.',
  'assessments': [
    {
      'releaseId': '7',
      'subject': 'Fiqh',
      'title': 'Wudu practical',
      'date': '2026-09-10',
      'score': 8,
      'maxScore': 10,
      'feedback': 'Correct sequence',
    },
  ],
  'attendance': {
    'present': 10,
    'late': 1,
    'absent': 1,
    'excused': 1,
    'recorded': 13,
    'rate': 91.67,
  },
  'quran': {
    'sessions': 4,
    'memorisedAyahs': 10,
    'reading': 1,
    'revision': 1,
    'tajweed': 0,
  },
  'policy': 'Learning summary, not a weighted term grade or class rank.',
};

class Fixture {
  final loads = <String>[];
  final writes = <(String, Map<String, dynamic>)>[];
  bool fail = false;
  Completer<dynamic>? waiting;
  Map<String, dynamic> row = {
    'id': '1',
    'revision': 1,
    'status': 'DRAFT',
    'sourcesCurrent': true,
    'feedback': 'Keep revising at home.',
    'period': {'name': 'September 2026'},
    'student': {'fullName': 'Amina Hassan', 'admissionNo': 'AFQ-001'},
    'class': {'name': 'Level 1A'},
    'draft': snapshot(),
    'releases': <dynamic>[],
  };
  Future<dynamic> load(String path) async {
    loads.add(path);
    if (path.endsWith('/options')) {
      return {
        'classes': [
          {'id': '2', 'name': 'Level 1A'},
        ],
        'periods': [
          {'id': '3', 'name': 'September 2026'},
        ],
      };
    }
    if (path.contains('?')) {
      return {
        'items': [row],
        'meta': {'totalItems': 21},
        'stats': [
          {'status': row['status'], '_count': 21},
        ],
      };
    }
    return row;
  }

  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add((path, Map.of(body)));
    if (waiting != null) return waiting!.future;
    if (fail) throw const ApiException('Offline', 0);
    row = {
      ...row,
      'revision': (row['revision'] as int) + 1,
      'sourcesCurrent': true,
      if (body.containsKey('feedback')) 'feedback': body['feedback'],
      if (body.containsKey('feedback'))
        'draft': {...snapshot(), 'feedback': body['feedback']},
      if (body.containsKey('action'))
        'status': switch (body['action']) {
          'submit' => 'SUBMITTED',
          'publish' => 'PUBLISHED',
          _ => 'DRAFT',
        },
    };
    return row;
  }
}

Widget shell(Widget child) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);
Widget host(Fixture f, {bool admin = false}) =>
    shell(StudentReportsPage(load: f.load, submit: f.submit, admin: admin));
void screen(WidgetTester t, double width) {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> click(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> open(WidgetTester t, Fixture f, {bool admin = false}) async {
  await t.pumpWidget(host(f, admin: admin));
  await t.pumpAndSettle();
  await click(t, 'Preview');
}

Future<void> feedback(WidgetTester t, String text) async {
  final f = find.widgetWithText(TextField, 'Parent-facing teacher feedback');
  await t.ensureVisible(f);
  await t.enterText(f, text);
  await t.pump();
}

void main() {
  test('reports append without changing existing remembered routes', () {
    expect(sectionsForRole('TEACHER')[8].path, '/api/assessments');
    expect(sectionsForRole('TEACHER')[9].path, '/api/student-reports');
    expect(sectionsForRole('ADMIN')[11].path, '/api/student-reports');
    expect(sectionsForRole('PARENT')[8].path, '/family/academic');
    expect(sectionsForRole('PARENT')[9].path, '/family/reports');
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('teacher reports and preview fit width $width', (t) async {
      screen(t, width);
      final f = Fixture();
      await open(t, f);
      expect(find.text('Student Learning Report'), findsOneWidget);
      expect(find.text('Save & refresh draft'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'save retains feedback on failure then updates revision on retry',
    (t) async {
      screen(t, 1440);
      final f = Fixture()..fail = true;
      await open(t, f);
      await feedback(t, 'Work on sequence');
      await click(t, 'Save & refresh draft');
      expect(find.textContaining('Save not confirmed'), findsOneWidget);
      expect(
        t
            .widget<TextField>(
              find.widgetWithText(TextField, 'Parent-facing teacher feedback'),
            )
            .controller!
            .text,
        'Work on sequence',
      );
      expect(f.writes.single.$2, {
        'revision': 1,
        'feedback': 'Work on sequence',
      });
      f.fail = false;
      await click(t, 'Save & refresh draft');
      expect(f.writes.last.$2['revision'], 1);
      await click(t, 'Submit for review');
      expect(f.writes.length, 2);
      await click(t, 'Confirm');
      expect(f.writes.last.$2, {'revision': 2, 'action': 'submit'});
      expect(find.text('Save & refresh draft'), findsNothing);
    },
  );
  testWidgets('unsaved feedback requires explicit discard', (t) async {
    screen(t, 1440);
    final f = Fixture();
    await open(t, f);
    await feedback(t, 'Unsaved note');
    await t.tap(find.byTooltip('Close report'));
    await t.pumpAndSettle();
    expect(find.text('Discard unsaved feedback?'), findsOneWidget);
    await click(t, 'Keep editing');
    expect(find.byType(StudentReportEditor), findsOneWidget);
    await t.tap(find.byTooltip('Close report'));
    await t.pumpAndSettle();
    await click(t, 'Discard changes');
    expect(find.byType(StudentReportEditor), findsNothing);
    expect(f.writes, isEmpty);
  });
  testWidgets('source change blocks publication but permits return', (t) async {
    screen(t, 1440);
    final f = Fixture();
    f.row = {...f.row, 'status': 'SUBMITTED', 'sourcesCurrent': false};
    await open(t, f, admin: true);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Source records have changed'), findsOneWidget);
    final publish = find.ancestor(
      of: find.text('Publish report'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(t.widget<FilledButton>(publish).onPressed, isNull);
    await click(t, 'Return for corrections');
    expect(find.text('Reason'), findsWidgets);
    expect(f.writes, isEmpty);
  });
  testWidgets(
    'publication requires explicit confirmation and correct revision',
    (t) async {
      screen(t, 1440);
      final f = Fixture();
      f.row = {...f.row, 'status': 'SUBMITTED', 'revision': 4};
      await open(t, f, admin: true);
      await click(t, 'Publish report');
      expect(f.writes, isEmpty);
      await click(t, 'Confirm');
      expect(f.writes.single.$2, {'revision': 4, 'action': 'publish'});
      expect(find.text('Retract publication'), findsOneWidget);
    },
  );
  testWidgets('pending save disables repeated writes', (t) async {
    screen(t, 1440);
    final f = Fixture()..waiting = Completer();
    await open(t, f);
    final button = find.text('Save & refresh draft');
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    await t.tap(button);
    await t.pump();
    expect(f.writes.length, 1);
    f.waiting!.complete({...f.row, 'revision': 2});
    await t.pumpAndSettle();
  });
  testWidgets('staff pagination preserves filters in API request', (t) async {
    screen(t, 1440);
    final f = Fixture();
    await t.pumpWidget(host(f));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Next reports'));
    await t.tap(find.byTooltip('Next reports'));
    await t.pumpAndSettle();
    expect(f.loads, contains('/api/student-reports?page=2'));
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'parent published reports fit width $width and preview snapshot',
      (t) async {
        screen(t, width);
        Future<dynamic> load(String _) async => {
          'items': [
            {'id': '8', 'createdAt': '2026-09-21', 'snapshot': snapshot()},
          ],
          'meta': {'totalItems': 1},
        };
        await t.pumpWidget(shell(ParentReports(load: load, childId: '4')));
        await t.pumpAndSettle();
        await click(t, 'View report');
        expect(find.text('Student Learning Report'), findsOneWidget);
        expect(find.byType(LearningReportPreview), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('empty parent reports do not invent marks or download actions', (
    t,
  ) async {
    screen(t, 1440);
    await t.pumpWidget(
      shell(
        ParentReports(
          load: (_) async => {
            'items': [],
            'meta': {'totalItems': 0},
          },
          childId: '4',
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.textContaining('No published reports are available'),
      findsOneWidget,
    );
    expect(find.byType(ReportPdfButton), findsNothing);
  });
  testWidgets('changing child resets pagination and hides prior report', (
    t,
  ) async {
    screen(t, 1440);
    final paths = <String>[];
    Future<dynamic> load(String path) async {
      paths.add(path);
      return {
        'items': [],
        'meta': {'totalItems': 21},
      };
    }

    Widget parent(String id) => shell(ParentReports(load: load, childId: id));
    await t.pumpWidget(parent('4'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Next reports'));
    await t.tap(find.byTooltip('Next reports'));
    await t.pumpAndSettle();
    await t.pumpWidget(parent('5'));
    await t.pumpAndSettle();
    expect(paths.last, '/api/student-reports/children/5?page=1');
  });
}
