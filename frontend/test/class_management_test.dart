import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_forms.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/class_record_actions.dart';
import 'package:mif_app/src/classes_page.dart';

Map<String, dynamic> group() => {
  'id': '1',
  'name': 'Level 1A',
  'level': 'Foundation',
  'academicYear': '2026',
  'teacherId': '2',
  'teacher': {'id': '2', 'fullName': 'Ustadh Ali'},
  'capacity': 20,
  'revision': 'a' * 64,
  'canRemove': true,
  '_count': {},
  'history': <Map<String, dynamic>>[],
  'teacherOptions': [
    {'id': '2', 'fullName': 'Ustadh Ali'},
    {'id': '3', 'fullName': 'Ustadh Omar'},
  ],
  'branch': {'name': 'Main'},
  'stats': {'currentStudents': 0},
};

Finder field(String label) => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      (w.decoration?.labelText == label ||
          w.decoration?.labelText == '$label (optional)'),
);

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> actions(
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
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ClassRecordActions(
            schoolClass: group(),
            load: (_) async => record ?? group(),
            submit: submit ?? (_, _) async => {},
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byTooltip('Manage Level 1A'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'edit loads fresh values, clears capacity and preserves teacher ID',
    (tester) async {
      String? savedPath;
      Map<String, dynamic>? saved;
      var changes = 0;
      await actions(
        tester,
        record: {...group(), 'name': 'Fresh class'},
        submit: (path, body) async {
          savedPath = path;
          saved = body;
          return {};
        },
        onChanged: () => changes++,
      );
      await choose(tester, 'Edit class');
      expect(find.text('Fresh class'), findsOneWidget);
      await tester.enterText(field('Class name'), 'Updated class');
      await tester.enterText(field('Capacity'), '');
      await tester.enterText(
        field('Reason for this change'),
        'Correct details',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(savedPath, '/api/admin/classes/1/edit');
      expect(saved, {
        'revision': 'a' * 64,
        'reason': 'Correct details',
        'name': 'Updated class',
        'level': 'Foundation',
        'academicYear': '2026',
        'teacherId': '2',
        'capacity': null,
      });
      expect(changes, 1);
    },
  );

  testWidgets('teacher can be explicitly unassigned', (tester) async {
    Map<String, dynamic>? saved;
    await actions(
      tester,
      submit: (_, body) async {
        saved = body;
        return {};
      },
    );
    await choose(tester, 'Edit class');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not assigned').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Reason for this change'), 'Teacher transfer');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved!['teacherId'], isNull);
  });

  testWidgets(
    'remove warns of permanent deletion, requires reason and can be cancelled',
    (tester) async {
      var saves = 0;
      await actions(
        tester,
        submit: (_, _) async {
          saves++;
          return {};
        },
      );
      await choose(tester, 'Remove class');
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await tester.tap(find.text('Permanently remove class'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    },
  );

  testWidgets(
    'linked records explain why removal is blocked without a delete request',
    (tester) async {
      var saves = 0;
      await actions(
        tester,
        record: {
          ...group(),
          'canRemove': false,
          '_count': {'currentStudents': 4, 'feeStructures': 1, 'timetable': 2},
        },
        submit: (_, _) async {
          saves++;
          return {};
        },
      );
      await choose(tester, 'Remove class');
      expect(find.text('This class cannot be removed'), findsOneWidget);
      expect(find.text('Assigned students: 4'), findsOneWidget);
      expect(find.text('Fee structures: 1'), findsOneWidget);
      expect(find.text('Timetable records: 2'), findsOneWidget);
      expect(find.text('Permanently remove class'), findsNothing);
      expect(saves, 0);
    },
  );

  testWidgets(
    'stale or failed save retains entries and shows server conflict reason',
    (tester) async {
      var changes = 0;
      var attempts = 0;
      await actions(
        tester,
        submit: (_, _) async {
          attempts++;
          if (attempts == 1) {
            throw const ApiException(
              'Capacity cannot be lower than the number of assigned students.',
              409,
            );
          }
          return {};
        },
        onChanged: () => changes++,
      );
      await choose(tester, 'Edit class');
      await tester.enterText(field('Class name'), 'Unsaved class');
      await tester.enterText(
        field('Reason for this change'),
        'Correct details',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved class'), findsOneWidget);
      expect(
        find.text(
          'Capacity cannot be lower than the number of assigned students.',
        ),
        findsOneWidget,
      );
      expect(changes, 0);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(changes, 1);
    },
  );

  testWidgets(
    'remove handles records attached after opening confirmation without false success',
    (tester) async {
      var changes = 0;
      await actions(
        tester,
        submit: (_, _) async => throw const ApiException(
          'This class has changed. Close the form and open it again.',
          409,
        ),
        onChanged: () => changes++,
      );
      await choose(tester, 'Remove class');
      await tester.enterText(
        field('Reason for this change'),
        'Duplicate class',
      );
      await tester.tap(find.text('Permanently remove class'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Close the form and open it again.'),
        findsOneWidget,
      );
      expect(changes, 0);
    },
  );

  testWidgets('history shows actor, reason and before/after values', (
    tester,
  ) async {
    await actions(
      tester,
      record: {
        ...group(),
        'history': [
          {
            'createdAt': '2026-09-27T10:00:00Z',
            'actorUser': {'fullName': 'Office Admin'},
            'metadata': {
              'reason': 'Corrected spelling',
              'before': {'name': 'Old name'},
              'after': {'name': 'New name'},
            },
          },
        ],
      },
    );
    await choose(tester, 'Change history');
    expect(find.textContaining('Office Admin'), findsOneWidget);
    expect(find.text('Corrected spelling'), findsOneWidget);
    expect(find.text('Name: Old name to New name'), findsOneWidget);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('class edit and remove dialogs fit $width', (tester) async {
      await actions(tester, width: width);
      await choose(tester, 'Edit class');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage Level 1A'));
      await tester.pumpAndSettle();
      await choose(tester, 'Remove class');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('class directory reloads after confirmed deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var exists = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ClassesPage(
                load: (path) async => path.endsWith('/record')
                    ? group()
                    : (exists ? [group()] : []),
                submit: (path, body) async {
                  expect(path, '/api/admin/classes/1/remove');
                  expect(body, {
                    'revision': 'a' * 64,
                    'reason': 'Duplicate class',
                  });
                  exists = false;
                  return {'removed': true};
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final menu = find.byTooltip('Manage Level 1A');
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await choose(tester, 'Remove class');
    await tester.enterText(field('Reason for this change'), 'Duplicate class');
    await tester.tap(find.text('Permanently remove class'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage Level 1A'), findsNothing);
    expect(find.text('No classes match your search.'), findsOneWidget);
  });

  testWidgets('read-only classes have no admin mutation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ClassesPage(load: (_) async => [group()]),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClassRecordActions), findsNothing);
    expect(find.text('Create class'), findsNothing);
    expect(find.byTooltip('Manage timetable'), findsNothing);
  });
}
