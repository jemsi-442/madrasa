import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

void main() {
  for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
    testWidgets('overview visibility and failure handling for $role', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var fail = false;
      var reads = 0;
      var reviewQueueOpened = false;
      var approvedQueueOpened = false;
      final api = PlatformApi(
        client: MockClient((req) async {
          dynamic data = [];
          if (req.url.path.endsWith('/login')) {
            data = {
              'accessToken': 'token',
              'expiresIn': 900,
              'user': {'id': 'admin', 'fullName': 'Reviewer', 'role': role},
            };
          } else if (req.url.path.endsWith('/overview')) {
            reads++;
            if (fail) return http.Response('{}', 503);
            data = {
              'checkedAt': '2026-10-08T00:00:00Z',
              'awaitingYourReview': 1,
              'onboarding': {'awaitingSetup': 2, 'pendingActivation': 1},
              'applications': {'REQUESTED': 2, 'APPROVED': 3, 'REJECTED': 0},
              'accounts': {
                'SUPER_ADMIN': {'ACTIVE': 2, 'DISABLED': 0},
                'IT_SECURITY': {'ACTIVE': 1, 'DISABLED': 4},
              },
            };
          }
          if (req.url.path.endsWith('/tenant-applications') &&
              req.url.queryParameters['status'] == 'APPROVED') {
            expect(req.url.queryParameters, {
              'page': '1',
              'pageSize': '20',
              'status': 'APPROVED',
            });
            approvedQueueOpened = true;
          }
          if (req.url.path.endsWith('/tenant-applications') &&
              req.url.queryParameters['scope'] == 'reviewable') {
            expect(req.url.queryParameters, {
              'page': '1',
              'pageSize': '20',
              'status': 'REQUESTED',
              'scope': 'reviewable',
            });
            reviewQueueOpened = true;
          }
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      await api.login('admin@example.test', 'password', '123456');
      await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
      await tester.pumpAndSettle();
      if (role == 'SUPER_ADMIN') {
        await tester.ensureVisible(find.text('Governance overview'));
        await tester.tap(find.text('Governance overview'));
        await tester.pumpAndSettle();
        expect(find.text('Platform snapshot'), findsOneWidget);
        expect(find.text('Disabled IT accounts'), findsOneWidget);
        expect(find.text('Approved, awaiting setup'), findsOneWidget);
        expect(find.text('Created, awaiting activation'), findsOneWidget);
        await tester.ensureVisible(find.text('View approved onboarding'));
        await tester.tap(find.text('View approved onboarding'));
        await tester.pumpAndSettle();
        expect(approvedQueueOpened, isTrue);
        await tester.ensureVisible(find.text('Governance overview'));
        await tester.tap(find.text('Governance overview'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review pending applications'));
        await tester.tap(find.text('Review pending applications'));
        await tester.pumpAndSettle();
        expect(reviewQueueOpened, isTrue);
        expect(find.text('Awaiting my review'), findsOneWidget);
        await tester.ensureVisible(find.text('Governance overview'));
        await tester.tap(find.text('Governance overview'));
        await tester.pumpAndSettle();
        expect(find.text('Platform snapshot'), findsOneWidget);
        fail = true;
        await tester.ensureVisible(find.text('Governance overview'));
        await tester.tap(find.text('Governance overview'));
        await tester.pumpAndSettle();
        expect(find.text('Platform snapshot'), findsNothing);
        expect(reads, 4);
      } else {
        expect(find.text('Governance overview'), findsNothing);
        expect(reads, 0);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
