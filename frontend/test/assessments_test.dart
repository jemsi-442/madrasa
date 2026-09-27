import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/assessments_page.dart';
import 'package:mif_app/src/parent_academics.dart';
import 'package:mif_app/src/workspace.dart';

class Fixture {
  final loads = <String>[];
  final writes = <(String, Map<String, dynamic>)>[];
  bool fail = false;
  Completer<dynamic>? waiting;
  Map<String, dynamic> row = {
    'id': '1',
    'revision': 1,
    'status': 'DRAFT',
    'title': 'Wudu practical',
    'assessedOn': '2026-09-20',
    'maxScore': 10,
    'class': {'id': '2', 'name': 'Level 2A'},
    'subject': {'id': '3', 'name': 'Fiqh'},
    'results': [
      {
        'studentId': '4',
        'score': null,
        'feedback': '',
        'student': {
          'id': '4',
          'fullName': 'Amina Hassan',
          'admissionNo': 'AFQ-001',
        },
      },
      {
        'studentId': '5',
        'score': 7,
        'feedback': 'Needs practice',
        'student': {
          'id': '5',
          'fullName': 'Yusuf Ali',
          'admissionNo': 'AFQ-002',
        },
      },
    ],
  };
  Future<dynamic> load(String path) async {
    loads.add(path);
    if (path.endsWith('/options')) {
      return {
        'classes': [
          {'id': '2', 'name': 'Level 2A'},
        ],
        'subjects': [
          {'id': '3', 'name': 'Fiqh'},
        ],
      };
    }
    if (path.contains('?')) {
      return {
        'items': [
          {
            ...row,
            '_count': {'results': 2},
          },
        ],
        'meta': {'totalItems': 21},
      };
    }
    return row;
  }

  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add((path, Map.of(body)));
    if (waiting != null) return waiting!.future;
    if (fail) throw const ApiException('Offline', 0);
    final next = {...row, 'revision': (row['revision'] as int) + 1};
    if (path.endsWith('/results')) {
      next['results'] = [
        for (final raw in body['results'] as List)
          {
            ...Map<String, dynamic>.from(raw as Map),
            'student': (row['results'] as List).firstWhere(
              (r) => r['studentId'] == raw['studentId'],
            )['student'],
          },
      ];
    }
    if (body['action'] != null) {
      next['status'] = switch (body['action']) {
        'submit' => 'SUBMITTED',
        'publish' => 'PUBLISHED',
        _ => 'DRAFT',
      };
    }
    if (body['reason'] != null) next['reviewNote'] = body['reason'];
    row = next;
    return row;
  }
}

Widget host(Fixture f, {bool admin = false}) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AssessmentsPage(load: f.load, submit: f.submit, admin: admin),
      ),
    ),
  ),
);
void screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> click(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> opened(
  WidgetTester tester,
  Fixture f, {
  bool admin = false,
}) async {
  await tester.pumpWidget(host(f, admin: admin));
  await tester.pumpAndSettle();
  await click(tester, 'Open');
}

Future<void> input(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Map<String, dynamic> academics({bool empty = false, int score = 80}) => {
  'student': {'id': '4', 'fullName': 'Amina Hassan'},
  'year': DateTime.now().year,
  'average': empty ? null : score,
  'policy':
      'Each assessment contributes equally. This is not a term grade or class rank.',
  'subjects': empty
      ? []
      : [
          {'id': '3', 'name': 'Fiqh', 'average': score, 'assessments': 1},
        ],
  'records': empty
      ? []
      : [
          {
            'id': '10',
            'title': 'Wudu practical',
            'subject': {'id': '3', 'name': 'Fiqh'},
            'score': score ~/ 10,
            'maxScore': 10,
            'percent': score,
            'assessedOn': '2026-09-20',
            'publishedAt': '2026-09-21',
            'teacher': 'Ustadh Ahmad',
            'feedback': 'Correct sequence',
          },
        ],
};
Widget parentHost(
  Future<dynamic> Function(String) load, {
  String child = '4',
}) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ParentAcademics(load: load, childId: child),
      ),
    ),
  ),
);

