import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/curriculum_oversight_report.dart';

void main() {
  testWidgets('compact Quran view shows only the selected activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => const CurriculumOversightReport(
                rows: [],
                compact: true,
                quran: {
                  'activities': [
                    {'activity': 'READING', 'sessions': 12},
                    {'activity': 'MEMORIZATION', 'sessions': 7},
                  ],
                },
              ).quranPanel(context),
            ),
          ),
        ),
      ),
    );
    expect(find.text('12 recorded sessions'), findsOneWidget);
    expect(find.text('7 recorded sessions'), findsNothing);
    await tester.tap(find.text('Hifz'));
    await tester.pumpAndSettle();
    expect(find.text('12 recorded sessions'), findsNothing);
    expect(find.text('7 recorded sessions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
