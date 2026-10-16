import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/family_identity_card.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('family number is selectable and copies at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
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
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilyIdentityCard(number: 'DSM/FAM/26/001'),
            ),
          ),
        ),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.tap(find.text('Copy family number'));
      await tester.pump();
      expect(copied, 'DSM/FAM/26/001');
      expect(find.text('Family number copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unissued number has guidance, not a fake identifier', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FamilyIdentityCard(number: null))),
    );
    expect(find.textContaining('has not been issued yet'), findsOneWidget);
    expect(find.text('Copy family number'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
  });
}
