import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('curriculum text hierarchy and empty state at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1400),
              textScaler: const TextScaler.linear(1.2),
            ),
            child: Scaffold(
              body: PlatformCurriculumPage(
                accountId: 'synthetic',
                onSessionExpired: () {},
                call: (_, {body}) async => {
                  'items': [],
                  'total': 0,
                  'madrasaCount': 0,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text('Curriculum & Subjects');
      final description = find.text(
        'Develop shared learning frameworks and choose what each madrasa adopts.',
      );
      expect(
        tester.getTopLeft(description).dy,
        greaterThan(tester.getBottomLeft(title).dy),
      );
      expect(
        tester.getTopLeft(find.text('View unpublished')).dy,
        greaterThan(tester.getBottomLeft(description).dy),
      );
      expect(find.text('No frameworks yet'), findsOneWidget);
      expect(find.text('No results'), findsNothing);
      expect(find.text('0 versions'), findsNothing);
      expect(find.text('Draft content'), findsOneWidget);
      expect(find.text('Publish when ready'), findsOneWidget);
      expect(find.text('Assign to madrasas'), findsOneWidget);
      await tester.ensureVisible(find.text('View unpublished'));
      await tester.tap(find.text('View unpublished'));
      await tester.pumpAndSettle();
      expect(find.text('No unpublished frameworks'), findsOneWidget);
      expect(find.text('No frameworks yet'), findsNothing);
      await tester.ensureVisible(find.text('View subject library'));
      await tester.tap(find.text('View subject library'));
      await tester.pumpAndSettle();
      expect(find.text('No frameworks yet'), findsOneWidget);
      expect(find.text('No unpublished frameworks'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
