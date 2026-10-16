import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_forms.dart';

void main() {
  for (final entry in <(String, bool)>[
    ('a' * 72, true),
    ('a' * 73, false),
    ('\u00e9' * 36, true),
    ('\u00e9' * 37, false),
    (' secret ', true),
  ]) {
    testWidgets(
      'admin password preserves input and enforces byte limit: ${entry.$1.length}, ${entry.$2}',
      (tester) async {
        String? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAdminForm(
                    context,
                    title: 'Account',
                    fields: const [
                      AdminField('password', 'Password', kind: 'password'),
                    ],
                    onSave: (body) async {
                      saved = body['password'] as String;
                    },
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), entry.$1);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        if (entry.$2) {
          expect(saved, entry.$1);
          expect(find.byType(AlertDialog), findsNothing);
        } else {
          expect(saved, isNull);
          expect(
            find.text('Password is too long (maximum 72 UTF-8 bytes).'),
            findsOneWidget,
          );
        }
      },
    );
  }
}
