import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_lesson_dialog.dart';

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('lesson selects multiple objectives at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => const CurriculumLessonDialog(
                      position: 1,
                      topics: [
                        {
                          'title': 'Reading',
                          'objectives': [
                            {
                              'id': 'o1',
                              'code': 'READ-1',
                              'description': 'Recognise letters',
                            },
                            {
                              'id': 'o2',
                              'code': 'READ-2',
                              'description': 'Read words',
                            },
                          ],
                        },
                      ],
                      lesson: {
                        'title': 'Reading practice',
                        'durationMinutes': 40,
                        'activities': 'Read together and practise individually',
                        'objectives': [],
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lesson'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Select at least one objective'), findsOneWidget);
      for (final label in [
        'READ-1 - Recognise letters',
        'READ-2 - Read words',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save lesson'));
      await tester.pumpAndSettle();
      expect(saved?['objectiveIds'], ['o1', 'o2']);
      expect(saved?['durationMinutes'], 40);
      expect(tester.takeException(), isNull);
    });
  }
}
