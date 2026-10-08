import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/school_invitation_page.dart';

Future<void> fill(
  WidgetTester tester, {
  String password = 'long-password-for-test',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Invitation code'),
    't' * 43,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Full name'),
    'School Administrator',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'New password'),
    password,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm password'),
    password,
  );
  await tester.ensureVisible(find.text('Accept invitation'));
}

void main() {
  test(
    'acceptance uses only a POST body and no authorization or URL secrets',
    () async {
      final api = SchoolInvitationApi(
        baseUrl: 'https://school.example.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://school.example.test/api/school-invitations/accept',
          );
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'token': 't' * 43,
            'fullName': 'Admin',
            'password': 'private-password',
          });
          return http.Response(
            '{"success":true,"data":{"status":"PENDING_ACTIVATION"}}',
            200,
          );
        }),
      );
      await api.accept('t' * 43, 'Admin', 'private-password');
      api.close();
    },
  );
  for (final status in [410, 422, 429, 409, 503]) {
    test(
      'sanitizes acceptance error $status without reflecting server body',
      () async {
        final api = SchoolInvitationApi(
          client: MockClient(
            (_) async => http.Response('private server details', status),
          ),
        );
        await expectLater(
          api.accept('t' * 43, 'Admin', 'private-password'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              isNot(contains('private server details')),
            ),
          ),
        );
        api.close();
      },
    );
  }
  test('does not claim success on an unexpected success payload', () async {
    final api = SchoolInvitationApi(
      client: MockClient(
        (_) async => http.Response(
          '{"success":true,"data":{"accessToken":"unexpected"}}',
          200,
        ),
      ),
    );
    await expectLater(
      api.accept('t' * 43, 'Admin', 'private-password'),
      throwsA(isA<ApiException>()),
    );
    api.close();
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('acceptance remains pending and fits width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final api = SchoolInvitationApi(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            '{"success":true,"data":{"status":"PENDING_ACTIVATION"}}',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SchoolInvitationPage(api: api)),
      );
      await fill(tester);
      await tester.tap(find.text('Accept invitation'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Waiting for activation'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('No sign-in session'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  testWidgets('validation blocks oversize Unicode passwords before sending', (
    tester,
  ) async {
    var requests = 0;
    final api = SchoolInvitationApi(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 503);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: SchoolInvitationPage(api: api)));
    await fill(tester, password: '\u00e9' * 37);
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Password exceeds 72 UTF-8 bytes.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets(
    'in-flight submission is single-shot and unavailable response clears passwords',
    (tester) async {
      var requests = 0;
      final pending = Completer<http.Response>();
      final api = SchoolInvitationApi(
        client: MockClient((_) {
          requests++;
          return pending.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SchoolInvitationPage(api: api)),
      );
      await fill(tester);
      await tester.tap(find.text('Accept invitation'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, 1);
      pending.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for activation'), findsNothing);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      for (final label in ['New password', 'Confirm password']) {
        expect(
          tester
              .widget<TextFormField>(find.widgetWithText(TextFormField, label))
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
