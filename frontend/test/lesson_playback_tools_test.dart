import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/lesson_playback_tools.dart';

void main() {
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
