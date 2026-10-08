import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('login and onboarding refresh flow at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var progressReads = 0;
      final writes = <String>[];
      final api = PlatformApi(
        baseUrl: 'https://platform.example.test',
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method != 'GET') writes.add(path);
          dynamic data;
          if (path.endsWith('/login')) {
            expect(jsonDecode(request.body), {
              'email': 'reviewer@example.test',
              'password': 'test-password-only',
              'code': '123456',
            });
            data = {
              'accessToken': 'test-token',
              'expiresIn': 900,
              'user': {
                'id': 'reviewer',
                'fullName': 'Reviewer',
                'role': 'SUPER_ADMIN',
              },
            };
          } else {
            expect(request.headers['Authorization'], 'Bearer test-token');
            if (path.endsWith('/onboarding-progress')) {
              progressReads++;
              if (progressReads == 2) {
                return http.Response('private diagnostic', 503);
              }
              data = {
                'schoolName': 'Afaq School',
                'requestedCode': 'afaq-school',
                'stage': 'ACTIVATION_REVIEW_PENDING',
                'checkedAt': '2026-10-08T10:00:0${progressReads}Z',
                'steps': [],
                'activationReview': {
                  'activationEnabled': false,
                  'prerequisitesPassed': true,
                  'checks': [
                    {
                      'label': 'Application independently approved',
                      'passed': true,
                    },
                  ],
                  'manualReviews': ['Tenant isolation', 'Backup and recovery'],
                },
              };
            } else if (path.endsWith('/tenant-applications')) {
              data = [
                {
                  'id': 'application',
                  'schoolName': 'Afaq School',
                  'requestedCode': 'afaq-school',
                  'adminEmail': 'school@example.test',
                  'status': 'APPROVED',
                  'requestedById': 'requester',
                  'reviewedById': 'reviewer',
                  'createdAt': '2026-10-08T09:00:00Z',
                  'reviewedAt': '2026-10-08T10:00:00Z',
                },
              ];
            } else {
              fail('Unexpected request: ${request.method} $path');
            }
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company email'),
        'reviewer@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'test-password-only',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        '123456',
      );
      await tester.ensureVisible(find.text('Verify and sign in'));
      await tester.tap(find.text('Verify and sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Onboarding progress'));
      await tester.tap(find.text('Onboarding progress'));
      await tester.pumpAndSettle();
      expect(find.text('Super Admin activation readiness'), findsOneWidget);
      expect(
        find.text('Checked (UTC): 2026-10-08T10:00:01.000Z'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Refresh progress'));
      await tester.tap(find.text('Refresh progress'));
      await tester.pumpAndSettle();
      expect(find.text('Super Admin activation readiness'), findsNothing);
      expect(
        find.textContaining('Previous information has been hidden'),
        findsOneWidget,
      );
      expect(find.textContaining('private diagnostic'), findsNothing);
      await tester.tap(find.text('Refresh progress'));
      await tester.pumpAndSettle();
      expect(
        find.text('Checked (UTC): 2026-10-08T10:00:03.000Z'),
        findsOneWidget,
      );
      expect(find.text('Backup and recovery: review required'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(writes, ['/api/platform/login']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
