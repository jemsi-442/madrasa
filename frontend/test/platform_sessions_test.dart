import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/platform_navigation.dart';

void main() {
  testWidgets(
    'current session revocation requires confirmation and returns to sign in',
    (tester) async {
      var revocations = 0;
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data;
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {
                'id': 'it',
                'fullName': 'IT Operator',
                'role': 'IT_SECURITY',
              },
            };
          } else if (req.url.path.endsWith('/revoke')) {
            revocations++;
            data = {'revoked': 1, 'current': true};
          } else {
            data = [
              {
                'id': 'session',
                'current': true,
                'createdAt': '2026-10-08T00:00:00Z',
                'expiresAt': '2026-10-08T00:15:00Z',
              },
            ];
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('it@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await openPlatformPage(tester, 'My sessions');
      expect(find.text('Current session'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign out this session'));
      await tester.tap(find.text('Sign out this session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(revocations, 0);
      await tester.tap(find.text('Sign out this session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke session'));
      await tester.pumpAndSettle();
      expect(revocations, 1);
      expect(api.user, isNull);
      expect(find.text('Platform sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
