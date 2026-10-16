import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/design_theme.dart';
import 'package:mif_app/src/workspace_details_dialog.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('full-page details adapt to text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAfaqTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    WorkspaceRecordHeading(
                      title: 'Afaq Demo Madrasa',
                      subtitle: 'Madrasa profile and administration',
                      trailing: Text('Active'),
                    ),
                    WorkspaceDetailsSection(
                      title: 'Madrasa details',
                      child: WorkspaceRecordDetails(
                        fields: [
                          ('Registration code', 'AFQ'),
                          ('Location', 'Dar es Salaam'),
                          ('Assigned admins', 'School Admin'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Registration code'));
      final second = tester.getTopLeft(find.text('Location'));
      if (scale == 1) {
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
        expect(second.dx, first.dx);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 1440.0]) {
    testWidgets('record details have labelled fields and scroll at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAfaqTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const WorkspaceDetailsDialog(
                    title: 'Demo School Admin',
                    statusFields: {'Account status'},
                    fields: [
                      ('Role', 'Madrasa Admin'),
                      ('Assigned madrasa', 'Afaq Demo Madrasa'),
                      ('Email', 'averylongaccountaddress@example.test'),
                      ('Account status', 'ACTIVE'),
                    ],
                    sections: [
                      ('Access scope', 'Only the assigned madrasa.'),
                      (
                        'Who can make changes?',
                        'The responsible madrasa administrator.',
                      ),
                    ],
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Madrasa Admin'), findsOneWidget);
      expect(find.text('Access scope'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(6));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      await tester.tap(find.text('Copy details'));
      await tester.pumpAndSettle();
      expect(copied, contains('Role: Madrasa Admin'));
      expect(copied, contains('Account status: ACTIVE'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Demo School Admin'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
