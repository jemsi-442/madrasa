import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/home_photo.dart';

void main() {
  testWidgets('missing photo keeps its reserved space and readable fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: HomePhoto(
                asset: 'assets/missing-test-photo.jpg',
                description: 'Test photo',
                aspectRatio: 2,
              ),
            ),
          ),
        ),
      ),
    );
    final initialSize = tester.getSize(find.byType(HomePhoto));
    expect(initialSize, const Size(320, 160));
    await tester.pumpAndSettle();
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(tester.getSize(find.byType(HomePhoto)), initialSize);
    expect(tester.takeException(), isNull);
  });
}
