import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/platform_console.dart';

http.Response success(dynamic data) =>
    http.Response(jsonEncode({'data': data}), 200);

http.Response loginResponse(String id) => success({
  'accessToken': 'token-$id',
  'expiresIn': 900,
  'user': {'id': id, 'role': 'SUPER_ADMIN'},
});

void main() {
  for (final status in [200, 401]) {
    test('late $status response cannot affect a new session', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var loginCount = 0;
      final api = PlatformApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return loginResponse('${++loginCount}');
          }
          if (request.url.path.endsWith('/audit-events')) {
            started.complete();
            return pending.future;
          }
          expect(request.headers['Authorization'], 'Bearer token-2');
          return success({'id': '2'});
        }),
      );
      addTearDown(api.close);
      await api.login('first@example.test', 'password', '123456');
      final result = expectLater(
        api.call('/audit-events'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      await started.future;
      await api.login('second@example.test', 'password', '123456');
      final version = api.sessionVersion;
      pending.complete(
        status == 200
            ? success(['private old account data'])
            : http.Response('unauthorized', 401),
      );
      await result;
      expect(api.user?['id'], '2');
      expect(api.sessionVersion, version);
      expect(await api.call('/me'), {'id': '2'});
    });
  }

  for (final relogin in [false, true]) {
    test(
      'pending login cannot survive ${relogin ? 'new login' : 'logout'}',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        var count = 0;
        final api = PlatformApi(
          client: MockClient((_) async {
            if (++count == 1) {
              started.complete();
              return pending.future;
            }
            return loginResponse('new');
          }),
        );
        addTearDown(api.close);
        final result = expectLater(
          api.login('old@example.test', 'password', '123456'),
          throwsA(isA<ApiException>()),
        );
        await started.future;
        if (relogin) {
          await api.login('new@example.test', 'password', '123456');
        } else {
          api.clear();
        }
        pending.complete(loginResponse('old'));
        await result;
        expect(api.user?['id'], relogin ? 'new' : isNull);
      },
    );
  }

  test('response arriving after expiry cannot return protected data', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final api = PlatformApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return loginResponse('operator');
        }
        started.complete();
        return pending.future;
      }),
    );
    addTearDown(api.close);
    await api.login('operator@example.test', 'password', '123456');
    final result = expectLater(
      api.call('/audit-events'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    await started.future;
    api.expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    pending.complete(success(['private data']));
    await result;
    expect(api.user, isNull);
    expect(api.expiresAt, isNull);
  });
}
