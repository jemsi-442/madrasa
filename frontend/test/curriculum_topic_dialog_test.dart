import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_topic_dialog.dart';

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('topic edit preserves measurable fields at $width', (
      tester,
    ) async {
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
                    builder: (_) => const CurriculumTopicDialog(
                      position: 1,
                      topic: {
                        'title': 'Taharah',
                        'objectives': [
                          {
                            'code': 'FIQH-1',
                            'description': 'Demonstrate the approved sequence',
                            'assessmentMethod': 'PRACTICAL',
                            'criteria':
                                'Complete the steps in the approved order',
                          },
                        ],
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
      expect(find.text('Taharah'), findsOneWidget);
      await tester.tap(find.text('Save topic'));
      await tester.pumpAndSettle();
      expect(saved?['title'], 'Taharah');
      expect(
        (saved?['objectives'] as List).single['assessmentMethod'],
        'PRACTICAL',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty topic cannot be submitted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CurriculumTopicDialog(position: 1)),
      ),
    );
    await tester.tap(find.text('Save topic'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 2 characters'), findsOneWidget);
    expect(find.text('Choose an assessment method'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
