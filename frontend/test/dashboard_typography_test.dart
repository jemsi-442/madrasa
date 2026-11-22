import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/dashboard_components.dart';

void main() {
  for (final (width, scale, stacked) in [
    (320.0, 1.0, true),
    (600.0, 2.0, true),
    (1000.0, 1.0, false),
  ]) {
    testWidgets('panel heading action layout at $width and $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: PanelHeading(
                'Recorded learning activity',
                subtitle: 'Review the records for your assigned classes.',
                action: OutlinedButton(
                  onPressed: () => opened = true,
                  child: const Text('View records'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = tester.getRect(find.byType(OutlinedButton));
      final subtitle = tester.getRect(
        find.text('Review the records for your assigned classes.'),
      );
      if (stacked) {
        expect(action.top, greaterThan(subtitle.bottom));
      } else {
        expect(action.left, greaterThan(subtitle.right));
      }
      await tester.tap(find.byType(OutlinedButton));
      expect(opened, isTrue);
    });
  }
  for (final width in [320.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('chart labels remain readable at $width and $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      PanelHeading('Learning activity', subtitle: 'This month'),
                      RingChart(
                        center: '24',
                        caption: 'Lessons',
                        items: [
                          ChartDatum('Completed lessons', 24, Colors.green),
                          ChartDatum('In progress', 12, Colors.amber),
                        ],
                      ),
                      ColumnChart(
                        items: [
                          ChartDatum('Long subject name', 24, Colors.blue),
                          ChartDatum('Second subject', 12, Colors.green),
                          ChartDatum('Third subject', 0, Colors.amber),
                          ChartDatum('Fourth subject', 5, Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['This month', 'Lessons', 'Long subject name']) {
          expect(
            tester.widget<Text>(find.text(label)).style!.fontSize,
            greaterThanOrEqualTo(14),
          );
        }
        expect(find.byTooltip('Long subject name'), findsOneWidget);
      });
    }
  }
}
