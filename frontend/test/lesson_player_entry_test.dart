import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/learner_lesson_reader.dart';
import 'package:mif_app/src/lesson_media_viewer.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';
import 'package:mif_app/src/media_player_preview.dart';
import 'lesson_media_flow_test.dart' show MediaFixture, RouteLog, host, tap;

class InlinePlayerFixture extends MediaFixture {
  InlinePlayerFixture() {
    includeAudio = false;
  }
  List<Map<String, dynamic>> assets = [];

  @override
  Future<dynamic> load(String path) async {
    final result = await super.load(path);
    if (path.startsWith('/api/learner/lessons/')) {
      result['lesson']['assets'] = assets;
    }
    return result;
  }
}

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('empty lesson has an inline player at $width and large text', (
      t,
    ) async {
      final f = InlinePlayerFixture(), routes = RouteLog();
      await host(
        t,
        f.reader(builder: f.surface),
        width: width,
        scale: 2,
        observer: routes,
      );
      expect(find.text('Lesson player'), findsOneWidget);
      expect(find.byType(LessonPlaybackTools), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Lesson player')).dy,
        lessThan(t.getTopLeft(find.text('Lesson notes')).dy),
      );
      expect(find.text('Load sample video'), findsOneWidget);
      expect(find.text('Load sample audio'), findsOneWidget);
      expect(find.byType(MediaPlayerPreviewPage), findsNothing);
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(f.paths, ['/api/learner/lessons/22']);
      expect(f.writes, isEmpty);
      expect(t.takeException(), isNull);

      final before = routes.pushed.length;
      await tap(t, find.text('Load sample video'));
      expect(find.text('Test VIDEO surface'), findsOneWidget);
      expect(find.textContaining('Practice sample only'), findsOneWidget);
      expect(find.byType(MediaPlayerPreviewPage), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(routes.pushed.length, before);
      final viewer = t.widget<LessonMediaViewer>(
        find.byType(LessonMediaViewer),
      );
      expect(viewer.previewSample!.delivery.uri.scheme, 'asset');
      await tap(t, find.byKey(const ValueKey('media-focus-view')));
      expect(find.text('Lesson notes'), findsNothing);
      expect(f.events, ['mount VIDEO']);
      await tap(t, find.byKey(const ValueKey('return-to-lesson-text')));
      expect(find.text('Lesson notes').hitTestable(), findsOneWidget);
      expect(find.text('Lesson player'), findsOneWidget);
      expect(f.events.last, 'dispose VIDEO');
      await tap(t, find.text('Load sample audio'));
      expect(find.text('Test AUDIO surface'), findsOneWidget);
      expect(f.paths, ['/api/learner/lessons/22']);
      expect(f.writes, isEmpty);
      await t.pumpWidget(const SizedBox());
      expect(f.events.last, 'dispose AUDIO');
    });
  }

  for (final kind in ['VIDEO', 'AUDIO']) {
    testWidgets('lesson player loads authorized $kind, not a sample', (
      t,
    ) async {
      final f = InlinePlayerFixture()..kind = kind;
      f.assets = [
        {
          ...f.asset('31', 'Locked video', 'PAYWALL', true),
          'assetType': 'VIDEO',
        },
        {
          ...f.asset('32', 'Awaiting upload', 'OPEN', false),
          'assetType': 'VIDEO',
        },
        {
          ...f.asset('30', 'Lesson recording', 'PREVIEW', true),
          'assetType': kind,
        },
      ];
      await host(t, f.reader(builder: f.surface));
      expect(find.text('Load sample video'), findsNothing);
      expect(find.text('Load sample audio'), findsNothing);
      expect(f.paths, ['/api/learner/lessons/22']);
      await tap(t, find.byKey(const ValueKey('load-lesson-player')));
      expect(find.text('Test $kind surface'), findsOneWidget);
      expect(find.text('Resource 1 of 1 available'), findsOneWidget);
      expect(
        t
            .widget<LessonMediaViewer>(find.byType(LessonMediaViewer))
            .previewSample,
        isNull,
      );
      expect(f.paths, [
        '/api/learner/lessons/22',
        '/api/learner/assets/30/open',
      ]);
      expect(f.writes, isEmpty);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('locked and unconnected sources are never opened by the player', (
    t,
  ) async {
    final f = InlinePlayerFixture();
    f.assets = [
      {...f.asset('31', 'Locked video', 'PAYWALL', true), 'assetType': 'VIDEO'},
      {
        ...f.asset('32', 'Awaiting upload', 'OPEN', false),
        'assetType': 'AUDIO',
      },
      f.asset('30', 'Reading notes', 'OPEN', true),
    ];
    await host(t, f.reader(builder: f.surface));
    await tap(t, find.text('Load sample video'));
    expect(f.paths, ['/api/learner/lessons/22']);
    await tap(t, find.byKey(const ValueKey('open-resource-30')));
    expect(find.textContaining('Practice sample only'), findsNothing);
    expect(find.text('Test PDF surface'), findsOneWidget);
    expect(f.events, ['mount VIDEO', 'dispose VIDEO', 'mount PDF']);
    expect(f.paths, ['/api/learner/lessons/22', '/api/learner/assets/30/open']);
    expect(f.writes, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('failed real media does not silently switch to a sample', (
    t,
  ) async {
    final f = InlinePlayerFixture()..deliveryStatus = 'NOT_READY';
    f.assets = [
      {...f.asset('30', 'Lesson video', 'OPEN', true), 'assetType': 'VIDEO'},
    ];
    await host(t, f.reader(builder: f.surface));
    await tap(t, find.byKey(const ValueKey('load-lesson-player')));
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('Practice sample only'), findsNothing);
    expect(f.events, isEmpty);
    expect(f.writes, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'changing lessons releases the inline sample and resets the player',
    (t) async {
      final f = InlinePlayerFixture();
      await host(
        t,
        LearnerLessonReader(
          id: '22',
          load: f.load,
          submit: f.submit,
          apiBaseUrl: 'https://school.test',
          surfaceBuilder: f.surface,
          outline: [
            f.row('22', 'Reading words', 'OPEN', 0),
            f.row('23', 'Next topic', 'OPEN', 0),
          ],
        ),
      );
      await tap(t, find.text('Load sample audio'));
      await tap(t, find.byKey(const ValueKey('next-lesson')));
      expect(find.text('Lesson player'), findsOneWidget);
      expect(find.byType(LessonMediaViewer), findsNothing);
      expect(f.events, ['mount AUDIO', 'dispose AUDIO']);
      expect(f.paths, ['/api/learner/lessons/22', '/api/learner/lessons/23']);
      expect(f.writes, isEmpty);
    },
  );

  testWidgets('the idle player cannot change while progress is saving', (
    t,
  ) async {
    final f = InlinePlayerFixture()..pendingSave = Completer<dynamic>();
    await host(t, f.reader(builder: f.surface));
    await t.ensureVisible(find.text('Mark complete'));
    await t.tap(find.text('Mark complete'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(
            find.byKey(const ValueKey('load-lesson-player')),
          )
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('load-lesson-sample-audio')),
          )
          .onPressed,
      isNull,
    );
    final controls = t.widget<LessonPlaybackTools>(
      find.byType(LessonPlaybackTools),
    );
    expect(controls.onPlay, isNull);
    expect(controls.onFocus, isNull);
    f.pendingSave!.complete();
    await t.pumpAndSettle();
    expect(find.text('Lesson completed'), findsOneWidget);
  });

  testWidgets('a lesson load error does not expose an inline sample', (
    t,
  ) async {
    final f = InlinePlayerFixture()..failLoad = true;
    await host(t, f.reader(builder: f.surface));
    expect(find.text('Lesson player'), findsNothing);
    expect(find.byType(LessonPlaybackTools), findsNothing);
    expect(find.byType(LessonMediaViewer), findsNothing);
    expect(f.writes, isEmpty);
  });
}
