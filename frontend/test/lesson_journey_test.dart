import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/learner_lesson_reader.dart';
import 'lesson_media_flow_test.dart' show MediaFixture, RouteLog, host, tap;

class JourneyFixture extends MediaFixture {
  final progress = <String, int>{'20': 0, '21': 35, '22': 0};
  String? lockedLesson, failedLesson, delayedLesson;
  Completer<dynamic>? pendingLesson;
  final titles = [
    'Learn the alphabet',
    'Read familiar words',
    'Build a sentence',
  ];

  List<Map<String, dynamic>> get outline => [
    for (var i = 0; i < titles.length; i++)
      {
        ...row(
          '${20 + i}',
          titles[i],
          lockedLesson == '${20 + i}'
              ? 'PAYWALL'
              : i == 1
              ? 'PREVIEW'
              : 'OPEN',
          progress['${20 + i}']!,
        ),
        'moduleTitle': i < 2 ? 'First steps' : 'Putting it together',
      },
  ];

  @override
  Future<dynamic> load(String path) async {
    if (path == '/api/learner/courses/1') {
      paths.add(path);
      final lessons = outline;
      return {
        'course': {
          ...course('1', 'Arabic foundations', 'OPEN'),
          'modules': [
            {'title': 'First steps', 'lessons': lessons.take(2).toList()},
            {
              'title': 'Putting it together',
              'lessons': [lessons.last],
            },
          ],
        },
      };
    }
    if (path.startsWith('/api/learner/lessons/')) {
      paths.add(path);
      final id = path.split('/').last;
      if (id == delayedLesson) await pendingLesson!.future;
      if (id == failedLesson) throw ApiException('Access has expired', 403);
      final lesson = outline.firstWhere((item) => item['id'] == id);
      return {
        'lesson': {
          ...lesson,
          'course': {'title': 'Arabic foundations'},
          'contentText': 'Reading text for lesson $id.',
          'assets': id == '20'
              ? [asset('30', 'Reading notes', 'OPEN', true)]
              : [],
        },
      };
    }
    return super.load(path);
  }

  @override
  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add({'path': path, 'body': body});
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw ApiException('Progress was not saved', 503);
    progress[path.split('/')[4]] = 100;
    return {'progressPercent': 100};
  }

  Widget journey({String id = '20', List<Map<String, dynamic>>? lessons}) =>
      LearnerLessonReader(
        id: id,
        load: load,
        submit: submit,
        apiBaseUrl: 'https://school.test',
        surfaceBuilder: surface,
        outline: lessons ?? outline,
      );
}

Finder control(String key) => find.byKey(ValueKey(key));

