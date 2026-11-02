import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/it_workspace_visuals.dart';

void main() {
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
      expect(tester.takeException(), isNull);
    });
  }
}
