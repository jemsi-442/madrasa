import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';
import 'package:mif_app/src/media_player_samples.dart';
import 'package:mif_app/src/platform/lesson_media_native.dart';

class TestMediaPlatform extends VideoPlayerPlatform {
  late final StreamController<VideoEvent> events;
  final calls = <String>[];
  final seeks = <Duration>[];
  final speeds = <double>[];
  final volumes = <double>[];
  final repeats = <bool>[];
  Duration position = Duration.zero;
  Duration duration = const Duration(seconds: 30);
  double? rejectedSpeed;
  bool failSeek = false;
  String? source;
  DataSource? requestedSource;
  bool fail = false;
  bool delay = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    events = StreamController<VideoEvent>();
    source = options.dataSource.uri;
    requestedSource = options.dataSource;
    if (fail) {
      events.addError(
        PlatformException(code: 'VideoError', message: 'Unsupported media'),
      );
    } else if (!delay) {
      initialize();
    }
    return 1;
  }

  void initialize() => events.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: const Size(640, 360),
      duration: duration,
    ),
  );
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek');
    if (failSeek) throw PlatformException(code: 'SeekError');
    seeks.add(position);
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> setLooping(int playerId, bool looping) async {
    repeats.add(looping);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds.add(speed);
    if (speed == rejectedSpeed) throw PlatformException(code: 'SpeedError');
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
}

