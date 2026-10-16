import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_madrasas_page.dart';

void main() {
  for (final canReview in [true, false]) {
    testWidgets(
      'pending madrasa review respects independent reviewer=$canReview',
      (tester) async {
        String? decision;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformMadrasasPage(
                onApplications: () {},
                onSessionExpired: () {},
                onReview: (_, value) async {
                  decision = value;
                },
                load: (_) async => {
                  'total': 1,
                  'items': [
                    {
                      'id': 'application:new',
                      'applicationId': 'new',
                      'name': 'New Madrasa',
                      'code': 'new',
                      'status': 'REQUESTED',
                      'canReview': canReview,
                      'admins': [],
                      'locations': [],
                      'students': null,
                      'teachers': null,
                    },
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final manage = find.text('Manage →');
        await tester.ensureVisible(manage);
        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(find.text('Applications'), findsNothing);
        expect(
          find.text('Approve madrasa'),
          canReview ? findsOneWidget : findsNothing,
        );
        if (canReview) {
          await tester.tap(find.text('Approve madrasa'));
          await tester.pumpAndSettle();
          expect(decision, 'APPROVED');
        } else {
          expect(
            find.text('Another Super Admin must review this request.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [390.0, 1400.0]) {
    testWidgets('directory at $width loads, searches and opens details', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      var applications = false;
      String? csv;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformMadrasasPage(
              onApplications: () => applications = true,
              onSessionExpired: () {},
              saveCsv: (_, content) async {
                csv = content;
                return true;
              },
              load: (path) async {
                paths.add(path);
                return {
                  'total': 1,
                  'summary': {
                    'total': 1,
                    'active': 1,
                    'onboarding': 0,
                    'assignedAdmins': 1,
                  },
                  'locations': ['Dar es Salaam'],
                  'items': [
                    {
                      'id': '7',
                      'name': 'Afaq Madrasa',
                      'code': 'AFQ',
                      'status': 'ACTIVE',
                      'students': 24,
                      'teachers': 3,
                      'admins': ['School Admin'],
                      'locations': ['Dar es Salaam'],
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Afaq Madrasa'), findsOneWidget);
      expect(find.text('Total madrasas'), findsOneWidget);
      expect(find.text('Assigned admins'), findsOneWidget);
      await tester.ensureVisible(find.text('Export list'));
      await tester.tap(find.text('Export list'));
      await tester.pumpAndSettle();
      expect(csv, contains('Dar es Salaam'));
      expect(Uri.parse(paths.last).queryParameters['export'], 'true');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'AFQ');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.last).queryParameters['search'], 'AFQ');
      final details = width < 700
          ? find.text('Afaq Madrasa')
          : find.text('Manage →');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Registration code'), findsOneWidget);
      expect(find.text('AFQ'), findsOneWidget);
      expect(find.text('Madrasa details'), findsOneWidget);
      expect(find.text('Onboarding & next steps'), findsOneWidget);
      expect(find.text('Management responsibilities'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to Madrasas'));
      await tester.tap(find.text('Back to Madrasas'));
      await tester.pumpAndSettle();
      final add = find.text('Add Madrasa');
      await tester.ensureVisible(add);
      await tester.tap(add);
      expect(applications, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
