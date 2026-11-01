import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_administration.dart';

void main() {
  for (final entry in [
    ('NOT_ISSUED', 'No invitation recorded.'),
    ('AWAITING_ACCEPTANCE', 'Invitation awaiting acceptance.'),
    ('AWAITING_ACTIVATION', 'Administrator is waiting for activation.'),
    ('ACCEPTED', 'Invitation accepted.'),
    ('EXPIRED', 'Invitation expired.'),
    ('REVIEW_REQUIRED', 'records need review.'),
  ]) {
    testWidgets(
      'shows ${entry.$1} separately from account and madrasa status',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: MadrasaAdministration(
                    record: {
                      'status': 'SUSPENDED',
                      'invitationStatus': entry.$1,
                      'adminAccounts': [
                        {'fullName': 'Synthetic Admin', 'status': 'ACTIVE'},
                        {
                          'fullName': 'Synthetic Disabled Admin',
                          'status': 'DISABLED',
                        },
                      ],
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining(entry.$2), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.text('DISABLED'), findsOneWidget);
        expect(find.textContaining('even for active accounts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
