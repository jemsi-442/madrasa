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
              'adoptions': [
                {
                  'id': 'adoption-1',
                  'createdAt': '2026-09-15T08:00:00.000Z',
                  'class': {
                    'id': '10',
                    'name': 'Class A',
                    'academicYear': '2026',
                  },
                  'subject': {'id': '20', 'name': 'Arabic language'},
                  'history': [
                    {
                      'id': 'history-1',
                      'replacedAt': '2026-09-15T08:00:00.000Z',
                      'previousAdoptedAt': '2026-01-01T08:00:00.000Z',
                      'previousAssignment': {
                        'version': {
                          'subject': 'Arabic',
                          'level': 'Level 1',
                          'version': '0.9',
                        },
                      },
                    },
                  ],
                },
              ],
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
            {'id': '20', 'name': 'Arabic language', 'isActive': true},
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
        expect(
          find.textContaining(
            'Previous: Arabic / Level 1 / v0.9 · in use from 1/1/2026 to 15/9/2026',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Current curriculum: v1.0 · in use since 15/9/2026',
          ),
          findsOneWidget,
        );
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
  testWidgets('a mapped assignment locks its school subject choice', (
    tester,
  ) async {
    final data = {
      'assignments': [
        {
          'id': 'a1',
          'subjectId': '20',
          'version': {
            'subject': 'Arabic',
            'version': '1.0',
            'level': 'Level 1',
            'description': 'Reading foundations',
            'topics': [],
            'lessons': [],
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
        {'id': '20', 'name': 'Arabic language', 'isActive': true},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCurriculumPage(
            isAdmin: true,
            load: (_) async => data,
            submit: (_, _) async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use in a class'));
    await tester.tap(find.text('Use in a class'));
    await tester.pumpAndSettle();
    final subjectField = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).last,
    );
    expect(subjectField.initialValue, '20');
    expect(subjectField.onChanged, isNull);
    expect(find.text('Arabic language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inactive mapped subject blocks adoption with a clear reason', (
    tester,
  ) async {
    final data = {
      'assignments': [
        {
          'id': 'a1',
          'subjectId': '20',
          'version': {
            'subject': 'Arabic',
            'version': '1.0',
            'level': 'Level 1',
            'description': 'Reading foundations',
            'topics': [],
            'lessons': [],
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
        {'id': '20', 'name': 'Arabic language', 'isActive': false},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCurriculumPage(
            isAdmin: true,
            load: (_) async => data,
            submit: (_, _) async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Reactivate it before adopting this version'),
      findsOneWidget,
    );
    final adoptLabel = find.text('Use in a class');
    final adoptButton = find.ancestor(
      of: adoptLabel,
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(adoptButton, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(adoptButton).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
