import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/workspace_chrome.dart';

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets('shared footer fits at $width with large text', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: SizedBox()),
                  WorkspaceFooter(),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('workspace-footer')), findsOneWidget);
      expect(
        find.text('\u00a9 ${DateTime.now().year} Afaq. All rights reserved.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
