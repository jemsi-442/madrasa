import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/student_record_actions.dart';
import 'package:mif_app/src/student_registry_page.dart';

Map<String, dynamic> student({String status = 'ACTIVE'}) => {
  'id': '1',
  'fullName': 'Ali Hassan',
  'admissionNo': 'AFQ-001',
  'status': status,
  'programCategory': 'MADRASA_CHILD',
  'gender': 'male',
  'dob': '2016-01-12T00:00:00.000Z',
  'joinedOn': null,
  'notes': 'Old note',
  'revision': 'a' * 64,
  'history': <Map<String, dynamic>>[],
};

Finder field(String label) => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      (w.decoration?.labelText == label ||
          w.decoration?.labelText == '$label (optional)'),
);

Future<void> showActions(
  WidgetTester tester, {
  Map<String, dynamic>? record,
  PageSubmitter? submit,
  VoidCallback? onChanged,
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final value = record ?? student();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StudentRecordActions(
            student: value,
            load: (_) async => value,
            submit: submit ?? (_, _) async => {},
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byTooltip('Manage Ali Hassan'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'edit preloads fresh details and sends explicit nulls for cleared fields',
    (tester) async {
      String? savedPath;
      Map<String, dynamic>? savedBody;
      var changes = 0;
      await showActions(
        tester,
        submit: (path, body) async {
          savedPath = path;
          savedBody = body;
          return {};
        },
        onChanged: () => changes++,
      );
      await choose(tester, 'Edit student');
      expect(find.text('AFQ-001'), findsOneWidget);
      expect(find.text('2016-01-12'), findsOneWidget);
      await tester.enterText(field('Full name'), 'Ali Updated');
      await tester.enterText(field('Date of birth (YYYY-MM-DD)'), '');
      await tester.enterText(field('Notes'), '');
      await tester.enterText(
        field('Reason for this change'),
        'Corrected admission form',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(savedPath, '/api/admin/students/1/edit');
      expect(savedBody, {
        'revision': 'a' * 64,
        'reason': 'Corrected admission form',
        'fullName': 'Ali Updated',
        'admissionNo': 'AFQ-001',
        'gender': 'male',
        'dob': null,
        'joinedOn': null,
        'notes': null,
      });
      expect(changes, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'archive requires confirmation and a reason; cancel does not mutate',
    (tester) async {
      var saves = 0;
      await showActions(
        tester,
        submit: (_, _) async {
          saves++;
          return {};
        },
      );
      await choose(tester, 'Remove student');
      expect(
        find.textContaining('Learning and payment history will be kept'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Remove student'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    },
  );

  testWidgets('archive and restore use separate backend operations', (
    tester,
  ) async {
    final requests = <String>[];
    for (final status in ['ACTIVE', 'INACTIVE']) {
      final label = status == 'ACTIVE' ? 'Remove student' : 'Restore student';
      await tester.pumpWidget(const SizedBox());
      await showActions(
        tester,
        record: student(status: status),
        submit: (path, body) async {
          requests.add(path);
          expect(body.keys.toSet(), {'revision', 'reason'});
          return {};
        },
      );
      await choose(tester, label);
      await tester.enterText(field('Reason for this change'), 'Family request');
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();
    }
    expect(requests, [
      '/api/admin/students/1/archive',
      '/api/admin/students/1/restore',
    ]);
  });

  testWidgets(
    'failed or stale saves retain entries and do not report success',
    (tester) async {
      var changes = 0;
      await showActions(
        tester,
        submit: (_, _) async => throw const ApiException('Changed record', 409),
        onChanged: () => changes++,
      );
      await choose(tester, 'Edit student');
      await tester.enterText(field('Full name'), 'Unsaved Name');
      await tester.enterText(field('Reason for this change'), 'Correct record');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved Name'), findsOneWidget);
      expect(find.textContaining('close this form and reopen'), findsOneWidget);
      expect(changes, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets('history shows actor, reason and changed values', (tester) async {
    final record = student();
    record['history'] = [
      {
        'action': 'student.admin_edit',
        'createdAt': '2026-09-25T10:00:00Z',
        'actorUser': {'fullName': 'Office Admin'},
        'metadata': {
          'reason': 'Corrected spelling',
          'before': {'fullName': 'Ali Hasaan'},
          'after': {'fullName': 'Ali Hassan'},
        },
      },
    ];
    await showActions(tester, record: record);
    await choose(tester, 'Change history');
    expect(find.textContaining('Office Admin'), findsOneWidget);
    expect(find.text('Corrected spelling'), findsOneWidget);
    expect(find.text('Name: Ali Hasaan to Ali Hassan'), findsOneWidget);
  });

  testWidgets(
    'online learner lifecycle is not confused with school archiving',
    (tester) async {
      await showActions(
        tester,
        record: {...student(), 'programCategory': 'COURSE_STUDENT'},
      );
      expect(find.text('Edit student'), findsOneWidget);
      expect(find.text('Remove student'), findsNothing);
      expect(find.text('Restore student'), findsNothing);
    },
  );

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('management form fits $width', (tester) async {
      await showActions(tester, width: width);
      await choose(tester, 'Edit student');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'admin directory defaults to active students and removal reloads that filter',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var active = true;
      final requests = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StudentRegistryPage(
                  load: (path) async {
                    final uri = Uri.parse(path);
                    if (uri.path == '/api/classes') return [];
                    if (uri.path.endsWith('/summary')) return {};
                    if (uri.path.endsWith('/record')) return student();
                    requests.add(uri);
                    return {
                      'items': active ? [student()] : [],
                      'meta': {'totalItems': active ? 1 : 0, 'totalPages': 1},
                    };
                  },
                  submit: (path, body) async {
                    expect(path, '/api/admin/students/1/archive');
                    expect(body['reason'], 'Family requested removal');
                    active = false;
                    return {};
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['status'], 'ACTIVE');
      final menu = find.byTooltip('Manage Ali Hassan');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await choose(tester, 'Remove student');
      expect(find.textContaining('not permanently deleted'), findsOneWidget);
      await tester.enterText(
        field('Reason for this change'),
        'Family requested removal',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Remove student'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['status'], 'ACTIVE');
      expect(find.byTooltip('Manage Ali Hassan'), findsNothing);
      expect(find.text('No students match these filters.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only student directory has no admin mutation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              StudentRegistryPage(
                load: (path) async => path == '/api/classes'
                    ? []
                    : {
                        'items': [student()],
                        'meta': {'totalItems': 1, 'totalPages': 1},
                      },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StudentRecordActions), findsNothing);
    expect(find.text('Add student'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