void main() {
  late TestMediaPlatform platform;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = TestMediaPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() async {
    await platform.events.close();
    VideoPlayerPlatform.instance = previous;
  });
  Widget surface(
    String kind,
    VoidCallback ready,
    VoidCallback failed, {
    double scale = 1,
    bool preview = false,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: 280,
        height: kind == 'AUDIO' ? 340 : 400,
        child: LessonMediaSurface(
          delivery: preview
              ? (kind == 'VIDEO'
                        ? MediaPlayerSample.video
                        : MediaPlayerSample.audio)
                    .delivery
              : LessonMediaDelivery(
                  uri: Uri.parse(
                    'https://school.test/api/learner/assets/3/deliver?token=signed',
                  ),
                  kind: kind,
                  title: 'Practice',
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                  downloadAllowed: false,
                ),
          onReady: ready,
          onError: failed,
        ),
      ),
    ),
  );
  for (final kind in ['AUDIO', 'VIDEO']) {
    testWidgets(
      '$kind preview uses a bundled asset with working native controls',
      (tester) async {
        await tester.pumpWidget(
          surface(kind, () {}, () => fail('Sample failed'), preview: true),
        );
        await tester.pumpAndSettle();
        expect(platform.requestedSource?.sourceType, DataSourceType.asset);
        expect(
          platform.requestedSource?.asset,
          kind == 'VIDEO'
              ? MediaPlayerSample.video.assetPath
              : MediaPlayerSample.audio.assetPath,
        );
        expect(platform.source, isNull);
        expect(platform.calls, isNot(contains('play')));
        await tester.tap(find.byTooltip('Play'));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('play'));
        await tester.tap(find.byTooltip('Forward 10 seconds'));
        await tester.pumpAndSettle();
        expect(platform.seeks.last.inSeconds, 10);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(platform.calls.last, 'dispose');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
    testWidgets(
      '$kind quick seek clamps to start/end and does not autoplay',
      (tester) async {
        var errors = 0;
        await tester.pumpWidget(surface(kind, () {}, () => errors++));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back 10 seconds'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byTooltip('Forward 10 seconds'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Back 10 seconds'));
        await tester.pumpAndSettle();
        expect(platform.seeks.map((value) => value.inSeconds), [
          0,
          10,
          20,
          30,
          30,
          20,
        ]);
        expect(platform.calls, isNot(contains('play')));
        expect(find.text('0:20 / 0:30'), findsOneWidget);
        expect(errors, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
    testWidgets(
      '$kind speed changes without autoplay or recreating the player',
      (tester) async {
        await tester.pumpWidget(surface(kind, () {}, () {}, scale: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Playback speed'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('playback-speed-1.25x')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LessonPlaybackTools>(find.byType(LessonPlaybackTools))
              .speed,
          1.25,
        );
        expect(platform.calls, isNot(contains('play')));
        await tester.tap(find.byTooltip('Play'));
        await tester.pumpAndSettle();
        expect(platform.speeds, contains(1.25));
        await tester.tap(find.byTooltip('Playback speed'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('playback-speed-0.75x')));
        await tester.pumpAndSettle();
        expect(platform.speeds.last, .75);
        expect(platform.calls, isNot(contains('dispose')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
    testWidgets(
      '$kind native controls play, pause, seek and dispose inside app',
      (tester) async {
        var ready = 0, failed = 0;
        await tester.pumpWidget(surface(kind, () => ready++, () => failed++));
        await tester.pumpAndSettle();
        expect(ready, 1);
        expect(platform.source, endsWith('/3/deliver?token=signed'));
        expect(platform.calls, isNot(contains('play')));
        await tester.tap(find.byTooltip('Play'));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('play'));
        await tester.tap(find.byTooltip('Pause'));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('pause'));
        await tester.tap(find.byKey(const ValueKey('playback-timeline')));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('seek'));
        expect(failed, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('dispose'));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  testWidgets(
    'stop, mute and repeat control the native engine',
    (tester) async {
      await tester.pumpWidget(
        surface('VIDEO', () {}, () => fail('Control failed')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Forward 10 seconds'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Stop'));
      await tester.pumpAndSettle();
      expect(platform.seeks.last, Duration.zero);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.tap(find.byTooltip('Mute'));
      await tester.pumpAndSettle();
      expect(platform.volumes.last, 0);
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(platform.volumes.last, 1);
      await tester.tap(find.byTooltip('Repeat'));
      await tester.pumpAndSettle();
      expect(platform.repeats.last, isTrue);
      await tester.tap(find.byTooltip('Disable repeat'));
      await tester.pumpAndSettle();
      expect(platform.repeats.last, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'unsupported speed restores the previous setting and reports an error',
    (tester) async {
      platform.rejectedSpeed = 1.5;
      var errors = 0;
      await tester.pumpWidget(surface('AUDIO', () {}, () => errors++));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Playback speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('playback-speed-1.5x')));
      await tester.pumpAndSettle();
      expect(errors, 1);
      expect(platform.speeds, containsAllInOrder([1.5, 1]));
      expect(
        tester
            .widget<LessonPlaybackTools>(find.byType(LessonPlaybackTools))
            .speed,
        1,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'quick seek is unavailable for a resource without a known duration',
    (tester) async {
      platform.duration = Duration.zero;
      await tester.pumpWidget(surface('AUDIO', () {}, () {}));
      await tester.pumpAndSettle();
      final tools = tester.widget<LessonPlaybackTools>(
        find.byType(LessonPlaybackTools),
      );
      expect(tools.onBackward, isNull);
      expect(tools.onForward, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'quick seek failure reports an error without leaving the player',
    (tester) async {
      platform.failSeek = true;
      var errors = 0;
      await tester.pumpWidget(surface('AUDIO', () {}, () => errors++));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Forward 10 seconds'));
      await tester.pumpAndSettle();
      expect(errors, 1);
      expect(platform.calls, isNot(contains('play')));
      expect(find.byType(LessonMediaSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  for (final kind in ['AUDIO', 'VIDEO']) {
    testWidgets(
      '$kind controls remain readable with enlarged text',
      (tester) async {
        await tester.pumpWidget(surface(kind, () {}, () {}, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Play'));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('play'));
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(platform.calls, contains('dispose'));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  testWidgets(
    'native player reports initialization failure without navigation',
    (tester) async {
      platform.fail = true;
      var ready = 0, failed = 0;
      await tester.pumpWidget(surface('VIDEO', () => ready++, () => failed++));
      await tester.pumpAndSettle();
      expect(ready, 0);
      expect(failed, greaterThan(0));
      expect(find.text('Unable to play this media'), findsOneWidget);
      expect(find.text('Opening media...'), findsNothing);
      expect(
        tester
            .widget<LessonPlaybackTools>(find.byType(LessonPlaybackTools))
            .onPlay,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'closing during initialization disposes late media safely',
    (tester) async {
      platform.delay = true;
      var ready = 0;
      await tester.pumpWidget(surface('VIDEO', () => ready++, () {}));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      platform.initialize();
      await tester.pumpAndSettle();
      expect(ready, 0);
      expect(platform.calls, contains('dispose'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
