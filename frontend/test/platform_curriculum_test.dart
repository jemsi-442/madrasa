import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('grouped levels and isolated framework sections at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rows = [
        for (final level in [1, 2])
          {
            'id': 'v$level',
            'subject': 'Arabic',
            'level': 'Level $level',
            'version': '1.0',
            'description': 'Arabic foundations',
            'status': 'DRAFT',
            'objectives': ['Read independently'],
            '_count': {'assignments': 0},
            'assignments': [],
            'topics': [],
            'lessons': [
              {
                'title': 'Practice reading',
                'durationMinutes': 20,
                'activities': 'Read with a partner',
                'objectives': [],
              },
            ],
          },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async => {
                'items': path.contains('&id=') ? [rows.first] : rows,
                'total': path.contains('&id=') ? 1 : 2,
                'madrasaCount': 2,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsNWidgets(3));
      expect(find.textContaining('Level: Level 1'), findsOneWidget);
      expect(find.textContaining('Level: Level 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Open framework').first);
      await tester.tap(find.text('Open framework').first);
      await tester.pumpAndSettle();
      expect(find.text('- Read independently'), findsOneWidget);
      expect(find.text('Read with a partner'), findsNothing);
      expect(find.textContaining('Next step: add topics'), findsOneWidget);
      final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publish version'),
      );
      expect(publish.onPressed, isNull);
      await tester.ensureVisible(find.text('Lesson Plans').first);
      await tester.tap(find.text('Lesson Plans').first);
      await tester.pumpAndSettle();
      expect(find.text('Read with a partner'), findsOneWidget);
      expect(find.text('- Read independently'), findsNothing);
      await tester.ensureVisible(find.text('Topics & Objectives').first);
      await tester.tap(find.text('Topics & Objectives').first);
      await tester.pumpAndSettle();
      expect(find.text('Read with a partner'), findsNothing);
      expect(find.text('Add topic & objectives'), findsOneWidget);
      await tester.ensureVisible(find.text('Assignments').first);
      await tester.tap(find.text('Assignments').first);
      await tester.pumpAndSettle();
      expect(find.text('Not assigned yet.'), findsOneWidget);
      expect(find.text('Add topic & objectives'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'save opens the exact draft and author publishes without approval',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final reads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async {
                if (body != null) {
                  if (path == '/curriculum') {
                    saved = {
                      ...body,
                      'id': 'saved-version',
                      'status': 'DRAFT',
                      'createdBy': 'author',
                      '_count': {'assignments': 0},
                      'assignments': [],
                      'topics': [
                        {
                          'title': 'Reading',
                          'objectives': [
                            {
                              'code': 'READ',
                              'description': 'Read simple words',
                              'assessmentMethod': 'ORAL',
                              'criteria': 'Read three words correctly',
                            },
                          ],
                        },
                      ],
                    };
                  } else if (path.endsWith('/transition')) {
                    saved!['status'] = 'PUBLISHED';
                  }
                  return {'id': 'saved-version'};
                }
                reads.add(path);
                return {
                  'items': [if (saved != null) saved],
                  'total': saved == null ? 0 : 1,
                  'madrasaCount': 2,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New framework'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Arabic');
      await tester.enterText(fields.at(2), 'Arabic foundations');
      await tester.enterText(fields.at(3), 'Read simple words');
      await tester.enterText(fields.at(4), 'Level 1');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(reads.last, contains('id=saved-version'));
      expect(
        find.textContaining('Next step: check your draft'),
        findsOneWidget,
      );
      expect(find.text('- Read simple words'), findsOneWidget);
      await tester.ensureVisible(find.text('Publish version'));
      await tester.tap(find.text('Publish version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish now'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Published. Next step: select Assign to madrasa'),
        findsOneWidget,
      );
      expect(find.text('Publish version'), findsNothing);
      await tester.tap(find.text('Back to subject library'));
      await tester.pumpAndSettle();
      expect(reads.last, '/curriculum?page=1');
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('curriculum layout and objectives at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async => {
                'total': 1,
                'madrasaCount': 2,
                'items': [
                  {
                    'id': 'v1',
                    'subject': 'Quran',
                    'version': '1.0',
                    'description': 'Recitation',
                    'objectives': ['Recite clearly'],
                    'status': 'PUBLISHED',
                    'createdBy': 'author',
                    '_count': {'assignments': 1},
                    'assignments': [
                      {
                        'organization': {'name': 'Afaq School', 'code': 'AFQ'},
                      },
                    ],
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quran'), findsNWidgets(2));
      expect(find.text('1 / 2 madrasas'), findsOneWidget);
      await tester.ensureVisible(find.text('Learning objectives').first);
      await tester.tap(find.text('Learning objectives').first);
      await tester.pumpAndSettle();
      expect(find.text('- Recite clearly'), findsOneWidget);
      expect(find.text('Release control'), findsOneWidget);
      await tester.ensureVisible(find.text('Versions & publishing'));
      await tester.tap(find.text('Versions & publishing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create new version'));
      await tester.tap(find.text('Create new version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.text('Use a version such as 1.1'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '1.0');
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a different version number'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();
      expect(find.text('Back to subject library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed curriculum shows retry, not fake frameworks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'author',
            onSessionExpired: () {},
            call: (_, {body}) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Quran'), findsNothing);
  });
}
