import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/student_residence_actions.dart';

void main() {
  for (final mode in ['UNKNOWN', 'GUARDIAN', 'SEPARATE']) {
    testWidgets('student residence saves $mode without changing guardian', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editStudentResidence(
                  context,
                  '9',
                  (_) async => {
                    'fullName': 'Synthetic Learner',
                    'revision': '2030-01-01T00:00:00.000Z',
                    'residence': {
                      'mode': mode,
                      if (mode == 'SEPARATE')
                        'location': {'ward': 'Synthetic Ward'},
                    },
                    'guardian': {
                      'id': '4',
                      'fullName': 'Synthetic Guardian',
                      'location': {'ward': 'Guardian Ward'},
                    },
                  },
                  (path, body) async {
                    expect(path, '/api/students/9/residence');
                    saved = body;
                    return {};
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final reason = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Reason for this change',
      );
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Synthetic residence confirmation');
      await tester.ensureVisible(find.text('Save residence'));
      await tester.tap(find.text('Save residence'));
      await tester.pumpAndSettle();
      expect(saved?['residence'], {
        'mode': mode,
        if (mode == 'GUARDIAN') 'guardianId': '4',
        if (mode == 'SEPARATE') 'location': {'ward': 'Synthetic Ward'},
      });
      expect(saved?['revision'], '2030-01-01T00:00:00.000Z');
      expect(tester.takeException(), isNull);
    });
  }
}
