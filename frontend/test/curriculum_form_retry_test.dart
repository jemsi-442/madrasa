import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_lesson_dialog.dart';
import 'package:mif_app/src/curriculum_topic_dialog.dart';
import 'package:mif_app/src/curriculum_save_conflict.dart';

void main() {
  for (final lesson in [false, true]) {
    for (final stale in [false, true]) {
      testWidgets(
        '${lesson ? 'lesson' : 'topic'} retains content; stale version: $stale',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const objective = {
            'id': 'objective-1',
            'code': 'READ-1',
            'description': 'Read simple words clearly',
            'assessmentMethod': 'ORAL',
            'criteria': 'Read at least three words correctly',
          };
          final requests = <Map<String, dynamic>>[];
          final pending = Completer<String?>();
          Future<String?> save(Map<String, dynamic> body) async {
            requests.add(body);
            if (stale) {
              throw const CurriculumSaveConflict('Reopen the latest draft.');
            }
            if (requests.length == 1) {
              return 'Temporary save failure. Try again.';
            }
            return pending.future;
          }

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => lesson
                          ? CurriculumLessonDialog(
                              position: 1,
                              maxPosition: 1,
                              occupiedPositions: [],
                              onSave: save,
                              topics: const [
                                {
                                  'title': 'Reading',
                                  'objectives': [objective],
                                },
                              ],
                              lesson: const {
                                'title': 'Reading practice',
                                'activities': 'Read together with a partner',
                                'durationMinutes': 30,
                                'objectives': [
                                  {'objectiveId': 'objective-1'},
                                ],
                              },
                            )
                          : CurriculumTopicDialog(
                              position: 1,
                              maxPosition: 1,
                              occupiedPositions: [],
                              onSave: save,
                              topic: const {
                                'title': 'Reading practice',
                                'objectives': [objective],
                              },
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
          final label = lesson ? 'Save lesson' : 'Save topic';
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (stale) {
            expect(find.text('Reopen the latest draft.'), findsOneWidget);
            expect(find.text('Reading practice'), findsOneWidget);
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNull,
            );
            expect(requests, hasLength(1));
            await tester.tap(find.text('Discard edits & view latest'));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }
          expect(
            find.text('Temporary save failure. Try again.'),
            findsOneWidget,
          );
          expect(find.text('Reading practice'), findsOneWidget);
          await tester.tap(find.text(label));
          await tester.pump();
          expect(requests, hasLength(2));
          expect(requests.last, equals(requests.first));
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.byType(AlertDialog), findsOneWidget);
          pending.complete(null);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
