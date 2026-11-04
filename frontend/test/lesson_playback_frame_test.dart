import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_playback_frame.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';

void main() {
  for (final size in [const Size(800, 450), const Size(390, 420)]) {
    testWidgets('course video uses responsive overlay controls at $size', (
      t,
    ) async {
      var plays = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: LessonPlaybackFrame(
                  overlayControls: true,
                  ready: true,
                  failed: false,
                  onPlay: () => plays++,
                  controls: SizedBox(
                    height: 80,
                    child: TextButton(
                      onPressed: () => plays++,
                      child: const Text('Transport play'),
                    ),
                  ),
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final overlay = size.width >= 652;
      expect(
        find.byKey(const ValueKey('video-overlay-layout')),
        overlay ? findsOneWidget : findsNothing,
      );
      expect(
        t.getSize(find.byKey(const ValueKey('playback-screen'))).height,
        overlay ? size.height : size.height - 80,
      );
      await t.tap(find.text('Transport play'));
      expect(plays, 1);
      await t.tap(find.byTooltip('Play video'));
      expect(plays, 2);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('central Play gives the stage keyboard focus', (t) async {
    var plays = 0, fullscreen = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 440,
            child: LessonPlaybackFrame(
              ready: true,
              failed: false,
              onPlay: () => plays++,
              onFullscreen: () => fullscreen++,
              controls: const SizedBox(height: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byTooltip('Play video'));
    await t.pump();
    expect(plays, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(plays, 2);
    expect(fullscreen, 1);
  });

  for (final audio in [true, false]) {
    testWidgets(
      'fullscreen shortcut is ignored for ${audio ? 'audio' : 'failed video'}',
      (t) async {
        var requests = 0;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 440,
                child: LessonPlaybackFrame(
                  ready: audio,
                  failed: !audio,
                  audio: audio,
                  onFullscreen: () => requests++,
                  controls: const SizedBox(height: 80),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const ValueKey('playback-screen')));
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.keyF);
        expect(requests, 0);
      },
    );
  }

  testWidgets('short frames keep the stage visible and controls scrollable', (
    t,
  ) async {
    var pressed = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: LessonPlaybackFrame(
              ready: true,
              failed: false,
              playing: true,
              controls: Column(
                children: [
                  const SizedBox(height: 300),
                  TextButton(
                    onPressed: () => pressed = true,
                    child: const Text('Last control'),
                  ),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('playback-screen'))).height,
      greaterThanOrEqualTo(40),
    );
    await t.ensureVisible(find.text('Last control'));
    await t.pumpAndSettle();
    await t.tap(find.text('Last control'));
    expect(pressed, isTrue);
    expect(t.takeException(), isNull);
  });

  test('playback clock formats long durations and clamps negative times', () {
    expect(playbackTime(const Duration(seconds: -3)), '0:00');
    expect(playbackTime(const Duration(seconds: 65)), '1:05');
    expect(playbackTime(const Duration(seconds: 3665)), '1:01:05');
  });

  testWidgets('stage shortcuts control playback without stealing button keys', (
    t,
  ) async {
    var plays = 0, back = 0, forward = 0, mutes = 0, stops = 0, fullscreen = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 440,
            child: LessonPlaybackFrame(
              ready: true,
              failed: false,
              playing: true,
              onPlay: () => plays++,
              onBackward: () => back++,
              onForward: () => forward++,
              onMute: () => mutes++,
              onFullscreen: () => fullscreen++,
              controls: LessonPlaybackTools(speed: 1, onStop: () => stops++),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('playback-screen')));
    await t.pump();
    expect(plays, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.keyM);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(fullscreen, 1);
    expect([plays, back, forward, mutes], [2, 1, 1, 1]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(back, 1);
    expect(fullscreen, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(fullscreen, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(stops, 1);
    expect(plays, 2);
  });

  testWidgets('failed stage has no loading or playable placeholder', (t) async {
    var plays = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 440,
            child: LessonPlaybackFrame(
              ready: false,
              failed: true,
              onPlay: () => plays++,
              controls: const LessonPlaybackTools(speed: 1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('playback-screen')));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(plays, 0);
    expect(find.text('Unable to play this media'), findsOneWidget);
    expect(find.text('Opening media...'), findsNothing);
    expect(find.byTooltip('Play video'), findsNothing);
  });

  testWidgets('timeline commits on release and desktop volume is adjustable', (
    t,
  ) async {
    final seeks = <Duration>[], volumes = <double>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonPlaybackTools(
            speed: 1,
            duration: const Duration(minutes: 2),
            onSeek: seeks.add,
            onVolume: volumes.add,
          ),
        ),
      ),
    );
    final timeline = find.byKey(const ValueKey('playback-timeline'));
    final rect = t.getRect(timeline);
    final gesture = await t.startGesture(
      Offset(rect.left + 30, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.center.dy));
    await t.pump();
    expect(seeks, isEmpty);
    await gesture.up();
    await t.pump();
    expect(seeks.single.inSeconds, closeTo(60, 2));
    await t.tap(find.byKey(const ValueKey('playback-volume')));
    await t.pump();
    expect(volumes.last, closeTo(.5, .1));
    expect(t.takeException(), isNull);
  });
}
