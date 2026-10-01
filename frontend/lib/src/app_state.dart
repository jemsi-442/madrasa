import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'browser_state.dart';

class AppState extends ChangeNotifier {
  AppState(this.api, {this.browserState = const BrowserState()});

  final MifApiClient api;
  final BrowserState browserState;
  bool restoring = false;
  bool _disposed = false;
  String? restorationError;
  String get _signOutKey => 'mif.signed-out:${api.baseUrl}';
  bool get _browserSignedOut =>
      api.browserAuth && browserState.read(_signOutKey, shared: true) == '1';
  String? get _sectionKey => session == null
      ? null
      : 'mif.page:${api.baseUrl}:${session!.userId}:${session!.role}';

  String? get rememberedSection =>
      _sectionKey == null ? null : browserState.read(_sectionKey!);

  void rememberSection(String path) {
    if (_sectionKey != null) browserState.write(_sectionKey!, path);
  }

  Future<void> restoreSession() async {
    if (!api.browserAuth || session != null || restoring) return;
    final version = _authVersion;
    restoring = true;
    restorationError = null;
    notifyListeners();
    try {
      if (browserState.read(_signOutKey, shared: true) == '1') {
        // A failed network logout must not sign this browser back in on reload.
        return;
      }
      final restored = await api.refresh('');
      if (!_disposed && version == _authVersion) session = restored;
    } catch (exception) {
      if (!_disposed &&
          version == _authVersion &&
          !(exception is ApiException && exception.statusCode == 401)) {
        restorationError =
            'We could not reconnect to your account. Please try again.';
      }
    } finally {
      if (!_disposed && version == _authVersion) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  void _acceptedSession(AuthSession value) {
    session = value;
    restorationError = null;
    browserState.write(_signOutKey, null, shared: true);
  }

  AuthSession? session;
  int _authVersion = 0;
  bool busy = false;
  String? error;

  Future<bool> signIn(String login, String password) async {
    final version = ++_authVersion;
    restoring = false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final signedIn = await api.login(login, password);
      if (_disposed || version != _authVersion) return false;
      _refreshing = null;
      _acceptedSession(signedIn);
      return true;
    } on ApiException catch (exception) {
      if (_disposed || version != _authVersion) return false;
      error = switch (exception.statusCode) {
        0 => 'We could not reach the school. Please try again.',
        401 => 'The phone number or email and password do not match.',
        429 => 'Please wait a moment before trying again.',
        _ => 'We could not sign you in. Please try again later.',
      };
      return false;
    } finally {
      if (!_disposed && version == _authVersion) {
        busy = false;
        notifyListeners();
      }
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
    final version = ++_authVersion;
    restoring = false;
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
      if (_disposed || version != _authVersion) return false;
      _refreshing = null;
      _acceptedSession(registered);
      return true;
    } on ApiException catch (exception) {
      if (_disposed || version != _authVersion) return false;
      error = switch (exception.statusCode) {
        0 => 'We could not connect. Please try again.',
        409 => 'This email already has an account. Please log in instead.',
        422 => 'Please check your details and try again.',
        429 => 'Please wait a few minutes before trying again.',
        _ => 'We could not create your account. Please try again later.',
      };
      return false;
    } finally {
      if (!_disposed && version == _authVersion) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<AuthSession>? _refreshing;

  Future<dynamic> load(String path) => _request(path);

  Future<dynamic> submit(String path, Map<String, dynamic> body) =>
      _request(path, method: 'POST', body: body);

  Future<dynamic> update(String path, Map<String, dynamic> body) =>
      _request(path, method: 'PATCH', body: body);

  Future<String> exportCsv(String path) async =>
      await _request(path, expectCsv: true) as String;

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool expectCsv = false,
  }) async {
    if (_browserSignedOut) {
      _authVersion++;
      _refreshing = null;
      session = null;
      if (!_disposed) notifyListeners();
      throw const ApiException('Please sign in again.', 401);
    }
    final current = session;
    final version = _authVersion;
    if (current == null) throw const ApiException('Please sign in again.', 401);
    try {
      return await api.request(
        path,
        method: method,
        body: body,
        accessToken: current.accessToken,
        expectCsv: expectCsv,
      );
    } on ApiException catch (exception) {
      if (exception.statusCode != 401) rethrow;
    }
    if (_browserSignedOut ||
        session == null ||
        version != _authVersion ||
        session!.userId != current.userId) {
      throw const ApiException('Please sign in again.', 401);
    }
    if (session!.accessToken == current.accessToken) {
      final pending = _refreshing ??= api.refresh(current.refreshToken);
      try {
        final renewed = await pending;
        if (_browserSignedOut ||
            session == null ||
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
    if (_browserSignedOut ||
        session == null ||
        version != _authVersion ||
        session!.userId != current.userId) {
      throw const ApiException('Please sign in again.', 401);
    }
    return api.request(
      path,
      method: method,
      body: body,
      accessToken: session!.accessToken,
      expectCsv: expectCsv,
    );
  }

  Future<void> signOut() async {
    _authVersion++;
    _refreshing = null;
    restoring = false;
    busy = false;
    restorationError = null;
    browserState.write(_signOutKey, '1', shared: true);
    if (_sectionKey != null) browserState.write(_sectionKey!, null);
    final refreshToken = session?.refreshToken;
    session = null;
    error = null;
    notifyListeners();
    if (refreshToken == null && !api.browserAuth) return;
    try {
      await api.logout(refreshToken ?? '');
    } catch (_) {
      // Local sign-out completes when the server cannot be reached.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authVersion++;
    api.dispose();
    super.dispose();
  }
}
