import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  testWidgets(
    'audit filter sends exact query and opens event details on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final api = PlatformApi(
        client: MockClient((req) async {
          requests.add(req.url);
          return http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {
                      'accessToken': 'token',
                      'expiresIn': 900,
                      'user': {
                        'id': 'it',
                        'fullName': 'IT Operator',
                        'role': 'IT_SECURITY',
                      },
                    }
                  : [
                      {
                        'id': 'event-123',
                        'actorId': 'target',
                        'actorRole': 'SUPER_ADMIN',
                        'action': 'platform.login.failed',
                        'entityType': 'PlatformAccount',
                        'entityId': 'target',
                        'createdAt': '2026-10-08T00:00:00Z',
                        'metadata': {},
                      },
                    ],
            }),
            200,
          );
        }),
      );
      await api.login('it@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Audit trail'));
      await tester.tap(find.text('Audit trail'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('All events'));
      await tester.tap(find.text('All events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed login').last);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['action'], 'platform.login.failed');
      expect(requests.last.queryParameters['page'], '1');
      await tester.ensureVisible(find.text('Event details'));
      await tester.tap(find.text('Event details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Event ID: event-123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
