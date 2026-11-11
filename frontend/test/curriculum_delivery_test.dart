import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/school_curriculum_page.dart';

void main() {
  testWidgets(
    'expired teaching session asks for sign-in without claiming success',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
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
                'subjects': [],
                'classes': [],
                'assignments': [
                  {
                    'id': 'assignment-1',
                    'version': {
                      'subject': 'Arabic',
                      'level': 'Level 1',
                      'version': '1.0',
                      'description': 'Synthetic example',
                      'topics': [],
                      'lessons': [
                        {
                          'id': 'lesson-1',
                          'title': 'Reading words',
                          'durationMinutes': 20,
                          'activities': 'Guided practice',
                          'objectives': [],
                        },
                      ],
                    },
                    'adoptions': [
                      {
                        'id': 'adoption-1',
                        'history': [],
                        'class': {
                          'id': '1',
                          'name': 'Class A',
                          'academicYear': '2026',
                        },
                        'subject': {'name': 'Arabic'},
                      },
                    ],
                  },
                ],
              },
              submit: (_, body) async {
                writes++;
                throw const ApiException('Private authentication detail', 401);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lesson plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lesson plan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Record lesson taught'));
      await tester.tap(find.text('Record lesson taught'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm taught'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.textContaining('Your session has expired.'), findsOneWidget);
      expect(
        find.textContaining('This attempt has not been confirmed.'),
        findsOneWidget,
      );
      expect(find.textContaining('do not refresh'), findsNothing);
      expect(find.text('Private authentication detail'), findsNothing);
      expect(find.text('Recorded'), findsNothing);
      expect(
        find.textContaining('Teaching recorded successfully'),
        findsNothing,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'teaching retries and confirmations stay scoped to selected class',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchoolCurriculumPage(
              isAdmin: false,
              load: (_) async => {
                'subjects': [],
                'classes': [],
                'assignments': [
                  {
                    'id': 'assignment-1',
                    'version': {
                      'subject': 'Arabic',
                      'level': 'Level 1',
                      'version': '1.0',
                      'description': 'Synthetic example',
                      'topics': [],
                      'lessons': [
                        {
                          'id': 'lesson-1',
                          'title': 'Reading words',
                          'durationMinutes': 20,
                          'activities': 'Guided practice',
                          'objectives': [],
                        },
                      ],
                    },
                    'adoptions': [
                      for (final name in ['A', 'B'])
                        {
                          'id': 'adoption-$name',
                          'history': [],
                          'class': {
                            'id': name,
                            'name': 'Class $name',
                            'academicYear': '2026',
                          },
                          'subject': {'name': 'Arabic'},
                        },
                    ],
                  },
                ],
              },
              submit: (_, body) async {
                writes.add(Map<String, dynamic>.from(body));
                if (writes.length == 1) {
                  throw const ApiException('Unavailable', 503);
                }
                return {'id': 'synthetic-delivery-${writes.length}'};
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lesson plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lesson plan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Record lesson taught'));
      await tester.tap(find.text('Record lesson taught'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm taught'),
            )
            .onPressed,
        isNull,
      );
      Future<void> selectClass(String name) async {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Class $name (2026)').last);
        await tester.pumpAndSettle();
      }

      await selectClass('A');
      await tester.tap(find.text('Confirm taught'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Confirmation was not received'),
        findsOneWidget,
      );
      await selectClass('B');
      expect(
        find.textContaining('Confirmation was not received'),
        findsNothing,
      );
      await tester.tap(find.text('Confirm taught'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded'), findsOneWidget);
      await selectClass('A');
      expect(find.text('Recorded'), findsNothing);
      expect(
        find.textContaining('Teaching recorded successfully'),
        findsNothing,
      );
      await tester.tap(find.text('Confirm taught'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(3));
      expect(writes[0], equals(writes[2]));
      expect(writes[0]['classCurriculumId'], 'adoption-A');
      expect(writes[1]['classCurriculumId'], 'adoption-B');
      expect(writes[1]['clientEventId'], isNot(writes[0]['clientEventId']));
      await selectClass('B');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Recorded'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    for (final admin in [false, true]) {
      testWidgets('online teaching at $width admin=$admin', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = Completer<dynamic>();
        final writes = <Map<String, dynamic>>[];
        var loads = 0;
        final data = {
          'subjects': [],
          'classes': [],
          'assignments': [
            {
              'id': 'assignment-1',
              'version': {
                'subject': 'Arabic',
                'level': 'Level 1',
                'version': '1.0',
                'description': 'Synthetic teaching example',
                'topics': [],
                'lessons': [
                  {
                    'id': 'lesson-1',
                    'title': 'Reading words',
                    'durationMinutes': 20,
                    'activities': 'Practise reading together',
                    'objectives': [],
                  },
                ],
              },
              'adoptions': [
                {
                  'id': 'adoption-1',
                  'history': [],
                  'class': {
                    'id': '1',
                    'name': 'Class A',
                    'academicYear': '2026',
                  },
                  'subject': {'name': 'Arabic'},
                },
              ],
            },
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SchoolCurriculumPage(
                isAdmin: admin,
                load: (_) async {
                  loads++;
                  return data;
                },
                submit: (path, body) async {
                  expect(path, '/api/school-curriculum/deliveries');
                  writes.add(Map<String, dynamic>.from(body));
                  if (writes.length == 1) return first.future;
                  return {'id': 'delivery-1'};
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!admin) {
          await tester.ensureVisible(find.text('Lesson plan'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lesson plan'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Shared lesson plans'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Shared lesson plans'));
        await tester.pumpAndSettle();
        if (admin) {
          expect(find.text('Record lesson taught'), findsNothing);
          expect(writes, isEmpty);
          return;
        }
        await tester.ensureVisible(find.text('Record lesson taught'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record lesson taught'));
        await tester.pumpAndSettle();
        expect(find.textContaining('not student attendance'), findsOneWidget);
        await tester.tap(find.text('Confirm taught'));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Recording...'),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        first.completeError(const ApiException('Unavailable', 503));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Confirmation was not received'),
          findsOneWidget,
        );
        // Closing and reopening the dialog still retries the same pending event.
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(loads, 1);
        await tester.tap(find.text('Record lesson taught'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm taught'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(2));
        expect(writes.last, equals(writes.first));
        expect(writes.last['classCurriculumId'], 'adoption-1');
        expect(writes.last['assignmentId'], 'assignment-1');
        expect(writes.last['lessonId'], 'lesson-1');
        expect(
          writes.last['clientEventId'],
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(
          find.textContaining('Teaching recorded successfully'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Recorded'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(loads, 2);
        expect(writes, hasLength(2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
