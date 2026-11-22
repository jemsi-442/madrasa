import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/src/teacher_course_workspace.dart';

void main() {
  testWidgets('edits stay in workspace and save to selected lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final writes = <Map<String, dynamic>>[];
    Future<dynamic> load(String path) async {
      if (path == '/api/teaching/courses')
        return [
          {'id': '1', 'title': 'Sample course'},
        ];
      if (path.endsWith('/modules'))
        return [
          {'id': '2', 'title': 'Getting started', 'position': 1},
        ];
      if (path.endsWith('/lessons'))
        return [
          {
            'id': '3',
            'title': 'Sample lesson',
            'contentText': 'Original notes',
            'publicationStatus': 'DRAFT',
          },
        ];
      return <Map<String, dynamic>>[];
    }

    Widget app() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeacherCourseWorkspace(
            load: load,
            submit: (_, body) async => body,
            update: (path, body) async {
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
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Revised notes'), findsOneWidget);
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(writes.single['path'], '/api/courses/lessons/3');
    expect(writes.single['contentText'], 'Revised notes');
    expect(find.text('Unsaved changes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
