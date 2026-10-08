import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final restore in [false, true]) {
    for (final saved in [false, true]) {
      testWidgets(
        'access feedback restore=$restore saved=$saved never retries the write',
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
              } else if (req.url.path.endsWith('/access-history')) {
                data = [
                  {
                    'id': 'event',
                    'action': 'platform.account.disabled',
                    'actorId': 'other-admin',
                    'createdAt': '2026-10-08T00:00:00Z',
                    'reason': 'Access under review',
                  },
                ];
              } else if (req.method == 'POST') {
                writes++;
                if (!saved) return http.Response('{}', 500);
                data = {
                  'id': 'it',
                  'status': restore ? 'ACTIVE' : 'DISABLED',
                  'revoked': 1,
                };
              } else if (req.url.path.endsWith('/accounts')) {
                if (writes > 0) return http.Response('{}', 503);
                data = [
                  {
                    'id': 'it',
                    'fullName': 'Security Operator',
                    'email': 'it@example.test',
                    'role': 'IT_SECURITY',
                    'status': restore ? 'DISABLED' : 'ACTIVE',
                    'createdAt': '2026-10-08T00:00:00Z',
                  },
                ];
              }
              return http.Response(jsonEncode({'data': data}), 200);
            }),
          );
          await api.login('admin@example.test', 'password', '123456');
          await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Company accounts'));
          await tester.tap(find.text('Company accounts'));
          await tester.pumpAndSettle();
          final action = restore ? 'Review restoration' : 'Disable IT account';
          await tester.ensureVisible(find.text(action));
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            ),
            'Security review completed',
          );
          await tester.tap(
            find.text(restore ? 'Confirm restore' : 'Confirm disable'),
          );
          await tester.pumpAndSettle();
          expect(writes, 1);
          expect(find.text(action), findsNothing);
          if (saved) {
            expect(
              find.textContaining('The access change was saved'),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                restore ? 'IT access restored.' : 'IT account disabled.',
              ),
              findsOneWidget,
            );
          } else {
            expect(
              find.textContaining('We could not confirm the access change.'),
              findsOneWidget,
            );
            expect(
              find.textContaining('The access change was saved'),
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
}
