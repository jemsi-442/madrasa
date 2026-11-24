import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_workspace.dart';

// Simulates an expansion flag left in page storage by an earlier widget tree.
class _ExpansionStateBucket extends PageStorageBucket {
  @override
  dynamic readState(BuildContext context, {Object? identifier}) {
    if (context.widget is ExpansionTile ||
        context.findAncestorWidgetOfExactType<ReorderableListView>() != null) {
      return true;
    }
    return super.readState(context, identifier: identifier);
  }
}

void main() {
  testWidgets('created module is visible despite active outline filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var createAttempts = 0;
    final creation = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherCourseWorkspace(
              load: (path) async => path == '/api/teaching/courses'
                  ? [
                      {'id': 'c1', 'title': 'Sample course'},
                    ]
                  : <Map<String, dynamic>>[],
              submit: (_, body) async {
                createAttempts++;
                if (createAttempts == 1) throw StateError('Connection failed');
                return creation.future;
              },
              update: (_, body) async => body,
              onPreview: (_, _, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('outline-search')),
      'missing',
    );
    await tester.tap(find.byKey(const ValueKey('outline-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Published').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add module'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a title of at least two characters.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'New module',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Your title is still here'), findsOneWidget);
    expect(find.text('New module'), findsOneWidget);
    expect(createAttempts, 1);
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(createAttempts, 2);
    expect(find.text('Creating...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Creating...'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    creation.complete({'id': 'm1', 'title': 'New module', 'position': 1});
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('New module'), findsOneWidget);
    expect(find.text('All statuses'), findsOneWidget);
    expect(
      find.text('Filtered outline. Clear filters to reorder.'),
      findsNothing,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('outline-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow outline survives expansion and status filtering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PageStorage(
              bucket: _ExpansionStateBucket(),
              child: TeacherCourseWorkspace(
                load: (path) async {
                  if (path == '/api/teaching/courses') {
                    return [
                      {'id': 'c1', 'title': 'Sample course'},
                    ];
                  }
                  if (path.endsWith('/modules')) {
                    return [
                      {'id': 'm1', 'title': 'Practice module', 'position': 1},
                    ];
                  }
                  if (path.endsWith('/lessons')) {
                    return [
                      {
                        'id': 'l1',
                        'title': 'Practice lesson',
                        'publicationStatus': 'DRAFT',
                      },
                    ];
                  }
                  return <Map<String, dynamic>>[];
                },
                submit: (_, body) async => body,
                update: (_, body) async => body,
                onPreview: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Practice module').first);
      await tester.tap(find.text('Practice module').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    for (final label in ['Draft', 'All statuses']) {
      final filter = find.byKey(const ValueKey('outline-status'));
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lesson-l1')), findsOneWidget);
    }
  });

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
          child: PageStorage(
            bucket: _ExpansionStateBucket(),
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
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Course outline'), findsOneWidget);
    expect(find.text('Edit lesson'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Total lessons')).dy,
      lessThan(tester.getTopLeft(find.text('Selected course')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Selected course')).dy,
      lessThan(tester.getTopLeft(find.text('Course outline')).dy),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Getting started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Getting started'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lesson-3')), findsOneWidget);
    }
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
    await tester.enterText(
      find.byKey(const ValueKey('outline-search')),
      'second',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-3')), findsNothing);
    expect(find.byKey(const ValueKey('lesson-4')), findsOneWidget);
    expect(find.text('Revised notes'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    for (final list in tester.widgetList<ReorderableListView>(
      find.byType(ReorderableListView),
    )) {
      list.onReorder(0, 1);
    }
    expect(writes, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('outline-search')),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No modules or lessons match these filters.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('outline-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outline-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Published').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-3')), findsNothing);
    expect(find.text('Revised notes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('outline-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All statuses').last);
    await tester.pumpAndSettle();
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
