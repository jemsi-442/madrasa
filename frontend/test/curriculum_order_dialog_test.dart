import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_lesson_dialog.dart';
import 'package:mif_app/src/curriculum_topic_dialog.dart';

void main() {
  testWidgets('topic order can move into an unoccupied position', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const CurriculumTopicDialog(
                    position: 3,
                    maxPosition: 4,
                    occupiedPositions: [1, 3],
                    topic: {
                      'id': 'topic-3',
                      'title': 'Letters',
                      'position': 3,
                      'objectives': [],
                    },
                  ),
                );
              },
              child: const Text('Open topic'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Position 2'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson order offers only free positions and current position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const CurriculumLessonDialog(
                  topics: [],
                  position: 3,
                  maxPosition: 4,
                  occupiedPositions: [1, 3],
                  lesson: {
                    'title': 'Practice',
                    'activities': 'Read and repeat the target sounds.',
                    'durationMinutes': 20,
                    'position': 3,
                    'objectives': [],
                  },
                ),
              ),
              child: const Text('Open lesson'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('Position 1'), findsNothing);
    expect(find.text('Position 2'), findsOneWidget);
    expect(find.text('Position 3'), findsNWidgets(2));
    expect(find.text('Position 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
