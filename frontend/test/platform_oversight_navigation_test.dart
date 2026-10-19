import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'package:mif_app/src/platform_workspace_shell.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';
import 'package:mif_app/src/curriculum_oversight_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final role in ['SUPER_ADMIN', 'IT_SECURITY']) {
      testWidgets('oversight navigation for $role at $width', (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var reportLoads = 0;
        final api = PlatformApi(
          client: MockClient((request) async {
            dynamic data = [];
            if (request.url.path.endsWith('/login')) {
              data = {
                'accessToken': 'synthetic-token',
                'expiresIn': 900,
                'user': {
                  'id': 'test',
                  'fullName': 'Synthetic Operator',
                  'role': role,
                },
              };
            } else if (request.url.path.endsWith('/curriculum/oversight')) {
              reportLoads++;
              data = {'items': [], 'hasMore': false};
            } else if (request.url.path.endsWith('/curriculum')) {
              data = {'items': [], 'total': 0, 'madrasaCount': 0};
            } else if (request.url.path.endsWith('/overview')) {
              data = {
                'applications': {},
                'onboarding': {},
                'awaitingYourReview': 0,
              };
            } else if (request.url.path.endsWith('/health')) {
              data = {'status': 'healthy', 'checks': []};
            }
            return http.Response(jsonEncode({'data': data}), 200);
          }),
        );
        await api.login('synthetic@example.test', 'test-only', '123456');
        await tester.pumpWidget(
          MaterialApp(
            home: PlatformConsole(api: api, onSignedOut: () {}),
          ),
        );
        await tester.pumpAndSettle();
        if (width < 1000) {
          await tester.tap(find.byTooltip('Open navigation'));
          await tester.pumpAndSettle();
        }
        if (role == 'IT_SECURITY') {
          expect(find.text('Learning Oversight'), findsNothing);
          expect(reportLoads, 0);
        } else {
          await tester.ensureVisible(find.text('Learning Oversight'));
          await tester.tap(find.text('Learning Oversight'));
          await tester.pumpAndSettle();
          expect(find.byType(CurriculumOversightPage), findsOneWidget);
          expect(find.byKey(const ValueKey('workspace-footer')), findsOneWidget);
          expect(
            tester
                .widget<PlatformWorkspaceShell>(
                  find.byType(PlatformWorkspaceShell),
                )
                .page,
            PlatformPage.oversight,
          );
          expect(reportLoads, 1);
          final refresh = find.descendant(
            of: find.byType(CurriculumOversightPage),
            matching: find.text('Refresh'),
          );
          await tester.ensureVisible(refresh);
          await tester.tap(refresh);
          await tester.pumpAndSettle();
          expect(reportLoads, 2);
          expect(
            tester
                .widget<PlatformWorkspaceShell>(
                  find.byType(PlatformWorkspaceShell),
                )
                .page,
            PlatformPage.oversight,
          );
          await tester.ensureVisible(find.text('Back to curriculum'));
          await tester.tap(find.text('Back to curriculum'));
          await tester.pumpAndSettle();
          expect(find.byType(PlatformCurriculumPage), findsOneWidget);
          final open = find.descendant(
            of: find.byType(PlatformCurriculumPage),
            matching: find.text('Learning Oversight'),
          );
          await tester.ensureVisible(open);
          await tester.tap(open);
          await tester.pumpAndSettle();
          expect(reportLoads, 3);
          expect(
            tester
                .widget<PlatformWorkspaceShell>(
                  find.byType(PlatformWorkspaceShell),
                )
                .page,
            PlatformPage.oversight,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      });
    }
  }
}
