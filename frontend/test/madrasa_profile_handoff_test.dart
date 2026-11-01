import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/madrasa_profile_handoff.dart';

void main() {
  for (final entry in [
    ('REQUESTED', 'Superadmin'),
    ('APPROVED', 'IT team'),
    ('PENDING_ACTIVATION', 'Check onboarding progress'),
    ('ACTIVE', 'Madrasa administrator'),
    ('TRIAL', 'Madrasa administrator'),
    ('SUSPENDED', 'Office access review'),
    ('REJECTED', 'See decision below'),
    ('UNKNOWN', 'Office review'),
  ]) {
    testWidgets(
      '${entry.$1} shows the handoff on narrow screens with large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MadrasaProfileHandoff(status: entry.$1),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(entry.$2), findsOneWidget);
        if (entry.$1 == 'SUSPENDED') {
          expect(
            find.textContaining('must not be used to restore access'),
            findsOneWidget,
          );
        }
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
