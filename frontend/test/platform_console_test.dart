import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/platform_console.dart';

Map<String, dynamic> loginResponse(String role) => {
  'accessToken': 'platform-token',
  'expiresIn': 900,
  'user': {'id': 'reviewer', 'fullName': 'Afaq Reviewer', 'role': role},
};
http.Response success(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  test(
    'platform token only goes to platform endpoints and is not shared between clients',
    () async {
      final seen = <http.Request>[];
      final api = PlatformApi(
        baseUrl: 'http://localhost:4000',
        client: MockClient((req) async {
          seen.add(req);
          return success(
            req.url.path.endsWith('/login') ? loginResponse('SUPER_ADMIN') : [],
          );
        }),
      );
      await api.login('operator@example.test', 'private-password', '123456');
      await api.call('/audit-events');
      expect(seen.first.headers['Authorization'], isNull);
      expect(seen.last.headers['Authorization'], 'Bearer platform-token');
      expect(
        seen.every((req) => req.url.path.startsWith('/api/platform/')),
        isTrue,
      );
      final another = PlatformApi(
        client: MockClient((_) async => throw StateError('Must not send')),
      );
      await expectLater(another.call('/me'), throwsA(isA<ApiException>()));
      api.close();
      another.close();
    },
  );

  test('401 clears platform session while 503 does not discard it', () async {
    var status = 503;
    final api = PlatformApi(
      client: MockClient(
        (req) async => req.url.path.endsWith('/login')
            ? success(loginResponse('SUPER_ADMIN'))
            : http.Response('{}', status),
      ),
    );
    await api.login('operator@example.test', 'password', '123456');
    await expectLater(api.call('/me'), throwsA(isA<ApiException>()));
    expect(api.user, isNotNull);
    status = 401;
    await expectLater(api.call('/me'), throwsA(isA<ApiException>()));
    expect(api.user, isNull);
    api.close();
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('platform login fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PlatformApi(client: MockClient((_) async => success([])));
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      expect(find.text('Platform sign in'), findsOneWidget);
      expect(find.text('Authenticator code'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }

  testWidgets('IT sees audit only and session expiry returns to login', (
    tester,
  ) async {
    final calls = <String>[];
    final api = PlatformApi(
      client: MockClient((req) async {
        calls.add(req.url.path);
        return success(
          req.url.path.endsWith('/login') ? loginResponse('IT_SECURITY') : [],
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'it@example.test');
    await tester.enterText(inputs.at(1), 'private-password');
    await tester.enterText(inputs.at(2), '123456');
    await tester.ensureVisible(find.text('Verify and sign in'));
    await tester.tap(find.text('Verify and sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Audit trail'), findsOneWidget);
    expect(find.text('Request madrassa'), findsNothing);
    expect(calls, contains('/api/platform/audit-events'));
    expect(calls, isNot(contains('/api/platform/tenant-applications')));
    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();
    expect(find.text('Platform sign in'), findsOneWidget);
    expect(api.user, isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
