import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_lesson_access.dart';

void main() {
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
