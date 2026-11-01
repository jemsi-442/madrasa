import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/it_workspace_visuals.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';

void main() {
  test('IT timestamps show UTC and do not invent missing dates', () {
    expect(itTimestamp('2026-10-31T11:30:05+03:00'), '31 Oct 2026, 08:30 UTC');
    expect(itTimestamp('2026-10-31T08:30:00Z'), '31 Oct 2026, 08:30 UTC');
    expect(itTimestamp(null), 'Not recorded');
    expect(itTimestamp('invalid'), 'Time unavailable');
    expect(itTimestamp('2026-10-31T08:30:00'), 'Time unavailable');
  });
  for (final width in [320.0, 1440.0]) {
    for (final page in [
      PlatformPage.accounts,
      PlatformPage.history,
      PlatformPage.sessions,
      PlatformPage.health,
    ]) {
      testWidgets('shared IT page $page at $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ItWorkspaceSurface(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      PlatformTaskIntro(page: page, isAdmin: false),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: ItRecordDetails(
                            values: {
                              'Account ID':
                                  'synthetic-account-long-identifier-for-testing',
                              'Status': 'Active',
                              'Recorded (UTC)': '2026-10-31T08:30:00Z',
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('AFAQ / IT WORKSPACE'), findsOneWidget);
        expect(find.text('Account ID'), findsOneWidget);
        expect(find.text('31 Oct 2026, 08:30 UTC'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
