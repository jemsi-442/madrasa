import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/security_incident_register.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  for (final status in [401, 403, 409]) {
    testWidgets(
      'Detail denial locks writes until a successful access check status=$status',
      (tester) async {
        var denied = true;
        var reads = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SecurityIncidentRegister(
                initialIncidentId: 'synthetic-private',
                request: (path, body) async {
                  expect(body, isNull);
                  reads++;
                  if (!path.contains('?') || denied && reads > 2) {
                    throw ApiException('Synthetic denial', status);
                  }
                  return {
                    'items': [
                      {
                        'id': 'synthetic-private',
                        'title': 'Private synthetic incident',
                        'priority': 'LOW',
                        'status': 'OPEN',
                      },
                    ],
                    'total': 1,
                    'open': 1,
                    'high': 0,
                    'resolved': 0,
                  };
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Private synthetic incident'), findsNothing);
        final create = find.ancestor(
          of: find.text('Record incident'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(tester.widget<FilledButton>(create).onPressed, isNull);
        await tester.pump(const Duration(seconds: 60));
        await tester.pumpAndSettle();
        expect(reads, 2);
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(create).onPressed, isNull);
        denied = false;
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
        expect(find.text('Private synthetic incident'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final denied in [false, true]) {
    testWidgets('Failed initial read retains receipt draft denied=$denied', (
      tester,
    ) async {
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityIncidentRegister(
              initialDescription: 'Receipt: SYNTHETIC-RECEIPT',
              request: (path, body) async {
                if (body != null) writes++;
                if (denied) throw const ApiException('Denied', 403);
                throw Exception('Synthetic offline connection');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Not saved yet'), findsOneWidget);
      final button = find.ancestor(
        of: find.text('Continue receipt draft'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(
        tester.widget<FilledButton>(button).onPressed,
        denied ? isNull : isNotNull,
      );
      if (!denied) {
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller!
              .text,
          'Receipt: SYNTHETIC-RECEIPT',
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Continue receipt draft'), findsNothing);
        expect(find.textContaining('Not saved yet'), findsNothing);
      }
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  for (final fails in [false, true]) {
    testWidgets(
      'Late incident response cannot replace newer choice failure=$fails',
      (tester) async {
        final first = Completer<dynamic>();
        Map<String, dynamic> incident(String id) => {
          'id': id,
          'title': 'Synthetic $id',
          'description': 'Details for $id',
          'priority': 'MEDIUM',
          'status': 'OPEN',
          'revision': 1,
          'entries': [],
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SecurityIncidentRegister(
                request: (path, body) async {
                  if (path.contains('?')) {
                    return {
                      'items': [incident('first'), incident('second')],
                      'total': 2,
                      'open': 2,
                      'high': 0,
                      'resolved': 0,
                    };
                  }
                  if (path.endsWith('/first')) return first.future;
                  return incident('second');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final buttons = tester
            .widgetList<TextButton>(find.widgetWithText(TextButton, 'Open'))
            .toList();
        // Two queued actions before the next frame disables the controls.
        buttons[0].onPressed!();
        buttons[1].onPressed!();
        await tester.pumpAndSettle();
        expect(find.text('Details for second'), findsOneWidget);
        if (fails) {
          first.completeError(Exception('Synthetic late failure'));
        } else {
          first.complete(incident('first'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Details for second'), findsOneWidget);
        expect(find.text('Details for first'), findsNothing);
        expect(find.text('Could not load the incident.'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Background updates preserve selected incident and pause for response form',
    (tester) async {
      var lists = 0, details = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityIncidentRegister(
              initialIncidentId: 'synthetic-incident',
              request: (path, body) async {
                expect(body, isNull);
                if (path.contains('?')) {
                  lists++;
                  return {
                    'items': [],
                    'total': 0,
                    'open': 1,
                    'high': 0,
                    'resolved': 0,
                  };
                }
                details++;
                return {
                  'id': 'synthetic-incident',
                  'title': 'Synthetic concern',
                  'description': 'Synthetic investigation',
                  'priority': 'MEDIUM',
                  'status': 'OPEN',
                  'revision': details,
                  'entries': [],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lists, 1);
      expect(details, 1);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(lists, 2);
      expect(details, 2);
      expect(find.text('Synthetic concern'), findsOneWidget);
      await tester.ensureVisible(find.text('Update response'));
      await tester.tap(find.text('Update response'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic unsaved response',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(lists, 2);
      expect(details, 2);
      expect(find.text('Synthetic unsaved response'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(lists, 3);
      expect(details, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(lists, 3);
      expect(tester.takeException(), isNull);
    },
  );

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
