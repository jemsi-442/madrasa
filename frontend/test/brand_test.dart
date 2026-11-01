import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/brand.dart';
import 'package:mif_app/src/foundation_ui.dart';
import 'package:mif_app/src/public_shell.dart';

void main() {
  testWidgets('compact mark preserves Afaq identity without a wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 76,
            height: 76,
            child: PublicBrand(compact: true, markOnly: true),
          ),
        ),
      ),
    );
    expect(find.text('Afaq'), findsNothing);
    expect(find.bySemanticsLabel('Afaq'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('public brand uses the shared app name', () {
    expect(appBrandName, 'Afaq');
    expect(publicBrandName, appBrandName);
  });

  testWidgets('shared brand marks display Afaq', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Column(children: [BrandMark(), PublicBrand()])),
      ),
    );
    expect(find.text('Afaq'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
