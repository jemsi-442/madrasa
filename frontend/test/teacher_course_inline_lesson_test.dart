import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/teacher_course_card.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'package:mif_app/src/teacher_course_inline_lesson.dart';
import 'package:mif_app/src/page_selection.dart';

void main() {
  testWidgets('retry resumes initial lesson search after an empty module', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherCourseInlineLesson(
              modules: const [
                {'id': 'empty', 'title': 'Empty module'},
                {'id': 'practice', 'title': 'Practice module'},
              ],
              apiBaseUrl: 'https://school.test',
              onClose: () {},
              load: (path) async {
                if (path == '/api/courses/modules/practice/lessons') {
                  attempts++;
                  if (attempts == 1) throw StateError('Temporary outage');
                  return [
                    {
                      'id': 'lesson',
                      'title': 'Recovered lesson',
                      'contentText': 'Recovered synthetic notes',
                    },
                  ];
                }
                return [];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('We could not load this page. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Recovered synthetic notes'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('next and previous stop at boundaries at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PageSelection(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCourseInlineLesson(
                  modules: const [
                    {'id': 'm', 'title': 'Synthetic module'},
                  ],
                  apiBaseUrl: 'https://school.test',
                  onClose: () {},
                  load: (path) async {
                    requests.add(path);
                    if (path.endsWith('/lessons')) {
                      return [
                        {
                          'id': 'a',
                          'title': 'First lesson',
                          'contentText': 'First notes',
                        },
                        {
                          'id': 'b',
                          'title': 'Second lesson',
                          'contentText': 'Second notes',
                        },
                      ];
                    }
                    return [];
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        SelectionContainer.maybeOf(tester.element(find.text('Course lesson'))),
        isNull,
      );
      expect(
        find.widgetWithText(SelectableText, 'First notes'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inline-lesson-navigation-stacked')),
        width < 640 ? findsOneWidget : findsNothing,
      );
      final previousRect = tester.getRect(find.text('Previous lesson'));
      final nextRect = tester.getRect(find.text('Next lesson'));
      if (width < 380) {
        expect(nextRect.top, greaterThan(previousRect.bottom));
      } else {
        expect(nextRect.top, closeTo(previousRect.top, 1));
      }
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Previous lesson'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Next lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Second notes'), findsOneWidget);
      expect(find.text('Lesson 2 of 2 in this module'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Previous lesson'));
      await tester.pumpAndSettle();
      expect(find.text('First notes'), findsOneWidget);
      expect(requests.where((p) => p.endsWith('/lessons')).length, 1);
      expect(requests, contains('/api/courses/lessons/b/assets'));
      tester.view.physicalSize = Size(width < 640 ? 1440 : 390, 1200);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, 'First notes'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1440.0]) {
    testWidgets('cover opens authorized lesson inline in one click at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      var navigation = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PageSelection(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TeacherCourseCard(
                  course: const {'id': 'c', 'title': 'Synthetic course'},
                  refreshToken: 0,
                  apiBaseUrl: 'https://school.test',
                  onOpen: () => navigation++,
                  onModule: (_) => navigation++,
                  load: (path) async {
                    requests.add(path);
                    switch (path) {
                      case '/api/courses/c/modules':
                        return [
                          {'id': 'empty', 'title': 'Empty module'},
                          {'id': 'm', 'title': 'Practice module'},
                        ];
                      case '/api/courses/modules/empty/lessons':
                        return [];
                      case '/api/courses/modules/m/lessons':
                        return [
                          {
                            'id': 'l',
                            'title': 'Practice lesson',
                            'contentText': 'Synthetic lesson notes',
                          },
                        ];
                      case '/api/courses/lessons/l/assets':
                        return [
                          {
                            'id': 'p',
                            'title': 'Practice PDF',
                            'assetType': 'PDF',
                          },
                          {
                            'id': 'v',
                            'title': 'Practice video',
                            'assetType': 'VIDEO',
                          },
                        ];
                      case '/api/courses/assets/v/open':
                        throw StateError('Synthetic unavailable video');
                      default:
                        throw StateError('Unexpected request $path');
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, ['/api/courses/c/modules']);
      await tester.tap(find.byTooltip('Play lesson'));
      await tester.pumpAndSettle();
      expect(navigation, 0);
      expect(find.byType(LessonMediaViewer), findsOneWidget);
      expect(
        tester
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .compactVideo,
        isTrue,
      );
      expect(find.byTooltip('Close video'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inline-lesson-selectors-row')),
        width >= 640 ? findsOneWidget : findsNothing,
      );
      expect(
        tester
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .assetId,
        'v',
      );
      expect(find.text('Synthetic lesson notes'), findsOneWidget);
      expect(requests.last, '/api/courses/assets/v/open');
      expect(requests.where((p) => p.endsWith('/open')).length, 1);
      await tester.ensureVisible(find.byTooltip('Close lesson'));
      await tester.tap(find.byTooltip('Close lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(navigation, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
