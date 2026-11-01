import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/automatic_data_updates.dart';

void main() {
  testWidgets(
    'serializes updates, pauses in background and stops after disposal',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      final updates = AutomaticDataUpdates(
        canUpdate: () => true,
        update: () async {
          calls++;
          if (calls == 1) await pending.future;
        },
      );
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 1);
      pending.complete();
      await tester.pump();
      updates.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 1);
      updates.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      updates.dispose();
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 2);
    },
  );
}
