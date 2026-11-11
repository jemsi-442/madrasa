import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/student_course_progress.dart';
import 'package:mif_app/src/teacher_students_page.dart';
import 'lesson_media_flow_test.dart' show host;

void main() {
  testWidgets(
    'teacher profile loads the scoped course summary without writing',
    (t) async {
      final paths = <String>[];
      await host(
        t,
        TeacherStudentProfile(
          studentId: '42',
          load: (path) async {
            paths.add(path);
            return {
              'student': {
                'id': '42',
                'fullName': 'Synthetic learner',
                'admissionNo': 'TEST-42',
                'currentClass': {'name': 'Synthetic class'},
              },
              'courseProgress': {
                'linked': true,
                'trackedLessons': 7,
                'completedLessons': 2,
                'recent': [],
              },
              'supportNotes': [],
              'sessions': [],
            };
          },
          submit: (_, _) async =>
              throw StateError('Read-only summary must not write'),
        ),
        width: 1100,
      );
      expect(paths, ['/api/teacher-workspace/students/42']);
      expect(find.text('Course activity'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'read-only learner activity is distinct from assessment at $width',
      (t) async {
        await host(
          t,
          const StudentCourseProgress(
            data: {
              'linked': true,
              'trackedLessons': 12,
              'completedLessons': 4,
              'recent': [
                {
                  'course': {'title': 'Sample course'},
                  'lesson': {'title': 'Practice one'},
                  'progressPercent': 100,
                  'completedAt': '2026-01-01T00:00:00Z',
                  'updatedAt': '2026-01-01T00:00:00Z',
                },
                {
                  'course': {'title': 'Sample course'},
                  'lesson': {'title': 'Practice two'},
                  'progressPercent': 30,
                  'updatedAt': '2026-01-02T00:00:00Z',
                },
              ],
            },
          ),
          width: width,
          scale: 2,
        );
        expect(
          find.textContaining('not teacher-assessed achievement'),
          findsOneWidget,
        );
        expect(find.text('Latest 2 of 12 recorded lessons'), findsOneWidget);
        expect(find.text('Marked complete by learner'), findsOneWidget);
        expect(find.text('30% reported'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('missing link and empty activity have different explanations', (
    t,
  ) async {
    await host(
      t,
      const StudentCourseProgress(data: {'linked': false}),
      width: 390,
    );
    expect(
      find.text('No learner login is linked to this student yet.'),
      findsOneWidget,
    );
    await host(
      t,
      const StudentCourseProgress(data: {'linked': true, 'trackedLessons': 0}),
      width: 390,
    );
    expect(
      find.textContaining('Classroom learning is tracked separately'),
      findsOneWidget,
    );
    await host(t, const StudentCourseProgress(data: {}), width: 390);
    expect(find.text('Course activity is unavailable.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
