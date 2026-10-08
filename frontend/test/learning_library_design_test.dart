import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/learner_courses_page.dart';
import 'package:mif_app/src/learner_lesson_reader.dart';
import 'package:mif_app/src/learning_library_ui.dart';
import 'lesson_journey_test.dart' show JourneyFixture;
import 'lesson_media_flow_test.dart' show host, tap;

class DesignFixture extends JourneyFixture {
  bool empty = false;
  @override
  Future<dynamic> load(String path) async {
    if (path == '/api/learner/courses') {
      paths.add(path);
      return empty
          ? []
          : [
              {
                ...course('1', 'Arabic foundations', 'OPEN'),
                'progress': {
                  'completedLessons': 1,
                  'totalLessons': 3,
                  'progressPercent': 33,
                },
                'resumeLesson': {'id': '21', 'title': titles[1]},
              },
              course('2', 'Practical fiqh', 'PAYWALL'),
            ];
    }
    return super.load(path);
  }

  Widget home(VoidCallback browse) => LearnerLearningHome(
    load: load,
    submit: submit,
    apiBaseUrl: 'https://school.test',
    surfaceBuilder: surface,
    onBrowse: browse,
  );
}

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'course search keeps typing focus when resume changes at $width',
      (t) async {
        final f = DesignFixture();
        await host(t, f.page(builder: f.surface), width: width);
        final search = find.widgetWithText(
          TextField,
          'Search subjects or courses',
        );
        await t.ensureVisible(search);
        await t.showKeyboard(search);
        final editable = find.descendant(
          of: search,
          matching: find.byType(EditableText),
        );
        final controller = t.widget<EditableText>(editable).controller;
        for (final query in ['f', 'fi', 'fiq', 'fiqh', 'no-such-course', '']) {
          t.testTextInput.enterText(query);
          await t.pumpAndSettle();
          final field = t.widget<EditableText>(editable);
          expect(field.controller, same(controller));
          expect(field.controller.text, query);
          expect(field.focusNode.hasFocus, isTrue);
        }
        expect(find.text('Resume lesson'), findsOneWidget);
        expect(find.byType(CourseCover), findsNWidgets(2));
        expect(f.paths, ['/api/learner/courses']);
        expect(f.writes, isEmpty);
      },
    );

    testWidgets(
      'course search filters content, not dashboard pages, at $width',
      (t) async {
        final f = DesignFixture();
        await host(t, f.page(builder: f.surface), width: width);
        final search = find.widgetWithText(
          TextField,
          'Search subjects or courses',
        );
        await t.ensureVisible(search);
        await t.enterText(search, '  ARABIC  ');
        await t.pumpAndSettle();
        expect(find.byType(CourseCover), findsOneWidget);
        expect(find.text('Practical fiqh'), findsNothing);
        expect(find.text('Resume lesson'), findsOneWidget);
        await t.enterText(search, 'fiqh');
        await t.pumpAndSettle();
        expect(find.text('Practical fiqh'), findsOneWidget);
        expect(find.text('Arabic foundations'), findsNothing);
        await t.enterText(search, 'not-a-published-course');
        await t.pumpAndSettle();
        expect(find.text('No courses match these filters.'), findsOneWidget);
        await t.enterText(search, '');
        await t.pumpAndSettle();
        expect(find.byType(CourseCover), findsNWidgets(2));
        expect(f.paths, ['/api/learner/courses']);
        expect(f.writes, isEmpty);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('illustrated library, subject filters and resume fit $width', (
      t,
    ) async {
      final f = DesignFixture();
      await host(t, f.page(builder: f.surface), width: width, scale: 2);
      expect(find.byType(CourseCover), findsNWidgets(2));
      expect(find.text('Browse by subject'), findsOneWidget);
      expect(find.text('Resume lesson'), findsOneWidget);
      expect(t.takeException(), isNull);
      await tap(t, key('subject-filter-2'));
      expect(find.text('Arabic foundations'), findsNothing);
      expect(find.text('Practical fiqh'), findsOneWidget);
      expect(find.text('Resume lesson'), findsNothing);
      await tap(t, key('subject-filter-2'));
      expect(find.text('Resume lesson'), findsOneWidget);
      expect(f.writes, isEmpty);
    });

    testWidgets('home resume checks curriculum then opens a lesson at $width', (
      t,
    ) async {
      final f = DesignFixture();
      int browsed = 0;
      await host(t, f.home(() => browsed++), width: width, scale: 2);
      expect(find.text('Your learning library'), findsOneWidget);
      await tap(t, find.text('All courses'));
      expect(browsed, 1);
      await tap(t, key('resume-course'));
      expect(find.byType(LearnerLessonReader), findsOneWidget);
      expect(find.text('Reading text for lesson 21.'), findsOneWidget);
      expect(f.paths.take(3), [
        '/api/learner/courses',
        '/api/learner/courses/1',
        '/api/learner/lessons/21',
      ]);
      await tap(t, find.byTooltip('Back to course'));
      expect(find.text('Course curriculum'), findsOneWidget);
      await tap(t, find.byTooltip('Back to home'));
      expect(find.text('Your learning library'), findsOneWidget);
      expect(f.paths.where((p) => p == '/api/learner/courses').length, 2);
      expect(f.writes, isEmpty);
    });

    testWidgets('course contents selects a topic inline at $width', (t) async {
      final f = JourneyFixture();
      await host(t, f.journey(), width: width, scale: 2);
      expect(find.text('Course contents'), findsOneWidget);
      if (width < 980) {
        expect(key('outline-lesson-21'), findsNothing);
        await tap(t, find.text('Course contents'));
      }
      expect(key('outline-lesson-21'), findsOneWidget);
      await tap(t, key('outline-lesson-21'));
      expect(find.text('Lesson 2 of 3'), findsOneWidget);
      expect(find.text('Reading text for lesson 21.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(f.paths, ['/api/learner/lessons/20', '/api/learner/lessons/21']);
      expect(f.writes, isEmpty);
      if (width < 980) expect(key('outline-lesson-20'), findsNothing);
    });
  }

  testWidgets('stale resume hint cannot bypass newly locked access', (t) async {
    final f = DesignFixture()..lockedLesson = '21';
    await host(t, f.page(builder: f.surface));
    await tap(t, key('resume-course'));
    expect(find.byType(LearnerLessonReader), findsNothing);
    expect(
      find.textContaining('That lesson is no longer available'),
      findsOneWidget,
    );
    expect(f.paths.contains('/api/learner/lessons/21'), isFalse);
    expect(f.writes, isEmpty);
  });

  testWidgets(
    'an empty home shelf does not invent courses or resume progress',
    (t) async {
      final f = DesignFixture()..empty = true;
      await host(t, f.home(() {}));
      expect(
        find.textContaining('Published courses will appear here'),
        findsOneWidget,
      );
      expect(key('resume-course'), findsNothing);
      expect(find.byType(CourseCover), findsNothing);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'outline keeps locked topics disabled and records completion only after save',
    (t) async {
      final f = JourneyFixture()..lockedLesson = '21';
      await host(t, f.journey());
      expect(
        t.widget<OutlinedButton>(key('outline-lesson-21')).onPressed,
        isNull,
      );
      expect(find.text('0 of 3 lessons complete'), findsOneWidget);
      f.pendingSave = Completer<dynamic>();
      await t.ensureVisible(find.text('Mark complete'));
      await t.tap(find.text('Mark complete'));
      await t.pump();
      expect(find.text('0 of 3 lessons complete'), findsOneWidget);
      f.pendingSave!.complete();
      await t.pumpAndSettle();
      expect(find.text('1 of 3 lessons complete'), findsOneWidget);
      expect(
        find.descendant(
          of: key('outline-lesson-20'),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      expect(f.writes.length, 1);
    },
  );

  testWidgets(
    'outline reauthorizes direct topic selection and clears old media',
    (t) async {
      final f = JourneyFixture()..failedLesson = '21';
      await host(t, f.journey());
      await tap(t, key('open-resource-30'));
      expect(f.events, ['mount PDF']);
      await tap(t, key('outline-lesson-21'));
      expect(
        find.text('We could not load this page. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Reading text for lesson 20.'), findsNothing);
      expect(f.events.last, 'dispose PDF');
      f.failedLesson = null;
      await tap(t, find.text('Try again'));
      expect(find.text('Reading text for lesson 21.'), findsOneWidget);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'lesson reading size has working limits and reset without progress writes',
    (t) async {
      final f = JourneyFixture();
      await host(t, f.journey(), width: 320, scale: 2);
      for (var i = 0; i < 4; i++) {
        await tap(t, find.byTooltip('Larger lesson text'));
      }
      expect(find.text('24px'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Larger lesson text',
              ),
            )
            .onPressed,
        isNull,
      );
      await tap(t, find.text('Reset text size'));
      expect(find.text('16px'), findsOneWidget);
      await tap(t, find.byTooltip('Smaller lesson text'));
      expect(find.text('14px'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Smaller lesson text',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(f.writes, isEmpty);
    },
  );

  testWidgets('long subject covers grow with accessibility text sizes', (
    t,
  ) async {
    await host(
      t,
      const CourseCover(
        subject: 'Integrated Islamic Studies and Character Education',
        lessons: 120,
      ),
      width: 320,
      scale: 3,
    );
    expect(t.takeException(), isNull);
    expect(find.text('120 lessons'), findsOneWidget);
  });
}
