import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final saved in [true, false]) {
    testWidgets(
      'application feedback distinguishes confirmed save=$saved from uncertainty',
      (tester) async {
        var writes = 0;
        final api = PlatformApi(
          client: MockClient((req) async {
            dynamic data;
            if (req.url.path.endsWith('/login')) {
              data = {
                'accessToken': 'token',
                'expiresIn': 900,
                'user': {
                  'id': 'reviewer',
                  'fullName': 'Reviewer',
                  'role': 'SUPER_ADMIN',
                },
              };
            } else if (req.url.path.endsWith('/review')) {
              writes++;
              if (!saved) return http.Response('{}', 500);
              data = {'id': 'request', 'status': 'APPROVED'};
            } else {
              if (writes > 0) return http.Response('{}', 503);
              data = [
                {
                  'id': 'request',
                  'schoolName': 'Afaq School',
                  'requestedCode': 'afaq-school',
                  'adminEmail': 'school@example.test',
                  'status': 'REQUESTED',
                  'requestedById': 'other',
                },
              ];
            }
            return http.Response(jsonEncode({'data': data}), 200);
          }),
        );
        await api.login('reviewer@example.test', 'password', '123456');
        await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Approve'));
        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          'Ownership evidence verified',
        );
        await tester.tap(find.text('Confirm decision'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(find.text('Approve'), findsNothing);
        if (saved) {
          expect(
            find.text('Approval saved. This does not activate the madrassa.'),
            findsOneWidget,
          );
          expect(
            find.textContaining('The change was saved, but the list'),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('We could not confirm whether'),
            findsOneWidget,
          );
          expect(
            find.text('Approval saved. This does not activate the madrassa.'),
            findsNothing,
          );
        }
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
}
