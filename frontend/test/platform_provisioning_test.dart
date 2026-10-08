import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mif_app/src/platform_console.dart';

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
                : [
                    {
                      'id': 'application',
                      'schoolName': 'Afaq School',
                      'requestedCode': 'afaq-school',
                      'status': 'APPROVED',
                    },
                  ],
          }),
          200,
        );
      }),
    );
    await api.login('reviewer@example.test', 'password', '123456');
    await tester.pumpWidget(MaterialApp(home: PlatformConsole(api: api)));
    await tester.ensureVisible(find.text('Madrassa applications'));
    await tester.tap(find.text('Madrassa applications'));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding progress'), findsOneWidget);
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
