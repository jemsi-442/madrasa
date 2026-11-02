import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_photo.dart';
import 'package:mif_app/src/home_story_sections.dart';

void main() {
  for (final width in [320.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('team cards fit width $width at text scale $scale', (
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
        for (final name in [
          'Kassim Iddi',
          'Miraji Hamidu',
          'Mrs. Ismail',
          'Zuberi Bani',
        ]) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.byType(HomePhoto), findsNWidgets(4));
        expect(find.text('Mentor & Advisor'), findsNWidgets(2));
        final first = tester.getTopLeft(find.byType(HomePhoto).at(0));
        final second = tester.getTopLeft(find.byType(HomePhoto).at(1));
        if (width == 320 || scale == 2) {
          expect(second.dy, greaterThan(first.dy));
        } else {
          expect(second.dy, first.dy);
          expect(second.dx, greaterThan(first.dx));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
