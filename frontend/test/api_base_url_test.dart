import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  final expectedBaseUrl = configuredApiBaseUrl.isEmpty
      ? 'http://127.0.0.1:4000'
      : configuredApiBaseUrl;

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in TargetPlatform.values) {
    test(
      'native API URL on ${platform.name} supports USB/local development',
      () {
        debugDefaultTargetPlatformOverride = platform;

        expect(defaultApiBaseUrl(), expectedBaseUrl);
      },
    );
  }

  test(
    'Android login uses the default server and native auth endpoint',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final api = MifApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url, Uri.parse('$expectedBaseUrl/api/auth/login'));
          expect(request.headers.containsKey('X-MIF-Browser'), isFalse);
          expect(jsonDecode(request.body), {
            'login': 'admin@example.test',
            'password': 'test-password',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'accessToken': 'test-access',
                'refreshToken': 'test-refresh',
                'user': {'id': '1', 'fullName': 'Test Admin', 'role': 'ADMIN'},
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);

      final session = await api.login('admin@example.test', 'test-password');

      expect(session.role, 'ADMIN');
    },
  );
}
