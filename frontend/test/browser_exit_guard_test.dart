@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:mif_app/src/browser_state.dart';

void main() {
  test('Browser exit warns only while work is unsaved and cleans up', () {
    var dirty = false;
    final dispose = guardBrowserExit(() => dirty);
    addTearDown(dispose);

    bool exitPrevented() {
      final event = web.Event('beforeunload', web.EventInit(cancelable: true));
      web.window.dispatchEvent(event);
      return event.defaultPrevented;
    }

    expect(exitPrevented(), isFalse);
    dirty = true;
    expect(exitPrevented(), isTrue);
    dirty = false;
    expect(exitPrevented(), isFalse);
    dirty = true;
    dispose();
    expect(exitPrevented(), isFalse);
  });
}
