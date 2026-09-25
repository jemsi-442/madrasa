import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String defaultApiBaseUrl() {
  if (configuredApiBaseUrl.isNotEmpty) return configuredApiBaseUrl;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:4000';
  }
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
      refreshToken: json['refreshToken'] as String,
      userId: user['id'].toString(),
      fullName: user['fullName'] as String,
      role: user['role'] as String,
    );
  }
}

class MifApiClient {
  MifApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultApiBaseUrl()).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String baseUrl;

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    late final http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _client.post(
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

  Future<AuthSession> login(String login, String password) async {
    final data = await request(
      '/api/auth/login',
      method: 'POST',
      body: {'login': login.trim(), 'password': password},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final data = await request(
      '/api/auth/register',
      method: 'POST',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final data = await request(
      '/api/auth/refresh',
      method: 'POST',
      body: {'refreshToken': refreshToken},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await request(
      '/api/auth/logout',
      method: 'POST',
      body: {'refreshToken': refreshToken},
    );
  }

  void dispose() => _client.close();
}
