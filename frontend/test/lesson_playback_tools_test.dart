import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';

void main() {
  testWidgets('browser fullscreen has a distinct control and action', (
    t,
  ) async {
    var requests = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonPlaybackTools(
            speed: 1,
            fullscreenControl: true,
            onFocus: () => requests++,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Expand player'), findsNothing);
    await t.tap(find.byTooltip('Fullscreen'));
    expect(requests, 1);
  });

  for (final width in [320.0, 680.0, 1200.0]) {
    testWidgets('player groups fit at width $width', (t) async {
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var plays = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonPlaybackTools(
              speed: 1,
              duration: const Duration(minutes: 4),
              position: const Duration(seconds: 32),
              onPlay: () => plays++,
              onFocus: () {},
            ),
          ),
        ),
      );
      final transport = find.byKey(const ValueKey('playback-transport'));
      final settings = find.byKey(const ValueKey('playback-settings'));
      expect(find.text('0:32 / 4:00'), findsOneWidget);
      expect(
        t.getSize(find.byTooltip('Play')).height,
        greaterThanOrEqualTo(48),
      );
      if (width == 320) {
        expect(
          t.getSize(find.byType(LessonPlaybackTools)).height,
          lessThanOrEqualTo(190),
        );
        final timeline = t.getRect(
          find.byKey(const ValueKey('playback-timeline')),
        );
        final clock = t.getRect(find.text('0:32 / 4:00'));
        expect(clock.center.dy, closeTo(timeline.center.dy, 1));
        expect(
          t.getTopLeft(settings).dy,
          greaterThan(t.getBottomLeft(transport).dy),
        );
      }
      await t.tap(find.byTooltip('Play'));
      expect(plays, 1);
      expect(t.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('quick tools fit a small player at text scale $scale', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      try {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        var backward = 0, forward = 0;
        double? selected;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: LessonPlaybackTools(
                  speed: 1.25,
                  onBackward: () => backward++,
                  onForward: () => forward++,
                  onSpeed: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byTooltip('Back 10 seconds'));
        await t.tap(find.byTooltip('Forward 10 seconds'));
        expect(backward, 1);
        expect(forward, 1);
        expect(
          t.getSize(find.byType(PopupMenuButton<double>)).height,
          greaterThanOrEqualTo(48),
        );
        await t.tap(find.byTooltip('Playback speed'));
        await t.pumpAndSettle();
        expect(find.byType(CheckedPopupMenuItem<double>), findsNWidgets(6));
        final current = t
            .widgetList<CheckedPopupMenuItem<double>>(
              find.byType(CheckedPopupMenuItem<double>),
            )
            .where((item) => item.checked);
        expect(current.single.value, 1.25);
        await t.tap(find.byKey(const ValueKey('playback-speed-1x')));
        await t.pumpAndSettle();
        expect(selected, 1);
        expect(
          t
              .getSemantics(find.byType(PopupMenuButton<double>))
              .flagsCollection
              .isButton,
          isTrue,
        );
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('unready controls do not open the speed menu', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: LessonPlaybackTools(speed: 1))),
    );
    final buttons = t.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    expect(
      t
          .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
          .enabled,
      isFalse,
    );
    await t.tap(find.byTooltip('Playback speed'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<double>), findsNothing);
  });
}
