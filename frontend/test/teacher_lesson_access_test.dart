import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_lesson_access.dart';

void main() {
  testWidgets('Failed publication keeps selected access for retry', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonAccess(
            lesson: {
              'id': '42',
              'publicationStatus': 'DRAFT',
              'visibility': 'LOCKED',
            },
            update: (_, body) async {
              writes.add(body);
              if (writes.length == 1) throw Exception('offline');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Publish lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available to course learners').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish lesson').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Your selection is kept'), findsOneWidget);
    expect(find.text('Draft lesson'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish lesson').last);
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes.last, writes.first);
    expect(writes.last['visibility'], 'FREE');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Lesson published'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hide keeps resources and publishes only after confirmation', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonAccess(
            lesson: {
              'id': '42',
              'publicationStatus': 'PUBLISHED',
              'visibility': 'FREE',
            },
            course: {
              'publicationStatus': 'DRAFT',
              'programme': 'MADRASA_CHILD',
            },
            update: (path, body) async {
              expect(path, '/api/courses/lessons/42');
              writes.add(body);
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('Course is not published'), findsOneWidget);
    await tester.tap(find.text('Hide from learners'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.text('Hide lesson'));
    await tester.pumpAndSettle();
    expect(writes.single, {'publicationStatus': 'DRAFT'});
    expect(find.text('Draft lesson'), findsOneWidget);
    await tester.tap(find.text('Publish lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish lesson').last);
    await tester.pumpAndSettle();
    expect(writes.last, {
      'publicationStatus': 'PUBLISHED',
      'visibility': 'FREE',
    });
    expect(find.text('Lesson published'), findsOneWidget);
  });

  testWidgets('Failed save preserves status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonAccess(
            lesson: {
              'id': '42',
              'publicationStatus': 'PUBLISHED',
              'visibility': 'FREE',
            },
            update: (_, _) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hide from learners'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Lesson published'), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  for (final entry in <String, String>{
    'DRAFT': 'Draft lesson',
    'ARCHIVED': 'Archived lesson',
    'PUBLISHED': 'Lesson published',
    'UNKNOWN': 'Publication status unavailable',
  }.entries) {
    testWidgets('Shows ${entry.key} without claiming learner eligibility', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherLessonAccess(
              lesson: {'publicationStatus': entry.key, 'visibility': 'FREE'},
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Published locked lesson remains blocked on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonAccess(
            lesson: {'publicationStatus': 'PUBLISHED', 'visibility': 'LOCKED'},
          ),
        ),
      ),
    );
    expect(find.text('Published, but locked'), findsOneWidget);
    expect(find.textContaining('cannot open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
