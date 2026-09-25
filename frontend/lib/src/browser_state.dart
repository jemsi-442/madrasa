import 'platform/browser_support_stub.dart'
    if (dart.library.js_interop) 'platform/browser_support_web.dart'
    as platform;

/// Only navigation preferences and a sign-out marker, never credentials.
class BrowserState {
  const BrowserState();

  String? read(String key, {bool shared = false}) =>
      platform.readPreference(key, shared);

  void write(String key, String? value, {bool shared = false}) =>
      platform.writePreference(key, value, shared);
}
