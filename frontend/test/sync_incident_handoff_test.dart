import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_sync_register.dart';
import 'package:mif_app/src/security_incident_register.dart';

void main() {
  testWidgets(
    'Receipt investigation opens an editable draft without saving automatically',
    (tester) async {
      String? draft;
      final writes = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, change) => draft == null
                  ? SingleChildScrollView(
                      child: PlatformSyncRegister(
                        onAudit: () {},
                        onIncidents: () {},
                        onInvestigate: (value) => change(() => draft = value),
                        request: (_) async => {
                          'items': [
                            {
                              'receiptId': 'SYNTHETIC-RECEIPT',
                              'madrasaId': 'SYNTHETIC-MADRASA',
                              'receivedAt': '2026-01-01T00:00:00Z',
                              'unexpectedPrivateField': 'MUST-NOT-BE-COPIED',
                            },
                          ],
                          'total': 1,
                          'capturedAt': '2026-01-01T00:00:00Z',
                        },
                      ),
                    )
                  : SecurityIncidentRegister(
                      initialDescription: draft,
                      request: (path, body) async {
                        if (body != null) {
                          writes.add(body);
                          throw Exception('Synthetic save failure');
                        }
                        return {
                          'items': [],
                          'total': 0,
                          'open': 0,
                          'high': 0,
                          'resolved': 0,
                        };
                      },
                    ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Investigate receipt'));
      await tester.tap(find.text('Investigate receipt'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(writes, isEmpty);
      expect(draft, contains('SYNTHETIC-RECEIPT'));
      expect(draft, contains('SYNTHETIC-MADRASA'));
      expect(draft, isNot(contains('MUST-NOT-BE-COPIED')));
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        draft,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.enterText(fields.at(0), 'Synthetic receipt investigation');
      await tester.enterText(
        fields.at(1),
        '${draft!}Review the reported delay.',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(
        writes.single['description'],
        contains('Review the reported delay.'),
      );
      expect(writes.single['description'], contains('SYNTHETIC-RECEIPT'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
