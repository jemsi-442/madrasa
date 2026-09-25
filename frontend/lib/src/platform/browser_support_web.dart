import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createClient() => BrowserClient()..withCredentials = true;

Future<T> withAuthLock<T>(String name, Future<T> Function() action) async {
  if (!web.window.isSecureContext ||
      !web.window.navigator.hasProperty('locks'.toJS).toDart) {
    return action();
  }
  late T result;
  Object? failure;
  StackTrace? trace;
  // The browser shares the rotating cookie across tabs. Serialize its use.
  await web.window.navigator.locks
      .request(
        name,
        ((JSAny? _) {
          return (() async {
            try {
              result = await action();
            } catch (error, stack) {
              failure = error;
              trace = stack;
            }
            return null;
          })().toJS;
        }).toJS,
      )
      .toDart;
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result;
}

String? readPreference(String key, bool shared) {
  try {
    return (shared ? web.window.localStorage : web.window.sessionStorage)
        .getItem(key);
  } catch (_) {
    return null;
  }
}

void writePreference(String key, String? value, bool shared) {
  try {
    final storage = shared
        ? web.window.localStorage
        : web.window.sessionStorage;
    if (value == null) {
      storage.removeItem(key);
    } else {
      storage.setItem(key, value);
    }
  } catch (_) {
    // Browsing can continue when storage is disabled; never store auth tokens here.
  }
}
