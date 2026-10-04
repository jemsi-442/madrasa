import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_playback_frame.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';

void main() {
  test('playback clock formats long durations and clamps negative times', () {
    expect(playbackTime(const Duration(seconds: -3)), '0:00');
    expect(playbackTime(const Duration(seconds: 65)), '1:05');
    expect(playbackTime(const Duration(seconds: 3665)), '1:01:05');
  });

  testWidgets('stage shortcuts control playback without stealing button keys', (
    t,
  ) async {
    var plays = 0, back = 0, forward = 0, mutes = 0, stops = 0;
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
    expect([plays, back, forward, mutes], [2, 1, 1, 1]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(back, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
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
