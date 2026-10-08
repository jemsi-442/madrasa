import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final accountAction in [false, true]) {
    for (final replaceSession in [false, true]) {
      testWidgets(
        'dialog blocks stale action account=$accountAction replaced=$replaceSession',
        (tester) async {
          var writes = 0;
          final api = PlatformApi(
            client: MockClient((req) async {
              dynamic data = [];
              if (req.url.path.endsWith('/login')) {
                data = {
                  'accessToken': 'token',
                  'expiresIn': 900,
                  'user': {
                    'id': 'admin',
                    'fullName': 'Reviewer',
                    'role': 'SUPER_ADMIN',
                  },
                };
              } else if (req.method == 'POST') {
                writes++;
                data = {};
              } else if (req.url.path.endsWith('/accounts')) {
                data = [
                  {
                    'id': 'it',
                    'fullName': 'Operator',
                    'email': 'it@example.test',
                    'role': 'IT_SECURITY',
                    'status': 'ACTIVE',
                  },
                ];
              } else {
                data = [
                  {
                    'id': 'request',
                    'schoolName': 'School',
                    'requestedCode': 'school-code',
                    'adminEmail': 'school@example.test',
                    'status': 'REQUESTED',
                    'requestedById': 'other',
                  },
                ];
              }
              return http.Response(jsonEncode({'data': data}), 200);
            }),
          );
          await api.login('admin@example.test', 'password', '123456');
          api.expiresAt = DateTime.now().add(const Duration(seconds: 30));
          await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
          final tab = accountAction ? 'Company accounts' : 'Refresh';
          await tester.ensureVisible(find.text(tab));
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(accountAction ? 'Disable IT account' : 'Approve'),
          );
          await tester.tap(
            find.text(accountAction ? 'Disable IT account' : 'Approve'),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            ),
            'Reviewed under the original session',
          );
          if (replaceSession) {
            await api.login('admin@example.test', 'password', '654321');
            await tester.tap(
              find.text(accountAction ? 'Confirm disable' : 'Confirm decision'),
            );
            await tester.pumpAndSettle();
          } else {
            await tester.pump(const Duration(seconds: 31));
            await tester.pumpAndSettle();
            expect(find.text('Platform sign in'), findsOneWidget);
          }
          expect(find.byType(AlertDialog), findsNothing);
          expect(writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          api.close();
        },
      );
    }
  }
}
