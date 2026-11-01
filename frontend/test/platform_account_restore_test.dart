import 'helpers/platform_navigation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  testWidgets(
    'IT review preserves disabled state when access history is denied',
    (tester) async {
      var attempts = 0;
      var historyAvailable = false;
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
                'role': 'IT_SECURITY',
              },
            };
          } else if (req.url.path.endsWith('/access-history')) {
            if (!historyAvailable) return http.Response('{}', 403);
            expect(req.url.queryParameters['pageSize'], '20');
            data = [
              {
                'id': 'suspension-1',
                'action': 'platform.account.disabled',
                'actorId': 'other-admin',
                'createdAt': '2026-10-08T00:00:00Z',
                'reason': 'Suspended pending access review',
              },
            ];
          } else if (req.method != 'GET') {
            attempts++;
            return http.Response('{}', 403);
          } else if (req.url.path.endsWith('/accounts')) {
            data = [
              {
                'id': 'it',
                'fullName': 'Security Operator',
                'email': 'it@example.test',
                'role': 'IT_SECURITY',
                'status': 'DISABLED',
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
      await openPlatformPage(tester, 'Company accounts');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Access history'));
      await tester.tap(find.text('Access history'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm restore'), findsNothing);
      expect(find.text('Suspended pending access review'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      historyAvailable = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Suspended pending access review'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('DISABLED'), findsOneWidget);
      expect(find.text('Review restoration'), findsNothing);
      expect(find.text('Disable IT account'), findsNothing);
      expect(attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
