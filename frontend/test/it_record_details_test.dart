import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/it_workspace_visuals.dart';
import 'package:mif_app/src/workspace_form_dialog.dart';

void main() {
  for (final width in [360.0, 1000.0]) {
    testWidgets('Record dialog remains readable at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => WorkspaceFormDialog(
                    title: const Text('Account details'),
                    content: const SizedBox(
                      width: 650,
                      child: SingleChildScrollView(
                        child: ItRecordDetails(
                          values: {
                            'Access scope':
                                'Technical operations across institutions',
                            'Reference':
                                'synthetic-account-reference-with-long-identifier',
                            'Created (UTC)': '2026-11-02T09:15:00Z',
                            'Missing value': null,
                          },
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                child: const Text('View'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('02 Nov 2026, 09:15 UTC'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceFormDialog), findsNothing);
    });
  }
}
