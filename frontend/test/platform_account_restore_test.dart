import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  testWidgets(
    'restoration preserves disabled state on denial and refreshes on approval',
    (tester) async {
      var allow = false;
      var active = false;
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
                'role': 'SUPER_ADMIN',
              },
            };
          } else if (req.url.path.endsWith('/access-history')) {
            if (!historyAvailable) return http.Response('{}', 503);
            expect(req.url.queryParameters['pageSize'], '1');
            data = [
              {
                'id': 'suspension-1',
                'action': 'platform.account.disabled',
                'actorId': 'other-admin',
                'createdAt': '2026-10-08T00:00:00Z',
                'reason': 'Suspended pending access review',
              },
            ];
          } else if (req.url.path.endsWith('/restore')) {
            attempts++;
            expect(jsonDecode(req.body), {
              'reason': 'Suspension resolved and reviewed',
              'suspensionEventId': 'suspension-1',
            });
            if (!allow) return http.Response('{}', 403);
            active = true;
            data = {'id': 'it', 'status': 'ACTIVE', 'revoked': 0};
          } else if (req.url.path.endsWith('/accounts')) {
            data = [
              {
                'id': 'it',
                'fullName': 'Security Operator',
                'email': 'it@example.test',
                'role': 'IT_SECURITY',
                'status': active ? 'ACTIVE' : 'DISABLED',
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
      await tester.ensureVisible(find.text('Review restoration'));
      await tester.tap(find.text('Review restoration'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm restore'), findsNothing);
      expect(attempts, 0);
      historyAvailable = true;
      for (final permitted in [false, true]) {
        allow = permitted;
        await tester.ensureVisible(find.text('Review restoration'));
        await tester.tap(find.text('Review restoration'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Only a different Super Admin'),
          findsOneWidget,
        );
        expect(find.text('Suspended pending access review'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          'Suspension resolved and reviewed',
        );
        await tester.tap(find.text('Confirm restore'));
        await tester.pumpAndSettle();
        expect(find.text(permitted ? 'Active' : 'Disabled'), findsOneWidget);
      }
      expect(attempts, 2);
      expect(find.text('Review restoration'), findsNothing);
      expect(find.text('Disable IT account'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
