import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_workspace.dart';

void main() {
  testWidgets('edits stay in workspace and save to selected lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final writes = <Map<String, dynamic>>[];
    var failSave = false;
    Future<dynamic> load(String path) async {
      if (path == '/api/teaching/courses') {
        return [
          {'id': '1', 'title': 'Sample course'},
        ];
      }
      if (path.endsWith('/modules')) {
        return [
          {'id': '2', 'title': 'Getting started', 'position': 1},
        ];
      }
      if (path.endsWith('/lessons')) {
        return [
          {
            'id': '3',
            'title': 'Sample lesson',
            'contentText': 'Original notes',
            'publicationStatus': 'DRAFT',
          },
          {
            'id': '4',
            'title': 'Second lesson',
            'contentText': 'Second notes',
            'publicationStatus': 'DRAFT',
          },
        ];
      }
      return <Map<String, dynamic>>[];
    }

    Widget app() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeacherCourseWorkspace(
            load: load,
            submit: (_, body) async => body,
            update: (path, body) async {
              if (failSave) throw StateError('Simulated connection failure');
              writes.add({'path': path, ...body});
              return body;
            },
            onPreview: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Course outline'), findsOneWidget);
    expect(find.text('Edit lesson'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Original notes'),
      'Revised notes',
    );
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-3')));
    await tester.pumpAndSettle();
    expect(find.text('Save your lesson changes?'), findsNothing);
    expect(find.text('Revised notes'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(writes, isEmpty);
    final lessonList = tester
        .widgetList<ReorderableListView>(find.byType(ReorderableListView))
        .last;
    lessonList.onReorder(0, 2);
    await tester.pumpAndSettle();
    expect(writes.single['path'], '/api/courses/modules/2/lessons/order');
    expect(writes.single['ids'], ['4', '3']);
    expect(writes.single['expectedIds'], ['3', '4']);
    expect(find.text('Revised notes'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    writes.clear();
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Revised notes'), findsOneWidget);
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(writes.single['path'], '/api/courses/lessons/3');
    expect(writes.single['contentText'], 'Revised notes');
    expect(find.text('Unsaved changes'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'Revised notes'),
      'Keep these changes',
    );
    await tester.ensureVisible(find.text('Second lesson'));
    await tester.tap(find.text('Second lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Keep these changes'), findsOneWidget);

    failSave = true;
    await tester.tap(find.text('Second lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(find.text('Keep these changes'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.textContaining('Your edits are still here'), findsOneWidget);

    failSave = false;
    await tester.tap(find.text('Second lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(writes.last['path'], '/api/courses/lessons/3');
    expect(writes.last['contentText'], 'Keep these changes');
    expect(find.text('Second notes'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lesson-3')));
    await tester.pumpAndSettle();
    expect(find.text('Keep these changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
