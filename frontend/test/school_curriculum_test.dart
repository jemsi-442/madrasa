import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/school_curriculum_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final admin in [true, false]) {
      testWidgets('school curriculum at $width admin=$admin', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? submitted;
        final data = {
          'assignments': [
            {
              'id': 'a1',
              'version': {
                'subject': 'Arabic',
                'version': '1.0',
                'level': 'Level 1',
                'description': 'Reading foundations',
                'topics': [],
                'lessons': [
                  {
                    'title': 'Reading practice',
                    'durationMinutes': 30,
                    'activities': 'Read in pairs',
                    'objectives': [],
                  },
                ],
              },
              'adoptions': [],
            },
          ],
          'classes': [
            {
              'id': '10',
              'name': 'Class A',
              'level': 'Level 1',
              'academicYear': '2026',
            },
          ],
          'subjects': [
            {'id': '20', 'name': 'Arabic language'},
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SchoolCurriculumPage(
                isAdmin: admin,
                load: (_) async => data,
                submit: (path, body) async {
                  expect(path, '/api/school-curriculum/adoptions');
                  submitted = body;
                  return {};
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (admin) {
          await tester.ensureVisible(find.text('Use in a class'));
          await tester.tap(find.text('Use in a class'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirm adoption'));
          await tester.pumpAndSettle();
          expect(find.text('Choose a class'), findsOneWidget);
          expect(submitted, isNull);
          await tester.tap(find.byType(DropdownButtonFormField<String>).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Class A (Level 1, 2026)').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Arabic language').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirm adoption'));
          await tester.pumpAndSettle();
          expect(submitted, {
            'assignmentId': 'a1',
            'classId': '10',
            'subjectId': '20',
          });
        } else {
          expect(find.text('Use in a class'), findsNothing);
        }
        await tester.ensureVisible(find.text('Shared lesson plans'));
        await tester.tap(find.text('Shared lesson plans'));
        await tester.pumpAndSettle();
        expect(find.text('Read in pairs'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('error offers retry without fabricated curriculum', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCurriculumPage(
            isAdmin: true,
            load: (_) async => throw Exception('offline'),
            submit: (_, _) async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Use in a class'), findsNothing);
  });
}
