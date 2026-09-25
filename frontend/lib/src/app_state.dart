import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final MifApiClient api;
  AuthSession? session;
  bool busy = false;
  String? error;

  Future<bool> signIn(String login, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      session = await api.login(login, password);
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

  Future<dynamic> load(String path) async {
    final current = session;
    if (current == null) throw const ApiException('Please sign in again.', 401);

    try {
      return await api.request(path, accessToken: current.accessToken);
    } on ApiException catch (exception) {
      if (exception.statusCode != 401) rethrow;
      try {
        session = await api.refresh(current.refreshToken);
        notifyListeners();
        return await api.request(path, accessToken: session!.accessToken);
      } on ApiException {
        session = null;
        notifyListeners();
        throw const ApiException(
          'Your session has expired. Please sign in again.',
          401,
        );
      }
    }
  }

  Future<void> signOut() async {
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
