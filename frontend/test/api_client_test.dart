import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  test('login sends assigned credentials and reads the role', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://school.test/api/auth/login');
      expect(jsonDecode(request.body), {
        'login': 'teacher@example.com',
        'password': 'test-password',
      });
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'user': {'id': '42', 'fullName': 'Teacher One', 'role': 'TEACHER'},
          },
        }),
        200,
      );
    });
    final api = MifApiClient(client: client, baseUrl: 'https://school.test');

    final session = await api.login(' teacher@example.com ', 'test-password');

    expect(session.role, 'TEACHER');
    expect(session.fullName, 'Teacher One');
    expect(session.accessToken, 'access-token');
  });

  test('API errors keep the server message', () async {
    final api = MifApiClient(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Invalid credentials'}), 401),
      ),
      baseUrl: 'https://school.test',
    );

    expect(
      api.login('unknown', 'wrong'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'Invalid credentials'),
      ),
    );
  });
}
