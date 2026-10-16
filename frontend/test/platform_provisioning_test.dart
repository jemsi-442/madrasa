import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';
import 'helpers/platform_navigation.dart';

void main() {
  testWidgets('office workspace does not expose technical setup checks', (
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
                      'id': 'reviewer',
                      'fullName': 'Reviewer',
                      'role': 'SUPER_ADMIN',
                    },
                  }
                : {
                    'total': 1,
                    'items': [
                      {
                        'id': 'application',
                        'name': 'Afaq School',
                        'applicationId': 'application',
                        'code': 'afaq-school',
                        'admins': [],
                        'locations': [],
                        'status': 'APPROVED',
                      },
                    ],
                  },
          }),
          200,
        );
      }),
    );
    await api.login('reviewer@example.test', 'password', '123456');
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    await openPlatformPage(tester, 'Madrassa applications');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage →'));
    await tester.tap(find.text('Manage →'));
    await tester.pumpAndSettle();
    expect(find.text('Review onboarding'), findsOneWidget);
    expect(find.text('Check setup readiness'), findsNothing);
    expect(find.text('System health'), findsNothing);
    expect(find.text('Audit trail'), findsNothing);
    expect(find.text('Madrassa setup'), findsNothing);
    expect(
      requests.any((uri) => uri.path.endsWith('/provisioning-preflight')),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
