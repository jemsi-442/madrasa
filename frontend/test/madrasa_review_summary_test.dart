import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_review_summary.dart';

void main() {
  for (final width in [360.0, 1000.0]) {
    for (final approving in [true, false]) {
      testWidgets('review summary $width approval=$approving is readable', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MadrasaReviewSummary(
                    approving: approving,
                    record: {
                      'schoolName': 'Synthetic Madrasa',
                      'requestedCode': 'synthetic',
                      'adminEmail': 'synthetic@example.test',
                      'location': {
                        'country': 'Tanzania',
                        'region': 'Synthetic Region',
                      },
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Madrasa & administrator'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Not recorded'), findsNWidgets(2));
        expect(find.text('Government registration number'), findsNothing);
        expect(
          find.text(
            approving ? 'Approve registration' : 'Decline registration',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('cannot be edited'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
