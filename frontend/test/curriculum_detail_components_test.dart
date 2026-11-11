import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_detail_components.dart';

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('lesson search keeps original lesson actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lessons = [
        {
          'id': 'synthetic-first',
          'title': 'Reading practice',
          'activities': 'Read in pairs',
          'objectives': <Map>[],
        },
        {
          'id': 'synthetic-second',
          'title': 'Writing practice',
          'activities': 'Trace letters',
          'objectives': [
            {
              'objective': {
                'code': 'WRITE-02',
                'description': 'Form letters independently',
              },
            },
          ],
        },
      ];
      int? selected;
      Widget screen(List data) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CurriculumLessonPlansBrowser(
                key: const ValueKey('synthetic-assignment'),
                lessons: data,
                buildLesson: (index) => TextButton(
                  onPressed: () => selected = index,
                  child: Text('Lesson ${index + 1}: ${data[index]['title']}'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(lessons));
      expect(find.text('Showing 2 of 2 lesson plans'), findsOneWidget);
      for (final term in [
        ' writing ',
        'TRACE',
        'write-02',
        'letters independently',
      ]) {
        await tester.enterText(find.byType(TextField), term);
        await tester.pumpAndSettle();
        expect(find.text('Lesson 1: Reading practice'), findsNothing);
        expect(find.text('Lesson 2: Writing practice'), findsOneWidget);
        expect(find.text('Showing 1 of 2 lesson plans'), findsOneWidget);
      }
      await tester.tap(find.text('Lesson 2: Writing practice'));
      expect(selected, 1);
      await tester.pumpWidget(screen(List.of(lessons)));
      await tester.pumpAndSettle();
      expect(find.text('Lesson 1: Reading practice'), findsNothing);
      expect(find.text('Lesson 2: Writing practice'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unmatched phrase');
      await tester.pumpAndSettle();
      expect(find.text('No matching lesson plans'), findsOneWidget);
      expect(find.text('Showing 0 of 2 lesson plans'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear lesson search'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson 1: Reading practice'), findsOneWidget);
      expect(find.text('Lesson 2: Writing practice'), findsOneWidget);
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 1100.0]) {
    testWidgets('topics open independently and retain selection at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bucket = PageStorageBucket();
      Widget topic(String id, {bool expanded = false}) => CurriculumTopicDetail(
        key: PageStorageKey(id),
        number: id == 'first' ? 1 : 2,
        initiallyExpanded: expanded,
        topic: {
          'title': 'Synthetic $id topic',
          'objectives': [
            {
              'code': '$id-01',
              'description': 'Read the $id assigned passage.',
              'assessmentMethod': 'Individual $id exercise',
              'criteria': '',
            },
          ],
        },
      );
      Widget screen(bool visible) => MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: visible
                ? SingleChildScrollView(
                    key: const PageStorageKey('topic-scroll'),
                    child: Column(
                      children: [
                        topic('first', expanded: true),
                        topic('second'),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      expect(find.text('1 learning objective'), findsNWidgets(2));
      expect(find.text('Individual first exercise'), findsOneWidget);
      expect(find.text('Individual second exercise'), findsNothing);
      expect(find.text('Not specified'), findsOneWidget);
      await tester.tap(find.text('Synthetic first topic'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Synthetic second topic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic second topic'));
      await tester.pumpAndSettle();
      expect(find.text('Individual first exercise'), findsNothing);
      expect(find.text('Individual second exercise'), findsOneWidget);
      final method = tester.getTopLeft(find.text('Assessment method'));
      final criteria = tester.getTopLeft(find.text('Success criteria'));
      if (width < 640) {
        expect(criteria.dy, greaterThan(method.dy));
      } else {
        expect(criteria.dy, method.dy);
        expect(criteria.dx, greaterThan(method.dx));
      }
      await tester.pumpWidget(screen(false));
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      expect(find.text('Individual first exercise'), findsNothing);
      expect(find.text('Individual second exercise'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty topic shows an explicit empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CurriculumTopicDetail(
            key: PageStorageKey('empty-topic'),
            topic: {'title': 'Synthetic empty topic', 'objectives': []},
            number: 1,
            initiallyExpanded: true,
          ),
        ),
      ),
    );
    expect(find.text('0 learning objectives'), findsOneWidget);
    expect(find.text('No objectives in this topic.'), findsOneWidget);
    expect(find.text('Assessment method'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1100.0, 1440.0]) {
    testWidgets('curriculum details separate fields and actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var records = 0;
      var histories = 0;
      final lesson = {
        'id': 'synthetic-lesson',
        'title':
            'Guided reading and independent practice for beginning learners',
        'durationMinutes': 35,
        'activities':
            'Read together.\nPractise in pairs and discuss the activity.',
        'objectives': [
          {
            'objective': {
              'code': 'READ-01',
              'description':
                  'Recognise and read the assigned words independently.',
            },
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: SelectionArea(
                child: SingleChildScrollView(
                  key: const PageStorageKey('detail-workspace'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SchoolCurriculumDetail(
                      assignment: {
                        'id': 'synthetic-assignment',
                        'version': {
                          'subject':
                              'Arabic language foundations and reading practice',
                          'level': 'Foundation level',
                          'version': '1.0',
                          'description':
                              'A synthetic framework for testing readable lesson plans on small and large screens.',
                          'lessons': [lesson],
                          'topics': [
                            {
                              'title': 'Reading foundations',
                              'objectives': [
                                {
                                  'code': 'READ-01',
                                  'description':
                                      'Recognise and read the assigned words independently.',
                                  'assessmentMethod':
                                      'Observe the individual reading exercise.',
                                  'criteria':
                                      'Read the assigned words without teacher assistance.',
                                },
                              ],
                            },
                          ],
                        },
                        'adoptions': [
                          {
                            'id': 'synthetic-adoption',
                            'class': {
                              'name': 'Synthetic foundation reading group',
                              'academicYear': '2026/2027',
                            },
                            'subject': {'name': 'Arabic language and literacy'},
                            'history': [],
                            'teachingCoverage': {
                              'taughtLessons': 0,
                              'totalLessons': 1,
                            },
                          },
                        ],
                      },
                      isAdmin: false,
                      openLessons: true,
                      onRecord: (selected) {
                        expect(selected, same(lesson));
                        records++;
                      },
                      onHistory: (_) => histories++,
                      historyDate: (_) => '',
                      historySummary: (_) => '',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teaching activities'), findsOneWidget);
      expect(find.text('Linked learning objectives'), findsOneWidget);
      expect(records, 0);
      await tester.ensureVisible(find.text('Record lesson taught'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record lesson taught'));
      expect(records, 1);
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'READ-01');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared lesson plans'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'READ-01',
      );
      await tester.ensureVisible(find.text('Topics & objectives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topics & objectives'));
      await tester.pumpAndSettle();
      expect(find.text('Assessment method'), findsOneWidget);
      expect(find.text('Success criteria'), findsOneWidget);
      await tester.ensureVisible(find.text('Teaching history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teaching history'));
      expect(histories, 1);
      expect(records, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
