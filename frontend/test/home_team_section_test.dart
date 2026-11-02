import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_photo.dart';
import 'package:mif_app/src/home_story_sections.dart';

void main() {
  for (final width in [320.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('original team image and zoom fit $width at text scale $scale', (
        tester,
      ) async {
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
        await tester.tap(find.byTooltip('Close team image'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
