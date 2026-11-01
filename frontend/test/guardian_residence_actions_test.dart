import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/student_record_actions.dart';

void main() {
  for (final conflict in [false, true]) {
    testWidgets(
      'guardian residence action saves or keeps conflicting form conflict=$conflict',
      (tester) async {
        Map<String, dynamic>? submitted;
        var changed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentRecordActions(
                student: const {'id': '9', 'fullName': 'Synthetic Learner'},
                load: (path) async {
                  expect(path, '/api/students/9/guardian-residence');
                  return {
                    'guardianId': '4',
                    'fullName': 'Synthetic Guardian',
                    'revision': '2030-01-01T00:00:00.000Z',
                    'legacyAddress': 'Previous address',
                    'location': {
                      'country': 'Tanzania',
                      'ward': 'Synthetic Ward',
                    },
                  };
                },
                submit: (path, body) async {
                  expect(path, '/api/students/9/guardian-residence');
                  submitted = body;
                  if (conflict) {
                    throw const ApiException('private diagnostic', 409);
                  }
                  return {};
                },
                onChanged: () => changed++,
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Manage Synthetic Learner'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit guardian residence'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Previous address retained: Previous address'),
          findsOneWidget,
        );
        final reason = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  'Reason for this change (at least 10 characters)',
        );
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'short');
        await tester.tap(find.text('Save residence'));
        await tester.pumpAndSettle();
        expect(submitted, isNull);
        expect(find.text('Enter at least 10 characters'), findsOneWidget);
        await tester.enterText(reason, 'Synthetic address correction');
        await tester.tap(find.text('Save residence'));
        await tester.pumpAndSettle();
        expect(submitted?['guardianId'], '4');
        expect(submitted?['revision'], '2030-01-01T00:00:00.000Z');
        expect(submitted?['location'], {
          'country': 'Tanzania',
          'ward': 'Synthetic Ward',
        });
        expect(changed, conflict ? 0 : 1);
        expect(
          find.textContaining('Close and reopen this form'),
          conflict ? findsOneWidget : findsNothing,
        );
        expect(find.text('private diagnostic'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('access denial opens no editable guardian form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentRecordActions(
            student: const {'id': '9', 'fullName': 'Synthetic Learner'},
            load: (_) async =>
                throw const ApiException('private diagnostic', 403),
            submit: (_, _) async {
              fail('Must not save');
            },
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Manage Synthetic Learner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit guardian residence'));
    await tester.pumpAndSettle();
    expect(find.text('Save residence'), findsNothing);
    expect(find.textContaining('school-wide administrator'), findsOneWidget);
    expect(find.text('private diagnostic'), findsNothing);
  });
}
