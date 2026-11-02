import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_photo.dart';
import 'package:mif_app/src/home_story_sections.dart';

void main() {
  for (final width in [320.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'original team image and zoom fit $width at text scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(child: HomeTeamSection()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('The people behind Afaq.'), findsOneWidget);
          expect(find.byType(HomePhoto), findsOneWidget);
          final photo = tester.widget<HomePhoto>(find.byType(HomePhoto));
          expect(photo.asset, 'assets/home/team.png');
          expect(photo.aspectRatio, 16 / 9);
          await tester.ensureVisible(find.text('View full team image'));
          await tester.tap(find.text('View full team image'));
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsOneWidget);
          final viewer = tester.widget<InteractiveViewer>(
            find.byType(InteractiveViewer),
          );
          final transform = viewer.transformationController!;
          expect(
            tester
                .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.remove),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byTooltip('Zoom in'));
          await tester.pump();
          expect(transform.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
          await tester.tap(find.byTooltip('Zoom out'));
          await tester.pump();
          expect(transform.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
          for (var i = 0; i < 5; i++) {
            await tester.tap(find.byTooltip('Zoom in'));
            await tester.pump();
          }
          expect(transform.value.getMaxScaleOnAxis(), 6);
          expect(
            tester
                .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
                .onPressed,
            isNull,
          );
          await tester.tap(find.byTooltip('Fit image'));
          await tester.pump();
          expect(transform.value, Matrix4.identity());
          await tester.sendKeyEvent(LogicalKeyboardKey.equal);
          await tester.pump();
          expect(transform.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
          transform.value = Matrix4.identity()
            ..setEntry(0, 0, 1.5)
            ..setEntry(1, 1, 1.5)
            ..setEntry(0, 3, -40);
          await tester.sendKeyEvent(LogicalKeyboardKey.minus);
          await tester.pump();
          expect(transform.value, Matrix4.identity());
          await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
          await tester.pump();
          expect(transform.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));
          await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
          await tester.pump();
          expect(transform.value, Matrix4.identity());
          await tester.tap(find.byTooltip('Close team image'));
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsNothing);
          await tester.tap(find.text('View full team image'));
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(InteractiveViewer), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
