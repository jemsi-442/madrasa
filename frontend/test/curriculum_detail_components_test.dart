import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_detail_components.dart';

void main() {
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
