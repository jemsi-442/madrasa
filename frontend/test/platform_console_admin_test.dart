import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final status in ['APPROVED', 'REJECTED', 'REQUESTED']) {
    testWidgets('application details and decision context for $status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PlatformApi(
        client: MockClient((req) async {
          final dynamic data = req.url.path.endsWith('/login')
              ? {
                  'accessToken': 'token',
                  'expiresIn': 900,
                  'user': {
                    'id': 'reviewer',
                    'fullName': 'Reviewer',
                    'role': 'SUPER_ADMIN',
                  },
                }
              : [
                  {
                    'id': 'request-1',
                    'schoolName': 'Afaq School',
                    'requestedCode': 'afaq-school',
                    'adminEmail': 'school@example.test',
                    'status': status,
                    'requestedById': 'requester',
                    'createdAt': '2026-10-08T09:00:00+03:00',
                    'reviewedById': status == 'REQUESTED' ? null : 'reviewer',
                    'reviewedAt': status == 'REQUESTED'
                        ? null
                        : '2026-10-08T10:00:00+03:00',
                    'decisionReason': status == 'REQUESTED'
                        ? null
                        : 'Ownership evidence reviewed',
                  },
                ];
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('reviewer@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Application details'));
      await tester.tap(find.text('Application details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Requested by account: requester'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-08T06:00:00.000Z'), findsOneWidget);
      if (status == 'REQUESTED') {
        expect(
          find.textContaining('Reviewed by account: Not yet reviewed'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Approve'));
        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Nominated admin: school@example.test'),
          findsOneWidget,
        );
        expect(
          find.text('This decision cannot be edited after confirmation.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } else {
        expect(
          find.textContaining('Reviewed by account: reviewer'),
          findsOneWidget,
        );
        expect(find.textContaining('2026-10-08T07:00:00.000Z'), findsOneWidget);
        expect(
          find.text('Decision: Ownership evidence reviewed'),
          findsOneWidget,
        );
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  testWidgets('requester cannot review own application in the console', (
    tester,
  ) async {
    final api = PlatformApi(
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'data': req.url.path.endsWith('/login')
                ? {
                    'accessToken': 'token',
                    'expiresIn': 900,
                    'user': {
                      'id': 'reviewer',
                      'fullName': 'Reviewer',
                      'role': 'SUPER_ADMIN',
                    },
                  }
                : [
                    {
                      'id': 'request',
                      'schoolName': 'Afaq School',
                      'requestedCode': 'afaq-school',
                      'status': 'REQUESTED',
                      'requestedById': 'reviewer',
                      'adminEmail': 'school@example.test',
                    },
                  ],
          }),
          200,
        ),
      ),
    );
    await api.login('reviewer@example.test', 'password', '123456');
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Request madrassa'), findsOneWidget);
    expect(
      find.text('Awaiting review by another Super Admin.'),
      findsOneWidget,
    );
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
