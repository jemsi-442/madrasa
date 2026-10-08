import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final fromProgress in [false, true]) {
    testWidgets('IT opens scoped history from setup progress=$fromProgress', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auditReads = <Uri>[];
      final writes = <String>[];
      final api = PlatformApi(
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method != 'GET') writes.add(path);
          dynamic data;
          if (path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {'id': 'it', 'fullName': 'IT', 'role': 'IT_SECURITY'},
            };
          } else if (path.endsWith('/provisioning-queue')) {
            data = [
              {
                'id': 'application',
                'schoolName': 'School',
                'requestedCode': 'school',
                'organization': {'status': 'PENDING_ACTIVATION'},
              },
            ];
          } else if (path.endsWith('/onboarding-progress')) {
            data = {
              'schoolName': 'School',
              'requestedCode': 'school',
              'stage': 'INVITATION_PENDING',
              'checkedAt': DateTime.now().toUtc().toIso8601String(),
            };
          } else if (path.endsWith('/audit-events')) {
            auditReads.add(request.url);
            data = [];
          } else {
            fail('Unexpected request: $path');
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('it@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Madrassa setup'));
      await tester.tap(find.text('Madrassa setup'));
      await tester.pumpAndSettle();
      if (fromProgress) {
        await tester.ensureVisible(find.text('Onboarding progress'));
        await tester.tap(find.text('Onboarding progress'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('View application history'));
      await tester.tap(find.text('View application history'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(auditReads.single.queryParameters['applicationId'], 'application');
      expect(auditReads.single.queryParameters['page'], '1');
      expect(find.text('Application history: application'), findsOneWidget);
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(auditReads.last.queryParameters['applicationId'], 'application');
      expect(writes, ['/api/platform/login']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  for (final withdrawn in [false, true]) {
    testWidgets('IT follows sign-off history from withdrawn=$withdrawn', (
      tester,
    ) async {
      final requests = <Uri>[];
      final api = PlatformApi(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/login')
                  ? {
                      'accessToken': 'token',
                      'expiresIn': 900,
                      'user': {
                        'id': 'it',
                        'fullName': 'IT',
                        'role': 'IT_SECURITY',
                      },
                    }
                  : [
                      {
                        'id': withdrawn ? 'withdrawal' : 'review',
                        'entityType': withdrawn
                            ? 'TechnicalReview'
                            : 'TenantApplication',
                        'entityId': withdrawn ? 'review' : 'application',
                        'action': withdrawn
                            ? 'tenant.technical-review.withdrawn'
                            : 'tenant.technical-review.recorded',
                      },
                    ],
            }),
            200,
          );
        }),
      );
      await api.login('it@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Audit trail'));
      await tester.tap(find.text('Audit trail'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View sign-off history'));
      await tester.tap(find.text('View sign-off history'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['technicalReviewId'], 'review');
      expect(requests.last.queryParameters['page'], '1');
      expect(find.text('Sign-off history: review'), findsOneWidget);
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['technicalReviewId'], 'review');
      await tester.ensureVisible(
        find.text('Show all application and platform events'),
      );
      await tester.tap(find.text('Show all application and platform events'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters.containsKey('technicalReviewId'),
        isFalse,
      );
      expect(find.text('Sign-off history: review'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    testWidgets('$role opens application-scoped audit and clears scope', (
      tester,
    ) async {
      final requests = <Uri>[];
      final api = PlatformApi(
        client: MockClient((req) async {
          requests.add(req.url);
          final dynamic data = req.url.path.endsWith('/login')
              ? {
                  'accessToken': 'token',
                  'expiresIn': 900,
                  'user': {
                    'id': 'operator',
                    'fullName': 'Operator',
                    'role': role,
                  },
                }
              : req.url.path.endsWith('/tenant-applications')
              ? [
                  {
                    'id': 'application',
                    'schoolName': 'School',
                    'requestedCode': 'school',
                    'status': 'APPROVED',
                    'adminEmail': 'admin@example.test',
                  },
                ]
              : [
                  {
                    'id': 'event',
                    'action': 'tenant.application.approved',
                    'actorRole': 'IT_SECURITY',
                    'actorId': 'operator',
                    'entityType': 'TenantApplication',
                    'entityId': 'application',
                    'metadata': {'status': 'PENDING_ACTIVATION'},
                  },
                ];
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('operator@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(
        find.text(
          role == 'SUPER_ADMIN' ? 'Madrassa applications' : 'Audit trail',
        ),
      );
      await tester.tap(
        find.text(
          role == 'SUPER_ADMIN' ? 'Madrassa applications' : 'Audit trail',
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View application history'));
      await tester.tap(find.text('View application history'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/platform/audit-events');
      expect(requests.last.queryParameters['applicationId'], 'application');
      expect(requests.last.queryParameters['page'], '1');
      expect(find.text('Application history: application'), findsOneWidget);
      await tester.ensureVisible(find.text('All events'));
      await tester.tap(find.text('All events'));
      await tester.pumpAndSettle();
      if (role == 'SUPER_ADMIN') {
        expect(find.text('Failed login'), findsNothing);
        expect(find.text('IT sign-off recorded'), findsNothing);
        expect(find.text('IT sign-off withdrawn'), findsNothing);
        expect(find.text('Inactive madrassa created'), findsNothing);
        expect(find.text('System health'), findsNothing);
        expect(find.text('My sessions'), findsNothing);
      }
      await tester.ensureVisible(find.text('Madrassa approved').last);
      await tester.tap(find.text('Madrassa approved').last);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['applicationId'], 'application');
      expect(
        requests.last.queryParameters['action'],
        'tenant.application.approved',
      );
      await tester.ensureVisible(
        find.text('Show all application and platform events'),
      );
      await tester.tap(find.text('Show all application and platform events'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters.containsKey('applicationId'),
        isFalse,
      );
      expect(requests.last.queryParameters.containsKey('action'), isFalse);
      expect(find.text('Application history: application'), findsNothing);
      if (role == 'IT_SECURITY') {
        await tester.ensureVisible(find.text('View actor activity'));
        await tester.tap(find.text('View actor activity'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['actorId'], 'operator');
        expect(requests.last.queryParameters['page'], '1');
        expect(
          requests.last.queryParameters.containsKey('applicationId'),
          isFalse,
        );
        expect(find.text('Activity by account: operator'), findsOneWidget);
        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['actorId'], 'operator');
        await tester.ensureVisible(find.text('View application history'));
        await tester.tap(find.text('View application history'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['applicationId'], 'application');
        expect(requests.last.queryParameters.containsKey('actorId'), isFalse);
        await tester.ensureVisible(find.text('View actor activity'));
        await tester.tap(find.text('View actor activity'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Show all application and platform events'),
        );
        await tester.tap(find.text('Show all application and platform events'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters.containsKey('actorId'), isFalse);
        expect(find.text('Activity by account: operator'), findsNothing);
      } else {
        expect(find.text('View actor activity'), findsNothing);
        expect(find.text('Office history'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }

  testWidgets(
    'audit filter sends exact query and opens event details on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final api = PlatformApi(
        client: MockClient((req) async {
          requests.add(req.url);
          return http.Response(
            jsonEncode({
              'data': req.url.path.endsWith('/login')
                  ? {
                      'accessToken': 'token',
                      'expiresIn': 900,
                      'user': {
                        'id': 'it',
                        'fullName': 'IT Operator',
                        'role': 'IT_SECURITY',
                      },
                    }
                  : [
                      {
                        'id': 'event-123',
                        'actorId': 'target',
                        'actorRole': 'SUPER_ADMIN',
                        'action': 'platform.login.failed',
                        'entityType': 'PlatformAccount',
                        'entityId': 'target',
                        'createdAt': '2026-10-08T00:00:00Z',
                        'metadata': {},
                      },
                    ],
            }),
            200,
          );
        }),
      );
      await api.login('it@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.ensureVisible(find.text('Audit trail'));
      await tester.tap(find.text('Audit trail'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('All events'));
      await tester.tap(find.text('All events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed login').last);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['action'], 'platform.login.failed');
      expect(requests.last.queryParameters['page'], '1');
      await tester.ensureVisible(find.text('Event details'));
      await tester.tap(find.text('Event details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Event ID: event-123'), findsOneWidget);
      for (final entry in {
        'IT sign-off recorded': 'tenant.technical-review.recorded',
        'IT sign-off withdrawn': 'tenant.technical-review.withdrawn',
      }.entries) {
        await tester.ensureVisible(find.text('Failed login').first);
        await tester.tap(find.text('Failed login').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(entry.key).last);
        await tester.tap(find.text(entry.key).last);
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['action'], entry.value);
        expect(requests.last.queryParameters['page'], '1');
        // Restore the selected filter for the next iteration.
        await tester.ensureVisible(find.text(entry.key).first);
        await tester.tap(find.text(entry.key).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Failed login').last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
