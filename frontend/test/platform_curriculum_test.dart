import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/platform_curriculum_page.dart';

void main() {
  testWidgets(
    'lesson objective rejection retains details and allows correction',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final row = <String, dynamic>{
        'id': 'lesson-retry',
        'subject': 'Arabic',
        'level': 'Level 1',
        'version': '1.0',
        'description': 'Reading foundations',
        'status': 'DRAFT',
        'updatedAt': '2026-10-20T10:00:00.000Z',
        'objectives': ['Read simple words'],
        'topics': [
          {
            'id': 'topic-1',
            'title': 'Reading',
            'position': 1,
            'objectives': [
              for (final id in ['first', 'second'])
                {
                  'id': id,
                  'code': id,
                  'description': 'Read simple words clearly',
                  'assessmentMethod': 'ORAL',
                  'criteria': 'Read three words correctly',
                },
            ],
          },
        ],
        'lessons': [
          {
            'id': 'lesson-1',
            'title': 'Reading practice',
            'position': 1,
            'durationMinutes': 30,
            'activities': 'Read together with a partner',
            'objectives': [
              {'objectiveId': 'first'},
              {'objectiveId': 'second'},
            ],
          },
        ],
        'reviews': [],
        'assignments': [],
        '_count': {'assignments': 0},
      };
      final writes = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'superadmin',
              onSessionExpired: () {},
              call: (path, {body}) async {
                if (path.endsWith('/lessons/lesson-1')) {
                  writes.add(Map<String, dynamic>.from(body!));
                  if (writes.length == 1) {
                    throw const ApiException(
                      'Choose objectives from this framework version',
                      422,
                    );
                  }
                  return {'id': row['id']};
                }
                return {
                  'items': [row],
                  'total': 1,
                  'madrasaCount': 1,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lesson Plans').first);
      await tester.tap(find.text('Lesson Plans').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit lesson plan'));
      await tester.tap(find.text('Edit lesson plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('One or more selected objectives'),
        findsOneWidget,
      );
      expect(find.text('Read together with a partner'), findsWidgets);
      final selection = find.widgetWithText(
        CheckboxListTile,
        'second - Read simple words clearly',
      );
      await tester.ensureVisible(selection);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lesson'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(2));
      expect(writes.last['objectiveIds'], ['first']);
      expect(writes.last['activities'], writes.first['activities']);
      expect(writes.last['expectedUpdatedAt'], row['updatedAt']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed draft save retains input and permits a single retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = <String, dynamic>{
      'id': 'retry-draft',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Original description',
      'status': 'DRAFT',
      'updatedAt': '2026-10-19T10:00:00.000Z',
      'objectives': ['Read simple words'],
      'topics': [],
      'lessons': [],
      'reviews': [],
      'assignments': [],
      '_count': {'assignments': 0},
    };
    final pending = Completer<dynamic>();
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (path.endsWith('/edit')) {
                writes.add(Map<String, dynamic>.from(body!));
                if (writes.length == 1) return pending.future;
                row['description'] = body['description'];
                return {'id': row['id']};
              }
              return {
                'items': [row],
                'total': 1,
                'madrasaCount': 1,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit draft'));
    await tester.tap(find.text('Edit draft'));
    await tester.pumpAndSettle();
    final description = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        )
        .at(2);
    await tester.enterText(description, 'Preserve my revised learning plan');
    await tester.tap(find.text('Save draft'));
    await tester.pump();
    expect(writes, hasLength(1));
    final savingButton = find.ancestor(
      of: find.text('Saving...'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(savingButton).onPressed, isNull);
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(tester.widgetList<TextField>(fields), hasLength(5));
    expect(
      tester.widgetList<TextField>(fields).every((field) => field.readOnly),
      isTrue,
    );
    pending.completeError(const ApiException('Service unavailable', 503));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Could not save.'), findsOneWidget);
    expect(
      tester.widgetList<TextField>(fields).every((field) => !field.readOnly),
      isTrue,
    );
    expect(
      tester.widget<TextFormField>(description).controller!.text,
      'Preserve my revised learning plan',
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes.last, equals(writes.first));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Preserve my revised learning plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate clone version explains how to recover', (
    tester,
  ) async {
    final cloneRequests = <Map<String, dynamic>>[];
    Map<String, dynamic>? created;
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final framework = <String, dynamic>{
      'id': 'published-framework',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Arabic foundations',
      'status': 'PUBLISHED',
      'objectives': ['Read simple words'],
      'topics': [],
      'lessons': [],
      'reviews': [],
      '_count': {'assignments': 0},
      'assignments': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (path.endsWith('/clone')) {
                cloneRequests.add(Map<String, dynamic>.from(body!));
                if (cloneRequests.length == 1) {
                  throw const ApiException(
                    'This subject version already exists',
                    409,
                  );
                }
                created = {
                  ...framework,
                  'id': 'new-draft',
                  'version': body['version'],
                  'status': 'DRAFT',
                };
                return {'id': 'new-draft'};
              }
              return {
                'items': [created ?? framework],
                'total': 1,
                'madrasaCount': 1,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View unpublished'), findsOneWidget);
    expect(find.text('Submit for approval'), findsNothing);
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Versions'));
    await tester.tap(find.text('Versions'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create new version'));
    await tester.tap(find.text('Create new version'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '1.1');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Update the reading objectives for the next term.',
    );
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'That version already exists for this subject and level. Choose a different version number.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Update the reading objectives for the next term.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '1.2');
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(cloneRequests, hasLength(2));
    expect(cloneRequests.last, {
      'version': '1.2',
      'reason': 'Update the reading objectives for the next term.',
    });
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Version 1.2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('version history shows account names, not internal actor IDs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final framework = <String, dynamic>{
      'id': 'history-framework',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Arabic foundations',
      'status': 'PUBLISHED',
      'createdBy': 'internal-author-id',
      'createdByName': 'Curriculum Author',
      'objectives': [],
      'topics': [],
      'lessons': [],
      'reviews': [
        {
          'actorId': 'internal-reviewer-id',
          'actorName': 'Super Admin',
          'fromStatus': 'DRAFT',
          'toStatus': 'PUBLISHED',
          'createdAt': '2026-10-20T10:00:00.000Z',
        },
      ],
      '_count': {'assignments': 0},
      'assignments': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (path, {body}) async => {
              'items': [framework],
              'total': 1,
              'madrasaCount': 1,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Versions'));
    await tester.tap(find.text('Versions'));
    await tester.pumpAndSettle();

    expect(find.text('Prepared by: Curriculum Author'), findsOneWidget);
    expect(find.text('Draft → Published'), findsOneWidget);
    expect(find.textContaining('Super Admin · 20 Oct 2026'), findsOneWidget);
    expect(find.textContaining('internal-author-id'), findsNothing);
    expect(find.textContaining('internal-reviewer-id'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final reloadFails in [false, true]) {
    testWidgets(
      'recovers after a concurrent edit; reload fails: $reloadFails',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final initial = <String, dynamic>{
          'id': 'draft-conflict',
          'subject': 'Arabic',
          'level': 'Level 1',
          'version': '1.0',
          'description': 'Original draft description',
          'status': 'DRAFT',
          'updatedAt': '2026-10-19T10:00:00.000Z',
          'objectives': ['Read simple words'],
          'topics': [],
          'lessons': [],
          'reviews': [],
          '_count': {'assignments': 0},
          'assignments': [],
        };
        final latest = {
          ...initial,
          'description': 'Concurrent administrator update',
          'updatedAt': '2026-10-19T11:00:00.000Z',
        };
        var conflictRaised = false;
        var failNextReload = reloadFails;
        final requests = <String>[];
        final submittedBodies = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformCurriculumPage(
                accountId: 'superadmin',
                onSessionExpired: () {},
                call: (path, {body}) async {
                  requests.add(path);
                  if (body != null) submittedBodies.add(body);
                  if (path.endsWith('/edit')) {
                    conflictRaised = true;
                    throw const ApiException('Framework changed', 409);
                  }
                  if (conflictRaised && failNextReload) {
                    failNextReload = false;
                    throw const ApiException('Temporarily unavailable', 503);
                  }
                  return {
                    'items': [
                      path.contains('&id=') && conflictRaised
                          ? latest
                          : initial,
                    ],
                    'total': 1,
                    'madrasaCount': 1,
                  };
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Open framework'));
        await tester.tap(find.text('Open framework'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Edit draft'));
        await tester.tap(find.text('Edit draft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();

        expect(
          requests.any((path) => path.contains('id=draft-conflict')),
          isTrue,
        );
        expect(
          submittedBodies.single['expectedUpdatedAt'],
          initial['updatedAt'],
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Concurrent administrator update'),
          reloadFails ? findsNothing : findsOneWidget,
        );
        if (reloadFails) {
          expect(
            find.textContaining('The latest version could not be loaded'),
            findsOneWidget,
          );
        }
        expect(find.text('Original draft description'), findsOneWidget);
        expect(
          find.textContaining('Cancel and reopen the latest draft'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save draft'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Discard edits & view latest'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        if (reloadFails) {
          expect(find.text('Edit draft'), findsNothing);
          await tester.ensureVisible(find.text('Try again'));
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(submittedBodies, hasLength(1));
        }
        expect(find.text('Concurrent administrator update'), findsOneWidget);
        await tester.ensureVisible(find.text('Edit draft'));
        await tester.tap(find.text('Edit draft'));
        await tester.pumpAndSettle();
        expect(find.text('Original draft description'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save draft'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('grouped levels and isolated framework sections at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rows = [
        for (final level in [1, 2])
          {
            'id': 'v$level',
            'subject': 'Arabic',
            'level': 'Level $level',
            'version': '1.0',
            'description': 'Arabic foundations',
            'status': 'DRAFT',
            'objectives': ['Read independently'],
            '_count': {'assignments': 0},
            'assignments': [],
            'topics': [],
            'lessons': [
              {
                'title': 'Practice reading',
                'durationMinutes': 20,
                'activities': 'Read with a partner',
                'objectives': [],
              },
            ],
          },
      ];
      rows.add({...rows.first, 'id': 'fiqh', 'subject': 'Fiqh'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async => {
                'items': path.contains('&id=') ? [rows.first] : rows,
                'total': path.contains('&id=') ? 1 : rows.length,
                'madrasaCount': 2,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsNWidgets(3));
      expect(find.textContaining('Level: Level 1'), findsNWidgets(2));
      expect(find.textContaining('Level: Level 2'), findsOneWidget);
      final arabic = tester.getRect(
        find.byKey(const ValueKey('subject-group-Arabic')),
      );
      final fiqh = tester.getRect(
        find.byKey(const ValueKey('subject-group-Fiqh')),
      );
      if (width > 1000) {
        expect(fiqh.top, arabic.top);
        expect(fiqh.left - arabic.right, closeTo(20, 0.1));
      } else {
        expect(fiqh.left, arabic.left);
        expect(fiqh.top - arabic.bottom, closeTo(24, 0.1));
      }
      await tester.ensureVisible(find.text('Open framework').first);
      await tester.tap(find.text('Open framework').first);
      await tester.pumpAndSettle();
      expect(find.text('- Read independently'), findsOneWidget);
      expect(find.text('Read with a partner'), findsNothing);
      expect(find.textContaining('Next step: Add topics'), findsOneWidget);
      final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publish version'),
      );
      expect(publish.onPressed, isNull);
      await tester.ensureVisible(find.text('Lesson Plans').first);
      await tester.tap(find.text('Lesson Plans').first);
      await tester.pumpAndSettle();
      expect(find.text('Read with a partner'), findsOneWidget);
      expect(find.text('- Read independently'), findsNothing);
      await tester.ensureVisible(find.text('Topics & Objectives').first);
      await tester.tap(find.text('Topics & Objectives').first);
      await tester.pumpAndSettle();
      expect(find.text('Read with a partner'), findsNothing);
      expect(find.text('Add topic & objectives'), findsOneWidget);
      await tester.ensureVisible(find.text('Assignments').first);
      await tester.tap(find.text('Assignments').first);
      await tester.pumpAndSettle();
      expect(find.text('Not assigned yet.'), findsOneWidget);
      expect(find.text('Add topic & objectives'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'save opens the exact draft and author publishes without approval',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final reads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async {
                if (body != null) {
                  if (path == '/curriculum') {
                    saved = {
                      ...body,
                      'id': 'saved-version',
                      'status': 'DRAFT',
                      'updatedAt': '2026-10-19T10:00:00.000Z',
                      'createdBy': 'author',
                      '_count': {'assignments': 0},
                      'assignments': [],
                      'topics': [
                        {
                          'title': 'Reading',
                          'position': 1,
                          'objectives': [
                            {
                              'code': 'READ',
                              'description': 'Read simple words',
                              'assessmentMethod': 'ORAL',
                              'criteria': 'Read three words correctly',
                            },
                          ],
                        },
                      ],
                    };
                  } else if (path.endsWith('/transition')) {
                    saved!['status'] = 'PUBLISHED';
                  }
                  return {'id': 'saved-version'};
                }
                reads.add(path);
                return {
                  'items': [if (saved != null) saved],
                  'total': saved == null ? 0 : 1,
                  'madrasaCount': 2,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New framework'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Arabic');
      await tester.enterText(fields.at(2), 'Arabic foundations');
      await tester.enterText(fields.at(3), 'Read simple words');
      await tester.enterText(fields.at(4), 'Level 1');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(reads.last, contains('id=saved-version'));
      expect(
        find.textContaining('Next step: check your draft'),
        findsOneWidget,
      );
      expect(find.text('- Read simple words'), findsOneWidget);
      await tester.ensureVisible(find.text('Publish version'));
      await tester.tap(find.text('Publish version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish now'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Assigned to 0 of 2 active madrasas'),
        findsOneWidget,
      );
      expect(find.text('Publish version'), findsNothing);
      await tester.tap(find.text('Back to subject library'));
      await tester.pumpAndSettle();
      expect(reads.last, '/curriculum?page=1');
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('curriculum layout and objectives at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'author',
              onSessionExpired: () {},
              call: (path, {body}) async => {
                'total': 1,
                'madrasaCount': 2,
                'items': [
                  {
                    'id': 'v1',
                    'subject': 'Quran',
                    'version': '1.0',
                    'description': 'Recitation',
                    'objectives': ['Recite clearly'],
                    'status': 'PUBLISHED',
                    'createdBy': 'author',
                    '_count': {'assignments': 1},
                    'assignments': [
                      {
                        'organization': {'name': 'Afaq School', 'code': 'AFQ'},
                      },
                    ],
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quran'), findsNWidgets(2));
      expect(find.text('1 / 2 active madrasas'), findsOneWidget);
      expect(find.text('Assigned to 1 active madrasa(s).'), findsOneWidget);
      expect(
        find.text('Assigned; no class adoption record exists yet.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Learning objectives').first);
      await tester.tap(find.text('Learning objectives').first);
      await tester.pumpAndSettle();
      expect(find.text('- Recite clearly'), findsOneWidget);
      expect(find.text('Release control'), findsOneWidget);
      await tester.ensureVisible(find.text('Versions & publishing'));
      await tester.tap(find.text('Versions & publishing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create new version'));
      await tester.tap(find.text('Create new version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.text('Use a version such as 1.1'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '1.0');
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a different version number'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();
      expect(find.text('Back to subject library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('release status distinguishes subject mapping from adoption', (
    tester,
  ) async {
    final framework = {
      'id': 'published-framework',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Reading foundations',
      'status': 'PUBLISHED',
      'objectives': ['Read fluently'],
      'topics': [],
      'lessons': [],
      '_count': {'assignments': 2},
      'assignments': [
        {
          'id': 'assignment-1',
          'organizationId': '10',
          'subjectId': '20',
          'subject': {'name': 'Arabic language', 'isActive': true},
          'organization': {
            'name': 'Afaq Madrasa',
            'code': 'AFQ',
            'status': 'ACTIVE',
          },
          '_count': {'adoptions': 2},
        },
        {
          'id': 'assignment-suspended',
          'organizationId': '11',
          'subjectId': '21',
          'subject': {'name': 'Arabic', 'isActive': true},
          'organization': {
            'name': 'Paused Madrasa',
            'code': 'PAU',
            'status': 'SUSPENDED',
          },
          '_count': {'adoptions': 8},
        },
        {
          'id': 'assignment-trial',
          'organizationId': '12',
          'subjectId': '22',
          'subject': {'name': 'Arabic', 'isActive': true},
          'organization': {
            'name': 'Trial Madrasa',
            'code': 'TRY',
            'status': 'TRIAL',
          },
          '_count': {'adoptions': 3},
        },
      ],
    };
    var assignmentPickerLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (path == '/madrasas?status=ACTIVE&export=true') {
                assignmentPickerLoads++;
                return {'items': []};
              }
              return {
                'items': [framework],
                'total': 1,
                'madrasaCount': 1,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'All active madrasa assignments have a linked active school subject.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 class adoption record(s) across active madrasas.'),
      findsOneWidget,
    );
    expect(find.textContaining('1 / 1 active madrasas'), findsOneWidget);
    await tester.ensureVisible(find.text('Madrasa assignments'));
    await tester.tap(find.text('Madrasa assignments'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('School subject: Arabic language'),
      findsOneWidget,
    );
    expect(find.textContaining('2 class adoption records'), findsOneWidget);
    expect(
      find.textContaining('Madrasa suspended · 8 historical class adoptions'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Trial access · 3 existing class adoptions'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2 recorded class adoption(s) at active madrasas. 3 existing class adoption(s) at 1 trial madrasa(s) remain available. 1 suspended assignment(s) are retained as history.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Assigned to all 1 active madrasas.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Review assignments'));
    await tester.tap(find.text('Review assignments'));
    await tester.pumpAndSettle();
    expect(find.text('Assignments'), findsWidgets);
    expect(assignmentPickerLoads, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy class adoption without a subject link is flagged', (
    tester,
  ) async {
    final framework = {
      'id': 'legacy-framework',
      'subject': 'Fiqh',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Foundations of worship',
      'status': 'PUBLISHED',
      'objectives': ['Explain daily practices'],
      'topics': [],
      'lessons': [],
      '_count': {'assignments': 2},
      'assignments': [
        {
          'id': 'legacy-assignment',
          'organizationId': '10',
          'subjectId': null,
          'subject': null,
          'organization': {'name': 'Afaq Madrasa', 'code': 'AFQ'},
          '_count': {'adoptions': 1},
        },
        {
          'id': 'inactive-subject-assignment',
          'organizationId': '11',
          'subjectId': '21',
          'subject': {'name': 'Arabic', 'isActive': false},
          'organization': {'name': 'Rahma Madrasa', 'code': 'RAH'},
          '_count': {'adoptions': 1},
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (_, {body}) async => {
              'items': [framework],
              'total': 1,
              'madrasaCount': 2,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'check existing adoptions before changing legacy mappings',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Madrasa assignments'));
    await tester.tap(find.text('Madrasa assignments'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Existing class adoption needs subject-link review'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 class adoption record · Inactive subject: Arabic'),
      findsOneWidget,
    );
    expect(find.textContaining('1 class adoption record'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('publish readiness requires measurable assessment criteria', (
    tester,
  ) async {
    final framework = {
      'id': 'draft-framework',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Reading foundations',
      'status': 'DRAFT',
      'objectives': ['Read simple words'],
      'topics': [
        {
          'title': 'Reading',
          'position': 1,
          'objectives': [
            {
              'code': 'READ-01',
              'description': 'Read simple words clearly',
              'assessmentMethod': 'ORAL',
              'criteria': ' ',
            },
          ],
        },
      ],
      'lessons': [],
      '_count': {'assignments': 0},
      'assignments': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (_, {body}) async => {
              'items': [framework],
              'total': 1,
              'madrasaCount': 1,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Add achievement criteria for objective READ-01'),
      findsOneWidget,
    );
    final publish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publish version'),
    );
    expect(publish.onPressed, isNull);
    await tester.ensureVisible(find.text('Organise topics'));
    await tester.tap(find.text('Organise topics'));
    await tester.pumpAndSettle();
    expect(find.text('Add topic & objectives'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final duplicateTopics in [true, false]) {
    testWidgets(
      duplicateTopics
          ? 'publish readiness rejects duplicate topic order'
          : 'publish readiness rejects duplicate lesson order',
      (tester) async {
        final validObjective = {
          'id': 'objective-reading',
          'code': 'READ-01',
          'description': 'Read simple words clearly',
          'assessmentMethod': 'ORAL',
          'criteria': 'Read at least three words correctly',
        };
        final framework = {
          'id': 'ordered-draft',
          'subject': 'Arabic',
          'level': 'Level 1',
          'version': '1.0',
          'description': 'Reading foundations',
          'status': 'DRAFT',
          'objectives': ['Read simple words'],
          'topics': [
            {
              'title': 'Reading',
              'position': 1,
              'objectives': [validObjective],
            },
            if (duplicateTopics)
              {
                'title': 'Comprehension',
                'position': 1,
                'objectives': [
                  {...validObjective, 'code': 'READ-02'},
                ],
              },
          ],
          'lessons': duplicateTopics
              ? []
              : [
                  {
                    'title': 'Reading practice',
                    'position': 1,
                    'durationMinutes': 20,
                    'activities': 'Read and repeat the target words.',
                    'objectives': [
                      {
                        'objectiveId': 'objective-reading',
                        'objective': {
                          'id': 'objective-reading',
                          'code': 'READ-01',
                        },
                      },
                    ],
                  },
                  {
                    'title': 'Comprehension practice',
                    'position': 1,
                    'durationMinutes': 20,
                    'activities': 'Read and explain the short passage.',
                    'objectives': [
                      {
                        'objectiveId': 'objective-reading',
                        'objective': {
                          'id': 'objective-reading',
                          'code': 'READ-01',
                        },
                      },
                    ],
                  },
                ],
          '_count': {'assignments': 0},
          'assignments': [],
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlatformCurriculumPage(
                accountId: 'superadmin',
                onSessionExpired: () {},
                call: (_, {body}) async => {
                  'items': [framework],
                  'total': 1,
                  'madrasaCount': 1,
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Open framework'));
        await tester.tap(find.text('Open framework'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            duplicateTopics
                ? 'Give every topic a different order number.'
                : 'Give every lesson plan a different order number.',
          ),
          findsOneWidget,
        );
        final publish = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Publish version'),
        );
        expect(publish.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('publish readiness requires lessons to use framework objectives', (
    tester,
  ) async {
    final framework = {
      'id': 'lesson-link-draft',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Reading foundations',
      'status': 'DRAFT',
      'objectives': ['Read simple words'],
      'topics': [
        {
          'title': 'Reading',
          'position': 1,
          'objectives': [
            {
              'id': 'objective-current',
              'code': 'READ-01',
              'description': 'Read simple words clearly',
              'assessmentMethod': 'ORAL',
              'criteria': 'Read at least three words correctly',
            },
          ],
        },
      ],
      'lessons': [
        {
          'id': 'lesson-1',
          'title': 'Reading practice',
          'position': 1,
          'durationMinutes': 20,
          'activities': 'Read and repeat the target words.',
          'objectives': [
            {
              'objectiveId': 'objective-from-another-version',
              'objective': {
                'id': 'objective-from-another-version',
                'code': 'READ-02',
              },
            },
          ],
        },
      ],
      '_count': {'assignments': 0},
      'assignments': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (_, {body}) async => {
              'items': [framework],
              'total': 1,
              'madrasaCount': 1,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Link "Reading practice" to at least one objective from this framework.',
      ),
      findsOneWidget,
    );
    final publish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publish version'),
    );
    expect(publish.onPressed, isNull);
    await tester.ensureVisible(find.text('Organise lesson plans'));
    await tester.tap(find.text('Organise lesson plans'));
    await tester.pumpAndSettle();
    expect(find.text('Lesson plans'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit lesson plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'publish readiness directs invalid lesson details to lesson editing',
    (tester) async {
      final framework = {
        'id': 'invalid-lesson-details-draft',
        'subject': 'Arabic',
        'level': 'Level 1',
        'version': '1.0',
        'description': 'Reading foundations',
        'status': 'DRAFT',
        'objectives': ['Read simple words'],
        'topics': [
          {
            'title': 'Reading',
            'position': 1,
            'objectives': [
              {
                'id': 'objective-current',
                'code': 'READ-01',
                'description': 'Read simple words clearly',
                'assessmentMethod': 'ORAL',
                'criteria': 'Read at least three words correctly',
              },
            ],
          },
        ],
        'lessons': [
          {
            'id': 'lesson-1',
            'title': 'x',
            'position': 1,
            'durationMinutes': 20,
            'activities': 'Read and repeat the target words.',
            'objectives': [
              {
                'objectiveId': 'objective-current',
                'objective': {'id': 'objective-current', 'code': 'READ-01'},
              },
            ],
          },
        ],
        '_count': {'assignments': 0},
        'assignments': [],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'superadmin',
              onSessionExpired: () {},
              call: (_, {body}) async => {
                'items': [framework],
                'total': 1,
                'madrasaCount': 1,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Give each lesson a title between 2 and 150 characters.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Organise lesson plans'));
      await tester.tap(find.text('Organise lesson plans'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit lesson plan'));
      await tester.tap(find.text('Edit lesson plan'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Edit lesson plan'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final conflict in [
    (
      'Another topic already uses this position',
      'That order number was just taken',
    ),
    (
      'Remove this objective from lesson plans before changing its code or removing it',
      'This objective is used in a lesson plan',
    ),
  ]) {
    testWidgets('topic conflict gives actionable guidance: ${conflict.$1}', (
      tester,
    ) async {
      final framework = <String, dynamic>{
        'id': 'position-conflict-draft',
        'subject': 'Arabic',
        'level': 'Level 1',
        'version': '1.0',
        'description': 'Arabic foundations',
        'status': 'DRAFT',
        'updatedAt': '2026-10-20T10:00:00.000Z',
        'objectives': ['Read independently'],
        'topics': [
          {
            'id': 'topic-1',
            'title': 'Letters',
            'position': 1,
            'objectives': [
              {
                'id': 'objective-1',
                'code': 'AR-01',
                'description': 'Read the target Arabic letters',
                'assessmentMethod': 'ORAL',
                'criteria': 'Read at least four letters accurately',
              },
            ],
          },
        ],
        'lessons': [],
        '_count': {'assignments': 0},
        'assignments': [],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'superadmin',
              onSessionExpired: () {},
              call: (path, {body}) async {
                if (path.endsWith('/topics/topic-1')) {
                  throw ApiException(conflict.$1, 409);
                }
                return {
                  'items': [framework],
                  'total': 1,
                  'madrasaCount': 1,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Topics & Objectives').first);
      await tester.tap(find.text('Topics & Objectives').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit topic'));
      await tester.tap(find.text('Edit topic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save topic'));
      await tester.pumpAndSettle();
      expect(find.textContaining(conflict.$2), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('AR-01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('readiness actions open the matching framework forms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final framework = <String, dynamic>{
      'id': 'draft-framework',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': 'invalid',
      'description': 'Reading foundations',
      'status': 'DRAFT',
      'objectives': ['Read simple words'],
      'topics': [
        {
          'title': 'Reading',
          'objectives': [
            {
              'code': 'READ-01',
              'description': 'Read simple words clearly',
              'assessmentMethod': 'ORAL',
              'criteria': 'Read at least three words correctly',
            },
          ],
        },
      ],
      'lessons': [],
      'reviews': [],
      '_count': {'assignments': 0},
      'assignments': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'superadmin',
            onSessionExpired: () {},
            call: (_, {body}) async => {
              'items': [framework],
              'total': 1,
              'madrasaCount': 1,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    expect(find.textContaining('version such as 1.0'), findsOneWidget);
    await tester.ensureVisible(find.text('Create corrected framework'));
    await tester.tap(find.text('Create corrected framework'));
    await tester.pumpAndSettle();
    expect(find.text('New framework').first, findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    framework['version'] = '1.0';
    framework['description'] = ' ';
    await tester.tap(find.text('Back to subject library'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    expect(find.textContaining('framework description'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit framework details'));
    await tester.tap(find.text('Edit framework details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit draft').first, findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('library search queries the server across pages', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'admin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              requests.add(path);
              return {'items': [], 'total': 0, 'madrasaCount': 0};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Arabic Level 2');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Search curriculum'));
    await tester.pumpAndSettle();
    expect(requests.last, '/curriculum?page=1&q=Arabic+Level+2');
    expect(find.text('No frameworks match "Arabic Level 2".'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'a late earlier library response cannot overwrite new search results',
    (tester) async {
      final initial = Completer<Map<String, dynamic>>();
      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'admin',
              onSessionExpired: () {},
              call: (path, {body}) {
                callCount++;
                if (callCount == 1) return initial.future;
                return Future.value({
                  'items': [
                    {
                      'id': 'new-result',
                      'subject': 'Arabic',
                      'level': 'Level 1',
                      'version': '1.0',
                      'description': 'Search result',
                      'status': 'DRAFT',
                      'objectives': ['Read independently'],
                      '_count': {'assignments': 0},
                      'assignments': <Map<String, dynamic>>[],
                      'topics': <Map<String, dynamic>>[],
                      'lessons': <Map<String, dynamic>>[],
                      'reviews': <Map<String, dynamic>>[],
                    },
                  ],
                  'total': 1,
                  'madrasaCount': 1,
                });
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Arabic');
      await tester.tap(find.byTooltip('Search curriculum'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Search result'), findsOneWidget);

      initial.complete({'items': [], 'total': 0, 'madrasaCount': 0});
      await tester.pumpAndSettle();
      expect(find.text('Search result'), findsOneWidget);
      expect(find.text('No frameworks match "Arabic".'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'opening a search result loads detail by id, independent of query',
    (tester) async {
      final requests = <String>[];
      final row = <String, dynamic>{
        'id': 'version-1',
        'subject': 'Arabic',
        'level': 'Level 1',
        'version': '1.0',
        'description': 'Arabic foundations',
        'status': 'DRAFT',
        'objectives': ['Read independently'],
        'createdBy': 'admin',
        '_count': {'assignments': 0},
        'assignments': <Map<String, dynamic>>[],
        'topics': <Map<String, dynamic>>[],
        'lessons': <Map<String, dynamic>>[],
        'reviews': <Map<String, dynamic>>[],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformCurriculumPage(
              accountId: 'admin',
              onSessionExpired: () {},
              call: (path, {body}) async {
                requests.add(path);
                return {
                  'items': [row],
                  'total': 1,
                  'madrasaCount': 1,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Arabic');
      await tester.tap(find.byTooltip('Search curriculum'));
      await tester.pumpAndSettle();
      expect(requests.last, '/curriculum?page=1&q=Arabic');
      await tester.ensureVisible(find.text('Open framework'));
      await tester.tap(find.text('Open framework'));
      await tester.pumpAndSettle();
      expect(requests.last, '/curriculum?page=1&id=version-1');
      expect(find.text('Arabic foundations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('published framework assigns to selected madrasas as one batch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final row = {
      'id': 'published-v1',
      'subject': 'Fiqh',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Foundations of worship',
      'status': 'PUBLISHED',
      'objectives': ['Explain daily practices'],
      '_count': {'assignments': 1},
      'assignments': <Map<String, dynamic>>[
        {
          'organizationId': '3',
          'organization': {'name': 'Amina', 'code': 'A03'},
          '_count': {'adoptions': 2},
        },
      ],
      'topics': <Map<String, dynamic>>[],
      'lessons': <Map<String, dynamic>>[],
      'reviews': <Map<String, dynamic>>[],
    };
    Map<String, dynamic>? assignmentBody;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'admin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (path == '/madrasas?status=ACTIVE&export=true') {
                return {
                  'items': [
                    {'id': '1', 'name': 'Noor', 'code': 'N01'},
                    {'id': '2', 'name': 'Huda', 'code': 'H02'},
                    {'id': '3', 'name': 'Amina', 'code': 'A03'},
                  ],
                };
              }
              if (path.contains('/assignment-preview?')) {
                return {
                  'framework': {
                    'subject': 'Fiqh',
                    'level': 'Level 1',
                    'version': '1.0',
                  },
                  'madrasa': {
                    'id': '1',
                    'name': 'Noor',
                    'code': 'N01',
                    'classCount': 3,
                    'branches': [
                      {'name': 'Main', 'location': 'Dar es Salaam'},
                    ],
                    'classLevels': [
                      {
                        'level': 'Level 1',
                        'academicYear': '2026',
                        'classCount': 2,
                      },
                    ],
                    'activeSubjects': [
                      {
                        'id': '7',
                        'name': 'Fiqh',
                        'code': 'FIQH',
                        'nameMatchesFramework': true,
                      },
                    ],
                  },
                  'existingAssignment': null,
                  'note': 'Name matches are suggestions only.',
                };
              }
              if (body != null) {
                if (path.endsWith('/assign')) assignmentBody = body;
                return {'id': 'published-v1'};
              }
              return {
                'items': [row],
                'total': 1,
                'madrasaCount': 2,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Assignments').first);
    await tester.tap(find.text('Assignments').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2 recorded class adoption(s) at active madrasas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('These are adoption records, not proof'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Assign to madrasa'));
    await tester.tap(find.text('Assign to madrasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview madrasa').first);
    await tester.pumpAndSettle();
    expect(find.text('Noor · N01'), findsOneWidget);
    expect(find.text('Classes: 3 · Active subjects: 1'), findsOneWidget);
    expect(find.textContaining('name match suggestion only'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No active madrasas match this search.'), findsOneWidget);
    expect(find.text('Select all matching (0)'), findsOneWidget);
    final selectAllZero = find.ancestor(
      of: find.text('Select all matching (0)'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(selectAllZero).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Noor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all matching (1)'));
    await tester.enterText(find.byType(TextField).last, 'Huda');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign to 2'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm madrasa assignment'), findsOneWidget);
    expect(
      find.text(
        'N01 · 3 classes · 1 active subject · 1 subject name suggestion',
      ),
      findsOneWidget,
    );
    expect(find.text('H02 · Preview not opened'), findsOneWidget);
    expect(assignmentBody, isNull);
    expect(find.textContaining('does not adopt it in a class'), findsOneWidget);
    await tester.tap(find.text('Assign to 2').last);
    await tester.pumpAndSettle();
    expect(assignmentBody, {
      'organizationIds': ['1', '2'],
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets('draft lesson removal requires confirmation and reloads content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const objective = {
      'id': 'objective-1',
      'code': 'AR-1',
      'description': 'Read the target Arabic letters',
      'assessmentMethod': 'ORAL',
      'criteria': 'Read at least four letters accurately',
    };
    final row = <String, dynamic>{
      'id': 'version-1',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Arabic foundations',
      'status': 'DRAFT',
      'updatedAt': '2026-10-19T10:00:00.000Z',
      'objectives': ['Read independently'],
      'createdBy': 'admin',
      '_count': {'assignments': 0},
      'assignments': <Map<String, dynamic>>[],
      'topics': [
        {
          'id': 'topic-1',
          'title': 'Letters',
          'position': 1,
          'objectives': [objective],
        },
      ],
      'lessons': [
        {
          'id': 'lesson-1',
          'title': 'Letter practice',
          'position': 1,
          'durationMinutes': 20,
          'activities': 'Practise reading letters with a partner.',
          'objectives': [
            {'objectiveId': 'objective-1'},
          ],
        },
      ],
      'reviews': <Map<String, dynamic>>[],
    };
    final writtenPaths = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'admin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (body != null) {
                writtenPaths.add(path);
                row['lessons'] = <Map<String, dynamic>>[];
                return {'id': 'version-1'};
              }
              return {
                'items': [row],
                'total': 1,
                'madrasaCount': 1,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lesson Plans').first);
    await tester.tap(find.text('Lesson Plans').first);
    await tester.pumpAndSettle();
    expect(find.text('Letter practice · 20 min'), findsOneWidget);
    await tester.ensureVisible(find.text('Remove').first);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove Letter practice?'), findsOneWidget);
    expect(writtenPaths, isEmpty);
    await tester.tap(find.text('Remove from draft'));
    await tester.pumpAndSettle();
    expect(writtenPaths, ['/curriculum/version-1/lessons/lesson-1/delete']);
    expect(
      find.text(
        'No lesson plans yet. Add objectives, then plan how they will be taught.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('linked topic deletion routes to its lesson plans first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const objective = {
      'id': 'objective-1',
      'code': 'AR-1',
      'description': 'Read the target Arabic letters',
      'assessmentMethod': 'ORAL',
      'criteria': 'Read at least four letters accurately',
    };
    final row = <String, dynamic>{
      'id': 'version-1',
      'subject': 'Arabic',
      'level': 'Level 1',
      'version': '1.0',
      'description': 'Arabic foundations',
      'status': 'DRAFT',
      'updatedAt': '2026-10-19T10:00:00.000Z',
      'objectives': ['Read independently'],
      'createdBy': 'admin',
      '_count': {'assignments': 0},
      'assignments': <Map<String, dynamic>>[],
      'topics': [
        {
          'id': 'topic-1',
          'title': 'Letters',
          'position': 1,
          'objectives': [objective],
        },
      ],
      'lessons': [
        {
          'id': 'lesson-1',
          'title': 'Letter practice',
          'position': 1,
          'durationMinutes': 20,
          'activities': 'Practise reading letters with a partner.',
          'objectives': [
            {'objective': objective},
          ],
        },
      ],
      'reviews': <Map<String, dynamic>>[],
    };
    final writes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'admin',
            onSessionExpired: () {},
            call: (path, {body}) async {
              if (body != null) {
                writes.add(path);
                if (path.endsWith('/lessons/lesson-1/delete')) {
                  row['lessons'] = <Map<String, dynamic>>[];
                }
                if (path.endsWith('/topics/topic-1/delete')) {
                  row['topics'] = <Map<String, dynamic>>[];
                }
              }
              return {
                'items': [row],
                'total': 1,
                'madrasaCount': 1,
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open framework'));
    await tester.tap(find.text('Open framework'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Topics & Objectives').first);
    await tester.tap(find.text('Topics & Objectives').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove').last);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('"Letters" is used in lesson plans'), findsOneWidget);
    expect(find.text('Letter practice'), findsOneWidget);
    expect(writes, isEmpty);
    await tester.tap(find.text('Review lesson plans'));
    await tester.pumpAndSettle();
    expect(find.text('Letter practice · 20 min'), findsOneWidget);
    expect(writes, isEmpty);
    await tester.ensureVisible(find.text('Remove').first);
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from draft'));
    await tester.pumpAndSettle();
    expect(writes, ['/curriculum/version-1/lessons/lesson-1/delete']);

    await tester.ensureVisible(find.text('Topics & Objectives').first);
    await tester.tap(find.text('Topics & Objectives').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove').last);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Remove Letters?'), findsOneWidget);
    await tester.tap(find.text('Remove from draft'));
    await tester.pumpAndSettle();
    expect(writes, [
      '/curriculum/version-1/lessons/lesson-1/delete',
      '/curriculum/version-1/topics/topic-1/delete',
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed curriculum shows retry, not fake frameworks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformCurriculumPage(
            accountId: 'author',
            onSessionExpired: () {},
            call: (_, {body}) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Quran'), findsNothing);
  });
}
