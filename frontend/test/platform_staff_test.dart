import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_staff_page.dart';

void main() {
  testWidgets('invitation follows madrasa onboarding without granting access', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformStaffPage(
            load: (_) async => {'total': 0, 'items': <Map<String, dynamic>>[]},
            onApplications: () => opened = true,
            onCompanyAccounts: () {},
            onSessionExpired: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite user'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('does not grant cross-madrasa access'),
      findsOneWidget,
    );
    expect(opened, isFalse);
    await tester.tap(find.text('Choose madrasa'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1400.0]) {
    testWidgets('staff directory at $width searches and reviews scope', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformStaffPage(
              onApplications: () {},
              onCompanyAccounts: () {},
              onSessionExpired: () {},
              load: (path) async {
                requests.add(path);
                return {
                  'total': 1,
                  'summary': {
                    'admins': 6,
                    'teachers': 30,
                    'guardianLinks': 410,
                    'pendingRequests': 2,
                  },
                  'items': [
                    {
                      'id': '2',
                      'fullName': 'School Admin',
                      'role': 'ADMIN',
                      'status': 'ACTIVE',
                      'school': {
                        'name': 'Afaq School',
                        'code': 'AFQ',
                        'status': 'ACTIVE',
                      },
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('School Admin'), findsOneWidget);
      expect(find.text('Guardian links'), findsOneWidget);
      expect(find.text('410'), findsOneWidget);
      expect(find.text('Role preview'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Afaq');
      await tester.tap(find.byTooltip('Search accounts'));
      await tester.pumpAndSettle();
      expect(Uri.parse(requests.last).queryParameters['search'], 'Afaq');
      await tester.ensureVisible(find.byTooltip('Review School Admin'));
      await tester.tap(find.byTooltip('Review School Admin'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Access is limited to the assigned madrasa.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'failed directory has retry and never shows a false empty result',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformStaffPage(
              onApplications: () {},
              onCompanyAccounts: () {},
              onSessionExpired: () {},
              load: (_) async => throw Exception('offline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No staff accounts match these filters.'), findsNothing);
    },
  );
}
