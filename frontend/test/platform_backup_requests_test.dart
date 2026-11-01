import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_backup_requests.dart';

void main() {
  testWidgets('Failed save keeps form and retry identity', (tester) async {
    final attempts = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformBackupRequests(
            onAudit: () {},
            request: (path, body) async {
              if (body == null) return {'items': [], 'total': 0};
              attempts.add(body);
              throw Exception('Synthetic connection failure');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request restore test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'BKP-SYNTHETIC');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Synthetic isolated recovery',
    );
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    expect(find.text('BKP-SYNTHETIC'), findsOneWidget);
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    expect(attempts.length, 2);
    expect(attempts[0]['requestId'], attempts[1]['requestId']);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });
}
