import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_topic_dialog.dart';

void main() {
  for (final useBack in [false, true]) {
    testWidgets(
      'unsaved topic protects changes on ${useBack ? 'Back' : 'Cancel'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const CurriculumTopicDialog(
                      position: 1,
                      maxPosition: 1,
                      occupiedPositions: [],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final title = find.widgetWithText(TextFormField, 'Topic title');
        await tester.enterText(title, 'My unsaved topic');
        await tester.pump();
        if (useBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text('Cancel'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('My unsaved topic'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'undo restores several removals after rejected save without changing prior request',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CurriculumTopicDialog(
                    position: 1,
                    maxPosition: 1,
                    occupiedPositions: [],
                    topic: {
                      'title': 'Reading skills',
                      'objectives': [
                        for (final code in ['READ-1', 'READ-2', 'READ-3'])
                          {
                            'code': code,
                            'description': 'Read simple words clearly',
                            'assessmentMethod': 'ORAL',
                            'criteria': 'Read three words correctly',
                          },
                      ],
                    },
                    onSave: (body) async {
                      requests.add(body);
                      return requests.length == 1
                          ? 'Objective is linked to a lesson.'
                          : null;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Remove objective').first);
        await tester.tap(find.text('Remove objective').first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save topic'));
      await tester.pumpAndSettle();
      expect(find.text('Objective is linked to a lesson.'), findsOneWidget);
      expect((requests.single['objectives'] as List).single['code'], 'READ-3');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Undo'));
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Undo'), findsNothing);
      for (final code in ['READ-1', 'READ-2', 'READ-3']) {
        expect(find.text(code), findsOneWidget);
      }
      await tester.tap(find.text('Save topic'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect((requests.first['objectives'] as List).single['code'], 'READ-3');
      expect((requests.last['objectives'] as List).map((o) => o['code']), [
        'READ-1',
        'READ-2',
        'READ-3',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
                      maxPosition: 1,
                      occupiedPositions: [],
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
                          {
                            'code': 'FIQH-2',
                            'description':
                                'Explain the approved sequence clearly',
                            'assessmentMethod': 'ORAL',
                            'criteria':
                                'Explain at least three steps correctly',
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
      await tester.ensureVisible(find.text('Remove objective').first);
      await tester.tap(find.text('Remove objective').first);
      await tester.pumpAndSettle();
      expect(find.text('FIQH-1'), findsNothing);
      expect(find.text('FIQH-2'), findsOneWidget);
      expect(
        find.text('Explain the approved sequence clearly'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('FIQH-1'), findsOneWidget);
      expect(find.text('FIQH-2'), findsOneWidget);
      await tester.ensureVisible(find.text('Remove objective').last);
      await tester.tap(find.text('Remove objective').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Remove objective'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is TextButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Save topic'));
      await tester.pumpAndSettle();
      expect(saved?['title'], 'Taharah');
      expect((saved?['objectives'] as List).single['code'], 'FIQH-1');
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
        home: Scaffold(
          body: CurriculumTopicDialog(
            position: 1,
            maxPosition: 1,
            occupiedPositions: [],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save topic'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 2 characters'), findsOneWidget);
    expect(find.text('Choose an assessment method'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
