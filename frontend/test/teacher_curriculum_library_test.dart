import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/school_curriculum_page.dart';

Map<String, dynamic> assignment(
  String id,
  String subject,
  String year, {
  int taught = 1,
}) => {
  'id': id,
  'version': {
    'subject': subject,
    'level': 'Level 1',
    'version': '1.0',
    'description': 'Synthetic teaching framework',
    'topics': [
      {
        'title': 'Foundations',
        'objectives': [
          {
            'code': '$id-1',
            'description': 'Read words',
            'assessmentMethod': 'Observation',
            'criteria': 'Read independently',
          },
        ],
      },
    ],
    'lessons': [
      {
        'id': 'lesson-$id',
        'title': '$subject practice',
        'durationMinutes': 20,
        'activities': 'Guided practice',
        'objectives': [],
      },
    ],
  },
  'adoptions': [
    {
      'id': 'adoption-$id',
      'class': {'id': id, 'name': 'Class $id', 'academicYear': year},
      'subject': {'name': subject},
      'history': [],
      'teachingCoverage': {'taughtLessons': taught, 'totalLessons': 1},
    },
  ],
};

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('teacher library filters and opens real plans at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchoolCurriculumPage(
              isAdmin: false,
              load: (_) async => {
                'classes': [],
                'subjects': [],
                'assignments': [
                  assignment('1', 'Arabic', '2026', taught: 0),
                  assignment('2', 'Fiqh', '2027'),
                ],
              },
              submit: (_, _) async {
                writes++;
                return {};
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Curriculum'), findsOneWidget);
      expect(find.text('Learning objectives'), findsOneWidget);
      expect(find.text('Resources'), findsNothing);
      expect(find.text('Taught 0 of 1 lessons'), findsOneWidget);
      expect(find.text('Taught 1 of 1 lessons'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Arabic practice');
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('Fiqh'), findsNothing);
      await tester.ensureVisible(find.text('View lessons'));
      await tester.tap(find.text('View lessons'));
      await tester.pumpAndSettle();
      expect(find.text('Guided practice'), findsOneWidget);
      expect(find.text('Record lesson taught'), findsOneWidget);
      expect(writes, 0);
      await tester.ensureVisible(find.text('My assigned curriculum'));
      await tester.tap(find.text('My assigned curriculum'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Arabic practice',
      );
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsNothing);
      expect(find.text('Fiqh'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'No match');
      await tester.pumpAndSettle();
      expect(find.text('No curriculum matches these filters.'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('Fiqh'), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
