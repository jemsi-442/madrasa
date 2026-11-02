import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_backup_requests.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  testWidgets(
    'Permission failure during editing clears history and stops polling',
    (tester) async {
      var reads = 0;
      final response = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformBackupRequests(
                onAudit: () {},
                request: (path, body) async {
                  reads++;
                  if (reads > 1) return response.future;
                  return {
                    'total': 1,
                    'items': [
                      {
                        'createdAt': '2026-10-01T00:00:00Z',
                        'metadata': {
                          'snapshot': 'BKP-PRIVATE',
                          'reason': 'Synthetic recovery scope',
                        },
                      },
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('BKP-PRIVATE'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(reads, 2);
      await tester.ensureVisible(find.text('Request restore test'));
      await tester.tap(find.text('Request restore test'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(find.byType(TextFormField).first, 'BKP-DRAFT');
      response.completeError(const ApiException('Permission denied', 403));
      await tester.pumpAndSettle();
      expect(find.text('BKP-DRAFT'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('BKP-PRIVATE'), findsNothing);
      expect(
        find.text(
          'Access could not be verified. Sign in again or check your permissions.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Automatic updates pause throughout editing and resume after close',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformBackupRequests(
              onAudit: () {},
              request: (path, body) async {
                reads++;
                return {'items': [], 'total': 0};
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(reads, 2);
      await tester.tap(find.text('Request restore test'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'BKP-DRAFT');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('BKP-DRAFT'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(reads, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed next page hides previous records and retries that page', (
    tester,
  ) async {
    final paths = <String>[];
    var failed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlatformBackupRequests(
              onAudit: () {},
              request: (path, body) async {
                paths.add(path);
                if (path.endsWith('page=2') && !failed) {
                  failed = true;
                  throw Exception('Synthetic network failure');
                }
                return {
                  'total': 21,
                  'items': [
                    {
                      'createdAt': '2026-10-01T00:00:00Z',
                      'metadata': {
                        'snapshot': path.endsWith('page=2')
                            ? 'BKP-SECOND'
                            : 'BKP-FIRST',
                        'reason': 'Synthetic recovery scope',
                      },
                    },
                  ],
                };
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BKP-FIRST'), findsOneWidget);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('BKP-FIRST'), findsNothing);
    expect(
      find.text('Could not load restore requests. Try again.'),
      findsOneWidget,
    );
    expect(find.text('No restore tests requested yet.'), findsNothing);
    await tester.ensureVisible(find.text('Check requests'));
    await tester.tap(find.text('Check requests'));
    await tester.pumpAndSettle();
    expect(find.text('BKP-SECOND'), findsOneWidget);
    expect(paths, [
      '/backups/requests?page=1',
      '/backups/requests?page=2',
      '/backups/requests?page=2',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed save keeps form and retry identity', (tester) async {
    final attempts = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformBackupRequests(
            onAudit: () {},
            request: (path, body) async {
              if (body == null) return {'items': [], 'total': 0};
              attempts.add(body);
              throw Exception('Synthetic connection failure');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request restore test'));
    await tester.pumpAndSettle();
    expect(find.text('RECOVERY / TEST REQUEST'), findsOneWidget);
    expect(find.text('Snapshot to test'), findsOneWidget);
    expect(find.text('Test purpose'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'BKP-SYNTHETIC');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Synthetic isolated recovery',
    );
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    expect(find.text('BKP-SYNTHETIC'), findsOneWidget);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    expect(attempts.length, 2);
    expect(attempts[0]['requestId'], attempts[1]['requestId']);
    expect(attempts[1], attempts[0]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Confirmed retry closes form and reloads recorded requests', (
    tester,
  ) async {
    final attempts = <Map<String, dynamic>>[];
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformBackupRequests(
            onAudit: () {},
            request: (path, body) async {
              if (body == null) {
                reads++;
                return {'items': [], 'total': 0};
              }
              attempts.add(body);
              if (attempts.length == 1) {
                throw Exception('Synthetic lost response');
              }
              return {'id': 'synthetic-request'};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request restore test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), ' BKP-SYNTHETIC ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      ' Synthetic isolated recovery ',
    );
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record request'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(attempts, hasLength(2));
    expect(attempts[1], attempts[0]);
    expect(attempts[1]['snapshot'], 'BKP-SYNTHETIC');
    expect(attempts[1]['reason'], 'Synthetic isolated recovery');
    expect(reads, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Request recorded. No restore has been executed.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
