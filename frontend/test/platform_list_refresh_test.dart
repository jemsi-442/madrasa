import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final view in [
    'Madrassa applications',
    'Office history',
    'Company accounts',
    'My sessions',
  ]) {
    testWidgets(
      '$view hides stale records during failed refresh and permits retry',
      (tester) async {
        final pending = Completer<http.Response>();
        var phase = 0;
        var reads = 0;
        var writes = 0;
        final api = PlatformApi(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'accessToken': 'token',
                    'expiresIn': 900,
                    'user': {
                      'id': 'admin',
                      'fullName': 'Reviewer',
                      'role': view == 'My sessions'
                          ? 'IT_SECURITY'
                          : 'SUPER_ADMIN',
                    },
                  },
                }),
                200,
              );
            }
            if (request.method != 'GET') writes++;
            reads++;
            if (phase == 1) return pending.future;
            return http.Response(
              jsonEncode({
                'data': phase == 2
                    ? []
                    : [
                        {
                          'id': 'snapshot-record',
                          'schoolName': 'snapshot-record',
                          'requestedCode': 'school',
                          'status': 'ACTIVE',
                          'adminEmail': 'school@example.test',
                          'fullName': 'snapshot-record',
                          'email': 'it@example.test',
                          'role': 'IT_SECURITY',
                          'actorRole': 'IT_SECURITY',
                          'action': 'snapshot-record',
                          'entityType': 'PlatformAccount',
                          'entityId': 'operator',
                          'current': false,
                          'createdAt': '2026-10-08T00:00:00Z',
                          'expiresAt': '2026-10-08T00:15:00Z',
                        },
                      ],
              }),
              200,
            );
          }),
        );
        await api.login('admin@example.test', 'password', '123456');
        await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
        await tester.ensureVisible(find.text(view));
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        expect(find.textContaining('snapshot-record'), findsWidgets);
        final before = reads;
        phase = 1;
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pump();
        expect(find.textContaining('snapshot-record'), findsNothing);
        expect(find.text('No records to display.'), findsNothing);
        await tester.tap(find.text('Refresh'));
        expect(reads, before + 1);
        pending.complete(http.Response('private error details', 503));
        await tester.pumpAndSettle();
        expect(find.textContaining('snapshot-record'), findsNothing);
        expect(
          find.textContaining('Platform access is not available yet'),
          findsOneWidget,
        );
        expect(find.textContaining('private error details'), findsNothing);
        expect(find.text('No records to display.'), findsNothing);
        phase = 2;
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(find.text('No records to display.'), findsOneWidget);
        expect(
          find.textContaining('Platform access is not available yet'),
          findsNothing,
        );
        expect(reads, before + 2);
        expect(writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
}
