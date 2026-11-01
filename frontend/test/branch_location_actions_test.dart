import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/branch_location_actions.dart';

void main() {
  testWidgets('branch editor retains structured fields and submits revision', (
    tester,
  ) async {
    String? postedPath;
    Map<String, dynamic>? posted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => editBranchLocation(
                context,
                (path) async => [
                  {
                    'id': '7',
                    'name': 'Synthetic Branch',
                    'revision': '2030-01-01T00:00:00.000Z',
                    'location': 'Legacy location',
                    'structuredLocation': {
                      'country': 'Tanzania',
                      'region': 'Synthetic Region',
                      'district': 'Synthetic District',
                      'ward': 'Synthetic Ward',
                    },
                  },
                ],
                (path, body) async {
                  postedPath = path;
                  posted = body;
                  return {};
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic Branch'));
    await tester.pumpAndSettle();
    expect(find.text('Previous address: Legacy location'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(postedPath, '/api/organizations/branches/7/location');
    expect(posted?['revision'], '2030-01-01T00:00:00.000Z');
    expect((posted?['location'] as Map)['ward'], 'Synthetic Ward');
    expect(find.text('Branch location saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
