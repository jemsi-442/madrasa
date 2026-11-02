import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/security_incident_register.dart';

void main() {
  testWidgets(
    'response retry keeps its payload and reloads after confirmation',
    (tester) async {
      final submissions = <Map<String, dynamic>>[];
      var detailReads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityIncidentRegister(
              initialIncidentId: 'synthetic-incident',
              request: (path, body) async {
                if (body != null) {
                  expect(path, '/incidents/synthetic-incident');
                  submissions.add(Map<String, dynamic>.from(body));
                  if (submissions.length == 1) throw Exception('Response lost');
                  return {'id': 'synthetic-incident'};
                }
                if (path.contains('?')) {
                  return {
                    'items': [],
                    'total': 0,
                    'open': 1,
                    'high': 0,
                    'resolved': 0,
                  };
                }
                detailReads++;
                return {
                  'id': 'synthetic-incident',
                  'title': 'Synthetic concern',
                  'description': 'Synthetic investigation',
                  'priority': 'MEDIUM',
                  'status': 'OPEN',
                  'revision': detailReads,
                  'entries': [],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Update response'));
      await tester.tap(find.text('Update response'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic response retained',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic response retained'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(DropdownButtonFormField<String>),
              ),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(submissions.length, 2);
      expect(submissions[0], submissions[1]);
      expect(submissions.first['revision'], 1);
      expect(
        submissions.first['requestId'],
        matches(RegExp(r'^[a-f0-9]{48}$')),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(detailReads, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('filters request server results with combined criteria', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityIncidentRegister(
            request: (path, body) async {
              paths.add(path);
              return {
                'items': [],
                'total': 0,
                'open': 3,
                'high': 1,
                'resolved': 2,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('All statuses'));
    await tester.tap(find.text('All statuses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investigating').last);
    await tester.pumpAndSettle();
    expect(paths.last, '/incidents?page=1&status=INVESTIGATING');
    await tester.ensureVisible(find.text('All priorities'));
    await tester.tap(find.text('All priorities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    expect(paths.last, '/incidents?page=1&status=INVESTIGATING&priority=HIGH');
    expect(find.text('No incidents match these filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('opens overview incident independently of list page', (
    tester,
  ) async {
    final paths = <String>[];
    var failDetail = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityIncidentRegister(
            initialIncidentId: 'synthetic-older',
            request: (path, body) async {
              paths.add(path);
              if (path.contains('?')) {
                return {
                  'items': [],
                  'total': 0,
                  'open': 1,
                  'high': 1,
                  'resolved': 0,
                };
              }
              if (failDetail) throw Exception('Synthetic detail failure');
              return {
                'id': 'synthetic-older',
                'title': 'Synthetic older concern',
                'description': 'Synthetic description',
                'priority': 'HIGH',
                'status': 'OPEN',
                'revision': 1,
                'entries': [],
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paths, contains('/incidents/synthetic-older'));
    expect(find.text('Synthetic older concern'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(paths.where((p) => p == '/incidents/synthetic-older').length, 2);
    expect(find.text('Synthetic older concern'), findsOneWidget);
    failDetail = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic older concern'), findsNothing);
    expect(find.text('Could not load the incident.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('incident form retains input on failed save', (tester) async {
    final submissions = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityIncidentRegister(
            request: (path, body) async {
              if (body != null) {
                submissions.add(Map<String, dynamic>.from(body));
                throw Exception('synthetic failure');
              }
              return {
                'items': [],
                'total': 0,
                'open': 0,
                'high': 0,
                'resolved': 0,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No incidents recorded.'), findsOneWidget);
    await tester.tap(find.text('Record incident'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Synthetic event');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Synthetic investigation note',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save could not be confirmed'), findsOneWidget);
    expect(find.text('Synthetic event'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submissions.length, 2);
    expect(submissions[0], submissions[1]);
    expect(submissions.first['requestId'], matches(RegExp(r'^[a-f0-9]{48}$')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
