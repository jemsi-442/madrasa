import 'dart:async';
import 'dart:convert';

import 'platform/browser_support_stub.dart'
    if (dart.library.js_interop) 'platform/browser_support_web.dart'
    as platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String browserApiBaseUrl(String configured, Uri location) {
  final localHosts = ['localhost', '127.0.0.1', '::1'];
  final target = Uri.tryParse(configured);
  if (localHosts.contains(location.host) &&
      (configured.isEmpty || localHosts.contains(target?.host))) {
    return Uri(
      scheme: location.scheme,
      host: location.host,
      port: configured.isEmpty ? 4000 : target!.port,
    ).origin;
  }
  return configured.isEmpty ? location.origin : configured;
}

String defaultApiBaseUrl() {
  if (kIsWeb) return browserApiBaseUrl(configuredApiBaseUrl, Uri.base);
  if (configuredApiBaseUrl.isNotEmpty) return configuredApiBaseUrl;
  // USB-connected Android devices reach this through adb reverse.
  return 'http://127.0.0.1:4000';
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final String role;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String? ?? '',
      userId: user['id'].toString(),
      fullName: user['fullName'] as String,
      role: user['role'] as String,
    );
  }
}

class MifApiClient {
  MifApiClient({http.Client? client, String? baseUrl, bool? browserAuth})
    : browserAuth = browserAuth ?? kIsWeb,
      _client = client ?? platform.createClient(),
      baseUrl = (baseUrl ?? defaultApiBaseUrl()).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final bool browserAuth;
  String get authPath => browserAuth ? '/api/auth/browser' : '/api/auth';

  Future<T> authOperation<T>(Future<T> Function() action) => browserAuth
      ? platform.withAuthLock('mif-auth-$baseUrl', action)
      : action();
  final String baseUrl;

  Future<http.Response> _browserPost(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) async {
    final aborted = Completer<void>();
    final request =
        http.AbortableRequest('POST', uri, abortTrigger: aborted.future)
          ..headers.addAll(headers)
          ..body = jsonEncode(body ?? {});
    final timer = Timer(const Duration(seconds: 25), aborted.complete);
    try {
      return await http.Response.fromStream(await _client.send(request));
    } finally {
      timer.cancel();
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? accessToken,
    Map<String, dynamic>? body,
    bool expectCsv = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': expectCsv ? 'text/csv' : 'application/json',
      if (browserAuth && path.startsWith('/api/auth/browser/'))
        'X-MIF-Browser': '1',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    late final http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = browserAuth && path.startsWith('/api/auth/browser/')
              ? await _browserPost(uri, headers, body)
              : await _client.post(
                  uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body),
                );
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'GET':
          response = await _client.get(uri, headers: headers);
        default:
          throw ArgumentError.value(method, 'method');
      }
    } catch (_) {
      throw const ApiException('Cannot connect to the school right now.', 0);
    }

    if (expectCsv && response.statusCode >= 200 && response.statusCode < 300) {
      if (response.headers['content-type']
              ?.split(';')
              .first
              .trim()
              .toLowerCase() !=
          'text/csv') {
        throw const ApiException(
          'The school did not return a CSV report.',
          502,
        );
      }
      return utf8.decode(response.bodyBytes);
    }

    dynamic envelope;
    try {
      envelope = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'The school returned an unexpected response.',
        response.statusCode,
      );
    }

    if (envelope is! Map<String, dynamic>) {
      throw ApiException(
        'The school returned an unexpected response.',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        envelope['message']?.toString() ?? 'Please try again.',
        response.statusCode,
      );
    }
    return envelope['data'];
  }

  Future<AuthSession> login(String login, String password) =>
      authOperation(() async {
        final data = await request(
          '$authPath/login',
          method: 'POST',
          body: {'login': login.trim(), 'password': password},
        );
        return AuthSession.fromJson(data as Map<String, dynamic>);
      });

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) => authOperation(() async {
    final data = await request(
      '$authPath/register',
      method: 'POST',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  });

  Future<AuthSession> refresh(String refreshToken) => authOperation(() async {
    final data = await request(
      '$authPath/refresh',
      method: 'POST',
      body: browserAuth ? {} : {'refreshToken': refreshToken},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  });

  Future<void> logout(String refreshToken) => authOperation(() async {
    await request(
      '$authPath/logout',
      method: 'POST',
      body: browserAuth ? {} : {'refreshToken': refreshToken},
    );
  });

  void dispose() => _client.close();
}
