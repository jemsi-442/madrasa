import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/workspace_chrome.dart';

void main() {
  for (final labelled in [false, true]) {
    for (final loading in [false, true]) {
      testWidgets(
        'refresh tooltip and busy guard labelled=$labelled loading=$loading',
        (tester) async {
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WorkspaceRefreshButton(
                  onRefresh: () => calls++,
                  tooltip: 'Refresh overview',
                  label: labelled ? 'Check services' : null,
                  loading: loading,
                ),
              ),
            ),
          );
          expect(find.byTooltip('Refresh overview'), findsOneWidget);
          await tester.tap(find.byTooltip('Refresh overview'));
          await tester.pump();
          expect(calls, loading ? 0 : 1);
          expect(
            find.byType(CircularProgressIndicator),
            loading ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