void main() {
  test(
    'role navigation exposes assessment workflow only to appropriate roles',
    () {
      expect(sectionsForRole('TEACHER')[8].title, 'Assessments');
      expect(sectionsForRole('ADMIN')[10].title, 'Assessment Review');
      expect(sectionsForRole('PARENT')[8].title, 'Academic Progress');
      expect(
        sectionsForRole('ACCOUNTANT').any((s) => s.path == '/api/assessments'),
        false,
      );
    },
  );
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('assessment editor and parent progress fit $width', (
      tester,
    ) async {
      screen(tester, width);
      final f = Fixture();
      await opened(tester, f);
      expect(find.text('Save draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close assessment'));
      await tester.pumpAndSettle();
      await click(tester, 'New assessment');
      expect(find.text('Assessment title'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(parentHost((_) async => academics()));
      await tester.pumpAndSettle();
      expect(find.text('Subject performance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('draft saves distinguish blank and zero and advance revision', (
    tester,
  ) async {
    screen(tester, 1440);
    final f = Fixture();
    await opened(tester, f);
    await input(tester, 'score-4', '0');
    await input(tester, 'score-5', '');
    await input(tester, 'feedback-4', 'Good participation');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Submit for review'),
          )
          .onPressed,
      isNull,
    );
    await click(tester, 'Save draft');
    expect(f.writes.single.$2, {
      'revision': 1,
      'results': [
        {'studentId': '4', 'score': 0, 'feedback': 'Good participation'},
        {'studentId': '5', 'score': null, 'feedback': 'Needs practice'},
      ],
    });
    expect(find.text('Saved to the school server.'), findsOneWidget);
    await input(tester, 'score-5', '6');
    await click(tester, 'Save draft');
    expect(f.writes.last.$2['revision'], 2);
  });
  testWidgets('invalid scores do not submit; failed save keeps typed marks', (
    tester,
  ) async {
    screen(tester, 1440);
    final f = Fixture()..fail = true;
    await opened(tester, f);
    await input(tester, 'score-4', '11');
    await click(tester, 'Save draft');
    expect(f.writes, isEmpty);
    expect(find.textContaining('whole-number scores'), findsOneWidget);
    await input(tester, 'score-4', '8');
    await click(tester, 'Save draft');
    expect(find.textContaining('Save not confirmed'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('score-4')))
          .controller!
          .text,
      '8',
    );
    f.fail = false;
    await click(tester, 'Save draft');
    expect(f.writes.first.$2, f.writes.last.$2);
    expect(find.text('Saved to the school server.'), findsOneWidget);
  });
  testWidgets('unsaved drafts require explicit discard', (tester) async {
    screen(tester, 1440);
    final f = Fixture();
    await opened(tester, f);
    await input(tester, 'score-4', '8');
    await tester.tap(find.byTooltip('Close assessment'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved marks?'), findsOneWidget);
    await click(tester, 'Keep editing');
    expect(find.byKey(const ValueKey('score-4')), findsOneWidget);
    await tester.tap(find.byTooltip('Close assessment'));
    await tester.pumpAndSettle();
    await click(tester, 'Discard changes');
    expect(find.byType(AssessmentEditor), findsNothing);
    expect(f.writes, isEmpty);
  });
  testWidgets('teacher confirms submit and cannot publish', (tester) async {
    screen(tester, 1440);
    final f = Fixture();
    await opened(tester, f);
    await click(tester, 'Submit for review');
    expect(find.text('Submit for review?'), findsOneWidget);
    await click(tester, 'Cancel');
    expect(f.writes, isEmpty);
    await click(tester, 'Submit for review');
    await click(tester, 'Confirm');
    expect(f.writes.single.$2, {'revision': 1, 'action': 'submit'});
    expect(find.text('Save draft'), findsNothing);
    expect(find.text('Publish results'), findsNothing);
  });
  testWidgets(
    'admin cannot edit marks and confirms publication then gives retraction reason',
    (tester) async {
      screen(tester, 1440);
      final f = Fixture();
      f.row['status'] = 'SUBMITTED';
      await opened(tester, f, admin: true);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('score-4')))
            .readOnly,
        true,
      );
      expect(find.text('Save draft'), findsNothing);
      await click(tester, 'Publish results');
      expect(find.text('Publish these results?'), findsOneWidget);
      await click(tester, 'Confirm');
      expect(f.writes.single.$2['action'], 'publish');
      await click(tester, 'Retract publication');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'Correct transcription',
      );
      await click(tester, 'Continue');
      expect(f.writes.last.$2, {
        'revision': 2,
        'action': 'retract',
        'reason': 'Correct transcription',
      });
      expect(find.text('Publish results'), findsNothing);
    },
  );
  testWidgets('in-flight save disables duplicate submission and close', (
    tester,
  ) async {
    screen(tester, 1440);
    final f = Fixture()..waiting = Completer();
    await opened(tester, f);
    await input(tester, 'score-4', '8');
    await tester.tap(find.text('Save draft'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Close assessment',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Saving...'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(f.writes, hasLength(1));
    f.waiting!.complete({...f.row, 'revision': 2});
    await tester.pumpAndSettle();
  });
  testWidgets(
    'parent empty state has no invented grade and zero is a real result',
    (tester) async {
      screen(tester, 1440);
      await tester.pumpWidget(parentHost((_) async => academics(empty: true)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No published assessment results'),
        findsOneWidget,
      );
      expect(find.text('Not available'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(parentHost((_) async => academics(score: 0)));
      await tester.pumpAndSettle();
      expect(find.text('Not available'), findsNothing);
      expect(find.text('0%'), findsWidgets);
    },
  );
  testWidgets('switching children hides old academic results while loading', (
    tester,
  ) async {
    screen(tester, 1440);
    final pending = Completer<dynamic>();
    Future<dynamic> load(String path) async =>
        path.contains('/5/') ? pending.future : academics();
    await tester.pumpWidget(parentHost(load));
    await tester.pumpAndSettle();
    expect(find.text('Correct sequence'), findsOneWidget);
    await tester.pumpWidget(parentHost(load, child: '5'));
    await tester.pump();
    expect(find.text('Correct sequence'), findsNothing);
    pending.complete(academics(empty: true));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No published assessment results'),
      findsOneWidget,
    );
  });
  testWidgets('assessment pagination fetches the next server page', (
    tester,
  ) async {
    screen(tester, 1440);
    final f = Fixture();
    await tester.pumpWidget(host(f));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(f.loads, contains('/api/assessments?page=2'));
  });
  testWidgets(
    'new assessment retries with the same request ID and selected school records',
    (tester) async {
      screen(tester, 1440);
      final f = Fixture()..fail = true;
      await tester.pumpWidget(host(f));
      await tester.pumpAndSettle();
      await click(tester, 'New assessment');
      final choices = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.tap(choices.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 2A').last);
      await tester.pumpAndSettle();
      await tester.tap(choices.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fiqh').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Assessment title'),
        'Wudu practical',
      );
      await click(tester, 'Save');
      expect(f.writes, hasLength(1));
      expect(find.byType(AssessmentEditor), findsNothing);
      f.fail = false;
      await click(tester, 'Save');
      expect(f.writes, hasLength(2));
      expect(f.writes.first.$2, f.writes.last.$2);
      expect(f.writes.last.$2['classId'], '2');
      expect(f.writes.last.$2['subjectId'], '3');
      expect(f.writes.last.$2['maxScore'], 10);
      expect(f.writes.last.$2['clientId'], matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(find.byType(AssessmentEditor), findsOneWidget);
    },
  );
}
