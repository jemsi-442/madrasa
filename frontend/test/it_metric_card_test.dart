import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/it_workspace_visuals.dart';
import 'package:mif_app/src/design_tokens.dart';

void main() {
  test('Card palette keeps navy text readable across gradient stops', () {
    for (final accent in [
      AfaqDesign.blue,
      AfaqDesign.green,
      AfaqDesign.gold,
      AfaqDesign.purple,
      Colors.red,
      Colors.grey,
    ]) {
      for (final background in AfaqDesign.cardGradient(accent).colors) {
        final contrast =
            (background.computeLuminance() + .05) /
            (AfaqDesign.ink.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });
  for (final width in [220.0, 320.0, 600.0]) {
    testWidgets('IT metric preserves long values at $width with large text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: const ItMetricCard(
                    label: 'Connected madrasas',
                    value: 'Not measured',
                    icon: Icons.account_balance_outlined,
                    accent: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final value = tester.widget<Text>(find.text('Not measured'));
      expect(value.maxLines, isNull);
      expect(value.overflow, isNot(TextOverflow.ellipsis));
      final surface = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ItMetricCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(
        (decoration.gradient! as LinearGradient).colors.first,
        AfaqDesign.cardTint(Colors.blue, .30),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
