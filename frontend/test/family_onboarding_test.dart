import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/family_registration_page.dart';
import 'package:mif_app/src/family_applications_panel.dart';
import 'package:mif_app/src/school_password_dialog.dart';

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'public family request keeps records private and shows receipt at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? body;
        final api = MifApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/auth/family-registration');
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'data': {'receipt': 'a' * 32},
              }),
              202,
            );
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: FamilyRegistrationScreen(api: api, onNavigate: (_) {}),
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in {
          'fullName': 'Parent Example',
          'email': 'parent@example.test',
          'phone': '255700000111',
          'childReference': 'Child Example, ADM-001',
          'password': 'FamilyPass123!',
          'confirmPassword': 'FamilyPass123!',
        }.entries) {
          await tester.enterText(
            find.byKey(ValueKey('family-register-${entry.key}')),
            entry.value,
          );
        }
        await click(tester, find.text('Submit family request'));
        expect(body?['role'], isNull);
        expect(body?['orgId'], isNull);
        expect(body?['password'], 'FamilyPass123!');
        expect(find.text('Your request has been received'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('family-request-receipt')),
          findsOneWidget,
        );
        expect(find.textContaining('No email has been sent'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'school password confirmation blocks mismatches and posts no identity fields',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showSchoolPasswordDialog(context, (path, body) async {
                      expect(path, '/api/auth/change-password');
                      sent = body;
                    }),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await click(tester, find.text('Open'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'OldPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'OtherPassword123!',
      );
      await click(tester, find.text('Change and sign out'));
      expect(sent, isNull);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'NewPassword123!',
      );
      await click(tester, find.text('Change and sign out'));
      expect(sent?.keys.toSet(), {
        'currentPassword',
        'password',
        'confirmPassword',
      });
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'request review requires verification and original receipt before approval',
    (tester) async {
      Map<String, dynamic>? sent;
      var approved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilyApplicationsPanel(
                onApproved: () => approved = true,
                load: (path) async =>
                    path.startsWith('/api/users/family-guardians')
                    ? {
                        'items': [
                          {
                            'id': '9',
                            'contactLabel': 'Verified Parent - 255700000111',
                            'childrenSummary': 'Child Example (ADM-001)',
                          },
                        ],
                      }
                    : {
                        'items': [
                          {
                            'id': 'application-1',
                            'fullName': 'Parent Example',
                            'email': 'parent@example.test',
                            'phone': '255700000111',
                            'childReference': 'Child Example',
                            'createdAt': '2026-10-09',
                          },
                        ],
                        'meta': {'totalItems': 1},
                      },
                submit: (path, body) async {
                  expect(
                    path,
                    '/api/users/family-applications/application-1/review',
                  );
                  sent = body;
                  return {'familyLoginId': 'DSM/FAM/26/001'};
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await click(tester, find.text('Verify and approve'));
      expect(sent, isNull);
      await click(tester, find.text('Identity verified'));
      await click(
        tester,
        find.widgetWithText(TextFormField, 'Verified guardian'),
      );
      await click(tester, find.text('Verified Parent - 255700000111'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Region code (for example DSM)'),
        'DSM',
      );
      await click(tester, find.text('Approve and issue number'));
      expect(sent, isNull);
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Receipt supplied privately by applicant',
        ),
        'a' * 32,
      );
      await click(tester, find.text('Approve and issue number'));
      expect(sent?['verified'], true);
      expect(sent?['guardianId'], '9');
      expect(sent?['receipt'], 'a' * 32);
      expect(approved, true);
      expect(tester.takeException(), isNull);
    },
  );
}
