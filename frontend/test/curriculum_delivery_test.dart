import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/school_curriculum_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final admin in [false, true]) {
      testWidgets('online teaching at $width admin=$admin', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = Completer<dynamic>();
        final writes = <Map<String, dynamic>>[];
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
                load: (_) async => data,
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
        await tester.ensureVisible(find.text('Shared lesson plans'));
        await tester.tap(find.text('Shared lesson plans'));
        await tester.pumpAndSettle();
        if (admin) {
          expect(find.text('Record lesson taught'), findsNothing);
          expect(writes, isEmpty);
          return;
        }
        await tester.ensureVisible(find.text('Record lesson taught'));
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
        expect(tester.takeException(), isNull);
      });
    }
  }
}
