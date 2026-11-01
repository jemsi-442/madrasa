import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_access_page.dart';

void main() {
  for (final width in [320.0, 1600.0]) {
    testWidgets('Access layout and local search at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reviewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAccessPage(
              records: [
                {
                  'id': 'synthetic',
                  'fullName': 'Synthetic Operator',
                  'role': 'IT_SECURITY',
                  'status': 'ACTIVE',
                },
              ],
              busy: false,
              error: null,
              page: 1,
              role: '',
              onRole: (_) {},
              onPage: (_) {},
              onRefresh: () {},
              onReview: (_) => reviewed = true,
            ),
          ),
        ),
      );
      expect(find.text('Access & Roles'), findsOneWidget);
      expect(find.text('Synthetic Operator'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Review'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Access scope'), findsOneWidget);
      expect(reviewed, isFalse);
      await tester.tap(find.text('Access history'));
      await tester.pumpAndSettle();
      expect(reviewed, isTrue);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('Synthetic Operator'), findsNothing);
      expect(find.text('No accounts match this view.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Synthetic Operator'), findsOneWidget);
      expect(find.text('Disable account'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
