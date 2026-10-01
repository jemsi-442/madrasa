import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_page.dart';

const _featureTitles = [
  "Qur'an Tracking",
  'Student Management',
  'Progress Reports',
  'Community Support',
];

Widget _featuresAtWidth(double width) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: const SingleChildScrollView(child: PublicHomeFeatures()),
      ),
    ),
  ),
);

void main() {
  for (final width in [0.0, 1.0, 10.0, 19.0, 20.0, 54.0, 120.0]) {
    testWidgets('home features tolerate a transient width of $width', (
      tester,
    ) async {
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.getSize(find.byType(PublicHomeFeatures)).width, width);
    });
  }

  for (final (width, columns) in [
    (240.0, 1),
    (260.0, 2),
    (272.0, 2),
    (342.0, 2),
    (599.0, 2),
    (600.0, 4),
    (790.0, 4),
  ]) {
    testWidgets('home features use $columns columns at width $width', (
      tester,
    ) async {
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull);
      final tops = _featureTitles
          .map((title) => tester.getTopLeft(find.text(title)))
          .toList();
      for (var i = 0; i < tops.length; i++) {
        expect(tops[i].dy, tops[(i ~/ columns) * columns].dy);
        if (i % columns == 0 && i > 0) {
          expect(tops[i].dy, greaterThan(tops[i - 1].dy));
        }
        final rect = tester.getRect(find.text(_featureTitles[i]));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
    });
  }

  testWidgets('home features recover after their width collapses to zero', (
    tester,
  ) async {
    for (final width in [342.0, 0.0, 10.0, 342.0, 790.0, 0.0, 272.0]) {
      await tester.pumpWidget(_featuresAtWidth(width));
      expect(tester.takeException(), isNull, reason: 'width: $width');
      expect(find.byType(ErrorWidget), findsNothing);
      if (width >= 272) {
        for (final title in _featureTitles) {
          expect(find.text(title), findsOneWidget);
        }
      }
    }
  });

  testWidgets('home remains usable through phone and desktop resizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final navigation = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(home: PublicHomeScreen(onNavigate: navigation.add)),
    );

    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(320, 640),
      const Size(768, 1024),
      const Size(1440, 900),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      for (final title in _featureTitles) {
        expect(find.text(title), findsOneWidget);
      }
    }

    await tester.ensureVisible(find.text("Qur'an Tracking"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('header-login')));
    expect(navigation, ['/login']);
    expect(tester.takeException(), isNull);
  });
}
