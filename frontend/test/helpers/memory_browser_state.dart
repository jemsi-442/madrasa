import 'package:mif_app/src/browser_state.dart';

/// Isolates navigation preferences from the browser running the test suite.
class MemoryBrowserState extends BrowserState {
  final _values = <(bool, String), String>{};

  @override
  String? read(String key, {bool shared = false}) => _values[(shared, key)];

  @override
  void write(String key, String? value, {bool shared = false}) {
    if (value == null) {
      _values.remove((shared, key));
    } else {
      _values[(shared, key)] = value;
    }
  }
}