void main() {
  for (final width in [320.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lesson sequence, module and top focus at $width / $scale', (
        t,
      ) async {
        final f = JourneyFixture();
        await host(t, f.journey(), width: width, scale: scale);
        expect(find.text('Lesson 1 of 3'), findsOneWidget);
        expect(
          t.widget<OutlinedButton>(control('previous-lesson')).onPressed,
          isNull,
        );
        await tap(t, control('next-lesson'));
        expect(find.text('Lesson 2 of 3'), findsOneWidget);
        expect(find.text('35% recorded'), findsOneWidget);
        expect(find.text('Reading text for lesson 20.'), findsNothing);
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        expect(scroll.position.pixels, closeTo(0, 1));
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'Current lesson',
        );
        await tap(t, control('next-lesson'));
        expect(find.text('Lesson 3 of 3'), findsOneWidget);
        expect(find.text('Putting it together'), findsOneWidget);
        expect(find.text('End of published lessons'), findsOneWidget);
        expect(control('next-lesson'), findsNothing);
        expect(find.text('0% recorded'), findsOneWidget);
        await tap(t, control('previous-lesson'));
        expect(find.text('Lesson 2 of 3'), findsOneWidget);
        expect(f.paths, [
          '/api/learner/lessons/20',
          '/api/learner/lessons/21',
          '/api/learner/lessons/22',
          '/api/learner/lessons/21',
        ]);
        expect(f.writes, isEmpty);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('one reader route returns straight to refreshed curriculum', (
    t,
  ) async {
    final f = JourneyFixture();
    final observer = RouteLog();
    await host(t, f.page(builder: f.surface), observer: observer);
    await tap(t, find.text('View lessons').first);
    await tap(t, find.text('Continue learning'));
    final pushes = observer.pushed.length;
    await tap(t, control('next-lesson'));
    await tap(t, control('next-lesson'));
    await tap(t, control('previous-lesson'));
    expect(observer.pushed.length, pushes);
    await tap(t, control('course-outline'));
    expect(find.text('Course curriculum'), findsOneWidget);
    expect(find.byType(LearnerLessonReader), findsNothing);
    expect(f.paths.where((p) => p == '/api/learner/courses/1').length, 2);
    expect(f.writes, isEmpty);
  });

  testWidgets('completion targets active lesson and never advances itself', (
    t,
  ) async {
    final f = JourneyFixture();
    await host(t, f.journey());
    await tap(t, find.text('Mark complete'));
    expect(find.text('Lesson 1 of 3'), findsOneWidget);
    await tap(t, control('next-lesson'));
    expect(find.text('Lesson completed'), findsNothing);
    expect(find.text('35% recorded'), findsOneWidget);
    await tap(t, find.text('Mark complete'));
    expect(find.text('Lesson 2 of 3'), findsOneWidget);
    expect(f.writes.map((w) => w['path']).toList(), [
      '/api/learner/lessons/20/progress',
      '/api/learner/lessons/21/progress',
    ]);
    expect(f.writes.last['body'], {
      'progressPercent': 100,
      'markCompleted': true,
    });
    await tap(t, control('previous-lesson'));
    expect(find.text('Lesson completed'), findsOneWidget);
    await tap(t, control('next-lesson'));
    expect(find.text('Lesson completed'), findsOneWidget);
    expect(f.writes.length, 2);
  });

  testWidgets('locked adjacent lessons cannot be opened or silently skipped', (
    t,
  ) async {
    final f = JourneyFixture()..lockedLesson = '21';
    await host(t, f.journey());
    expect(t.widget<FilledButton>(control('next-lesson')).onPressed, isNull);
    expect(find.text('First steps / Access required'), findsOneWidget);
    await tap(t, control('next-lesson'));
    expect(f.paths, ['/api/learner/lessons/20']);
    await t.pumpWidget(const SizedBox());
    await host(t, f.journey(id: '22'));
    expect(
      t.widget<OutlinedButton>(control('previous-lesson')).onPressed,
      isNull,
    );
    await tap(t, control('previous-lesson'));
    expect(f.paths, ['/api/learner/lessons/20', '/api/learner/lessons/22']);
    expect(f.writes, isEmpty);
  });

  testWidgets('pending completion blocks lesson changes and curriculum exit', (
    t,
  ) async {
    final f = JourneyFixture()..pendingSave = Completer<dynamic>();
    final observer = RouteLog();
    await host(t, f.page(), observer: observer);
    await tap(t, find.text('View lessons').first);
    await tap(t, find.text('Continue learning'));
    await tap(t, control('next-lesson'));
    final save = find.text('Mark complete');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pump();
    expect(t.widget<FilledButton>(control('next-lesson')).onPressed, isNull);
    expect(
      t.widget<OutlinedButton>(control('previous-lesson')).onPressed,
      isNull,
    );
    expect(t.widget<TextButton>(control('course-outline')).onPressed, isNull);
    expect(
      t
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Back to course',
            ),
          )
          .onPressed,
      isNull,
    );
    await t.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await t.pump();
    expect(find.byType(LearnerLessonReader), findsOneWidget);
    f.pendingSave!.complete();
    await t.pumpAndSettle();
    expect(find.text('Lesson 2 of 3'), findsOneWidget);
    await tap(t, control('next-lesson'));
    expect(find.text('Lesson 3 of 3'), findsOneWidget);
    expect(f.writes.single['path'], '/api/learner/lessons/21/progress');
  });

  testWidgets('a save error belongs only to its lesson', (t) async {
    final f = JourneyFixture()..failSave = true;
    await host(t, f.journey());
    await tap(t, find.text('Mark complete'));
    expect(find.text('Progress was not saved'), findsOneWidget);
    expect(find.text('Lesson 1 of 3'), findsOneWidget);
    await tap(t, control('next-lesson'));
    expect(find.text('Progress was not saved'), findsNothing);
    expect(find.text('35% recorded'), findsOneWidget);
    f.failSave = false;
    await tap(t, find.text('Mark complete'));
    expect(find.text('Lesson completed'), findsOneWidget);
    expect(f.progress['20'], 0);
    expect(f.progress['21'], 100);
  });

  testWidgets('switching lessons disposes media, while focus does not', (
    t,
  ) async {
    final f = JourneyFixture();
    await host(t, f.journey());
    await tap(t, control('open-resource-30'));
    expect(f.events, ['mount PDF']);
    await tap(t, control('media-focus-view'));
    expect(find.text('Continue your course'), findsNothing);
    expect(control('next-lesson'), findsNothing);
    await tap(t, control('media-focus-view'));
    expect(f.events, ['mount PDF']);
    await tap(t, control('next-lesson'));
    expect(f.events, ['mount PDF', 'dispose PDF']);
    expect(find.text('Test PDF surface'), findsNothing);
    await tap(t, control('previous-lesson'));
    expect(find.text('Test PDF surface'), findsNothing);
    expect(find.text('Lesson notes'), findsOneWidget);
    expect(f.paths.where((p) => p.endsWith('/open')).length, 1);
    expect(f.writes, isEmpty);
  });

  testWidgets(
    'fresh authorization failure clears old content and retries new id',
    (t) async {
      final f = JourneyFixture()
        ..delayedLesson = '21'
        ..failedLesson = '21'
        ..pendingLesson = Completer<dynamic>();
      await host(t, f.journey());
      await tap(t, control('open-resource-30'));
      await t.ensureVisible(control('next-lesson'));
      await t.tap(control('next-lesson'));
      await t.pump();
      expect(find.text('Reading text for lesson 20.'), findsNothing);
      expect(find.text('Mark complete'), findsNothing);
      expect(find.text('Test PDF surface'), findsNothing);
      expect(f.events, ['mount PDF', 'dispose PDF']);
      f.pendingLesson!.complete();
      await t.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Reading text for lesson 20.'), findsNothing);
      f.failedLesson = null;
      await tap(t, find.text('Try again'));
      expect(find.text('Lesson 2 of 3'), findsOneWidget);
      expect(find.text('35% recorded'), findsOneWidget);
      expect(f.paths.where((p) => p == '/api/learner/lessons/21').length, 2);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets(
    'single lesson has honest boundaries without claiming completion',
    (t) async {
      final f = JourneyFixture();
      await host(t, f.journey(lessons: [f.outline.first]));
      expect(find.text('Lesson 1 of 1'), findsOneWidget);
      expect(find.text('End of published lessons'), findsOneWidget);
      expect(control('next-lesson'), findsNothing);
      expect(
        t.widget<OutlinedButton>(control('previous-lesson')).onPressed,
        isNull,
      );
      expect(find.text('0% recorded'), findsOneWidget);
      expect(find.text('Mark complete'), findsOneWidget);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets('reader without curriculum context does not invent a sequence', (
    t,
  ) async {
    final f = JourneyFixture();
    await host(t, f.journey(lessons: []));
    expect(find.text('Continue your course'), findsNothing);
    expect(control('next-lesson'), findsNothing);
    expect(control('previous-lesson'), findsNothing);
    expect(find.text('Reading text for lesson 20.'), findsOneWidget);
    await tap(t, find.text('Mark complete'));
    expect(f.writes.single['path'], '/api/learner/lessons/20/progress');
  });
}
