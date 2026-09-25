import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final MifApiClient api;
  AuthSession? session;
  int _authVersion = 0;
  bool busy = false;
  String? error;

  Future<bool> signIn(String login, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final signedIn = await api.login(login, password);
      _authVersion++;
      _refreshing = null;
      session = signedIn;
      return true;
    } on ApiException catch (exception) {
      error = switch (exception.statusCode) {
        0 => 'We could not reach the school. Please try again.',
        401 => 'The phone number or email and password do not match.',
        429 => 'Please wait a moment before trying again.',
        _ => 'We could not sign you in. Please try again later.',
      };
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final registered = await api.register(
        fullName: fullName,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      _authVersion++;
      _refreshing = null;
      session = registered;
      return true;
    } on ApiException catch (exception) {
      error = switch (exception.statusCode) {
        0 => 'We could not connect. Please try again.',
        409 => 'This email already has an account. Please log in instead.',
        422 => 'Please check your details and try again.',
        429 => 'Please wait a few minutes before trying again.',
        _ => 'We could not create your account. Please try again later.',
      };
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<AuthSession>? _refreshing;

  Future<dynamic> load(String path) => _request(path);

  Future<dynamic> submit(String path, Map<String, dynamic> body) =>
      _request(path, method: 'POST', body: body);

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final current = session;
    final version = _authVersion;
    if (current == null) throw const ApiException('Please sign in again.', 401);
    try {
      return await api.request(
        path,
        method: method,
        body: body,
        accessToken: current.accessToken,
      );
    } on ApiException catch (exception) {
      if (exception.statusCode != 401) rethrow;
    }
    if (session == null ||
        version != _authVersion ||
        session!.userId != current.userId) {
      throw const ApiException('Please sign in again.', 401);
    }
    if (session!.accessToken == current.accessToken) {
      final pending = _refreshing ??= api.refresh(current.refreshToken);
      try {
        final renewed = await pending;
        if (session == null ||
            version != _authVersion ||
            session!.userId != current.userId ||
            renewed.userId != current.userId) {
          throw const ApiException('Please sign in again.', 401);
        }
        session = renewed;
        notifyListeners();
      } on ApiException catch (exception) {
        if (exception.statusCode == 401 &&
            session?.accessToken == current.accessToken) {
          session = null;
          notifyListeners();
        }
        rethrow;
      } finally {
        if (identical(_refreshing, pending)) _refreshing = null;
      }
    }
    if (session == null ||
        version != _authVersion ||
        session!.userId != current.userId) {
      throw const ApiException('Please sign in again.', 401);
    }
    return api.request(
      path,
      method: method,
      body: body,
      accessToken: session!.accessToken,
    );
  }

  Future<void> signOut() async {
    _authVersion++;
    _refreshing = null;
    final refreshToken = session?.refreshToken;
    session = null;
    error = null;
    notifyListeners();
    if (refreshToken == null) return;
    try {
      await api.logout(refreshToken);
    } catch (_) {
      // Local sign-out completes when the server cannot be reached.
    }
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
