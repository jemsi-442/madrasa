import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:mif_app/src/lesson_media_delivery.dart';
import 'package:mif_app/src/platform/lesson_media_native.dart';

class TestMediaPlatform extends VideoPlayerPlatform {
  late final StreamController<VideoEvent> events;
  final calls = <String>[];
  String? source;
  bool fail = false;
  bool delay = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    events = StreamController<VideoEvent>();
    source = options.dataSource.uri;
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
      duration: const Duration(seconds: 30),
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
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
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
    VoidCallback failed,
  ) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 280,
        height: kind == 'AUDIO' ? 90 : 240,
        child: LessonMediaSurface(
          delivery: LessonMediaDelivery(
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
        await tester.tap(find.byType(LinearProgressIndicator).last);
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
    'native player reports initialization failure without navigation',
    (tester) async {
      platform.fail = true;
      var ready = 0, failed = 0;
      await tester.pumpWidget(surface('VIDEO', () => ready++, () => failed++));
      await tester.pumpAndSettle();
      expect(ready, 0);
      expect(failed, greaterThan(0));
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
