import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/family_accounts_page.dart';
import 'package:mif_app/src/workspace.dart';

Map<String, dynamic> account({
  String? number,
  bool linked = true,
  String status = 'ACTIVE',
}) => {
  'id': '12',
  'role': 'PARENT',
  'fullName': 'Amina Hassan',
  'email': 'amina@example.test',
  'status': status,
  'familyLoginId': number,
  'guardianProfile': linked
      ? <String, dynamic>{'id': '4', 'fullName': 'Amina Hassan'}
      : null,
};

Future<void> show(
  WidgetTester tester, {
  double width = 1000,
  Map<String, dynamic>? row,
  Future<dynamic> Function()? loadAccounts,
  void Function(String)? onLoad,
  Future<dynamic> Function(String, Map<String, dynamic>)? submit,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FamilyAccountsPage(
              key: UniqueKey(),
              load: (path) async {
                onLoad?.call(path);
                if (path.startsWith('/api/users/family-guardians?')) {
                  return {
                    'items': [
                      {
                        'id': '4',
                        'contactLabel': 'Amina Hassan - 255700000100',
                        'childrenSummary':
                            'Linked children (up to 3): Ahmad Hassan (DSM/26/001), Ayesha Hassan (DSM/26/002)',
                      },
                    ],
                    'meta': {'page': 1, 'totalPages': 1, 'totalItems': 1},
                  };
                }
                expect(path, '/api/users?role=PARENT');
                if (loadAccounts != null) return loadAccounts();
                return [row ?? account()];
              },
              submit:
                  submit ?? (_, _) async => {'familyLoginId': 'DSM/FAM/26/001'},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> createParent(WidgetTester tester) async {
  await tester.tap(find.text('Create parent account'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextFormField, 'Guardian'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Ahmad Hassan (DSM/26/001)'), findsOneWidget);
  await tester.tap(find.text('Amina Hassan - 255700000100'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Account holder name'),
    'Amina Hassan',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'amina@example.test',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Initial password'),
    'Temporary123!',
  );
  await tester.tap(find.text('Create account'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('guardian search and clear work without Enter at $width', (
      tester,
    ) async {
      final paths = <String>[];
      await show(tester, width: width, onLoad: paths.add);
      await tester.tap(find.text('Create parent account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextFormField, 'Guardian'));
      await tester.pumpAndSettle();
      final searchField = find
          .descendant(
            of: find.byType(AlertDialog).last,
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(searchField, '  DSM/26/001  ');
      await tester.tap(find.text('Search records'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.last).queryParameters['search'], 'DSM/26/001');
      expect(Uri.parse(paths.last).queryParameters['page'], '1');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(Uri.parse(paths.last).queryParameters['search'], '');
      expect(tester.widget<TextField>(searchField).controller!.text, '');
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 1440.0]) {
    testWidgets('family handover instructions copy safely at $width', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(
        tester,
        width: width,
        row: account(number: 'DSM/FAM/26/001'),
      );
      await tester.ensureVisible(find.text('Sign-in instructions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign-in instructions'));
      await tester.pumpAndSettle();
      expect(find.text('Family sign-in instructions'), findsOneWidget);
      await tester.tap(find.text('Copy instructions'));
      await tester.pumpAndSettle();
      expect(copied, contains('DSM/FAM/26/001'));
      expect(copied, contains('select a child'));
      expect(copied, contains('The family number is not your password'));
      expect(copied, isNot(contains('amina@example.test')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Family sign-in instructions'), findsNothing);
    });
  }

  testWidgets('disabled families do not offer sign-in instructions', (
    tester,
  ) async {
    await show(
      tester,
      row: account(number: 'DSM/FAM/26/001', status: 'DISABLED'),
    );
    expect(find.text('Sign-in instructions'), findsNothing);
  });

  testWidgets(
    'stage filters distinguish unlinked, pending, issued and disabled families',
    (tester) async {
      final rows = [
        {...account(linked: false), 'id': '1', 'fullName': 'Unlinked Family'},
        {...account(), 'id': '2', 'fullName': 'Pending Family'},
        {
          ...account(number: 'DSM/FAM/26/010'),
          'id': '3',
          'fullName': 'Issued Family',
        },
        {
          ...account(number: 'DSM/FAM/26/011', status: 'DISABLED'),
          'id': '4',
          'fullName': 'Disabled Family',
        },
      ];
      await show(tester, loadAccounts: () async => rows);
      expect(find.text('All (4)'), findsOneWidget);
      for (final entry in {
        'Needs guardian': 'Unlinked Family',
        'Awaiting number': 'Pending Family',
        'Number issued': 'Issued Family',
        'Disabled': 'Disabled Family',
      }.entries) {
        await tester.tap(find.text('${entry.key} (1)'));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        for (final row in rows.where((row) => row['fullName'] != entry.value)) {
          expect(find.text(row['fullName'] as String), findsNothing);
        }
      }
    },
  );
  testWidgets('family search matches a linked child admission number', (
    tester,
  ) async {
    final row = account();
    row['guardianProfile']['children'] = [
      {'id': '7', 'fullName': 'Yusuf', 'admissionNo': 'CHILD-777'},
    ];
    await show(tester, row: row);
    await tester.enterText(find.byType(TextField), 'child-777');
    await tester.pump();
    expect(find.text('Amina Hassan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not-linked');
    await tester.pump();
    expect(find.text('Amina Hassan'), findsNothing);
  });
  testWidgets(
    'issuance updates stage counts and confirms completion when a filtered row disappears',
    (tester) async {
      await show(tester);
      await tester.tap(find.text('Awaiting number (1)'));
      await tester.pump();
      await tester.ensureVisible(find.text('Issue family number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue family number'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'DSM');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Confirm and issue'));
      await tester.pumpAndSettle();
      expect(find.text('Awaiting number (0)'), findsOneWidget);
      expect(find.text('Number issued (1)'), findsOneWidget);
      expect(
        find.textContaining('Family number issued: DSM/FAM/26/001'),
        findsOneWidget,
      );
      await tester.tap(find.text('Show issued'));
      await tester.pumpAndSettle();
      expect(find.text('DSM/FAM/26/001'), findsOneWidget);
    },
  );
  testWidgets('creation continues to issuance using freshly loaded children', (
    tester,
  ) async {
    var reads = 0;
    final paths = <String>[];
    await show(
      tester,
      loadAccounts: () async {
        reads++;
        final row = account();
        row['guardianProfile']['children'] = [
          {'id': '8', 'fullName': 'Fresh child', 'admissionNo': 'CH-008'},
        ];
        return [row];
      },
      submit: (path, body) async {
        paths.add(path);
        return path == '/api/users'
            ? {'id': '12'}
            : {'familyLoginId': 'DSM/FAM/26/002'};
      },
    );
    await createParent(tester);
    expect(reads, 2);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Fresh child - CH-008'),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'DSM');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm and issue'));
    await tester.pumpAndSettle();
    expect(paths, ['/api/users', '/api/users/12/family-registration']);
    expect(find.text('DSM/FAM/26/002'), findsOneWidget);
  });

  testWidgets(
    'refresh failure after creation does not resubmit account creation',
    (tester) async {
      var reads = 0, writes = 0;
      await show(
        tester,
        loadAccounts: () async {
          reads++;
          if (reads == 2) throw Exception('offline');
          return [account()];
        },
        submit: (_, _) async {
          writes++;
          return {'id': '12'};
        },
      );
      await createParent(tester);
      expect(find.textContaining('Account created, but'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(reads, 3);
      expect(find.text('Issue family number'), findsOneWidget);
    },
  );
  testWidgets('admin creates a parent account from a selected guardian', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await show(
      tester,
      submit: (path, body) async {
        expect(path, '/api/users');
        saved = body;
        return {'id': '12'};
      },
    );
    await tester.tap(find.text('Create parent account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextFormField, 'Guardian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amina Hassan - 255700000100'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account holder name'),
      'Amina Hassan',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'amina@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Initial password'),
      'Temporary123!',
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Initial password'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(saved, {
      'guardianId': '4',
      'fullName': 'Amina Hassan',
      'email': 'amina@example.test',
      'password': 'Temporary123!',
      'role': 'PARENT',
    });
    expect(
      find.widgetWithText(AlertDialog, 'Issue family number'),
      findsOneWidget,
    );
    expect(find.text('Temporary123!'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Issue family number'), findsOneWidget);
  });
  testWidgets('linked children appear on the card and before confirmation', (
    tester,
  ) async {
    final row = account();
    row['guardianProfile']['children'] = [
      {'id': '1', 'fullName': 'Ahmad', 'admissionNo': 'CHILD-001'},
      {'id': '2', 'fullName': 'Ayesha', 'admissionNo': 'CHILD-002'},
    ];
    await show(tester, row: row);
    expect(find.text('Ahmad - CHILD-001'), findsOneWidget);
    expect(find.text('Ayesha - CHILD-002'), findsOneWidget);
    await tester.tap(find.text('Issue family number'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ahmad - CHILD-001'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ayesha - CHILD-002'),
      ),
      findsOneWidget,
    );
  });
  test('only school admin navigation includes family accounts', () {
    expect(
      sectionsForRole('ADMIN').any((s) => s.title == 'Family accounts'),
      isTrue,
    );
    for (final role in ['PARENT', 'TEACHER', 'LEARNER', 'ACCOUNTANT']) {
      expect(
        sectionsForRole(role).any((s) => s.title == 'Family accounts'),
        isFalse,
      );
    }
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('family cards and issue dialog fit width $width', (
      tester,
    ) async {
      await show(tester, width: width);
      await tester.ensureVisible(find.text('Issue family number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue family number'));
      await tester.pumpAndSettle();
      expect(find.text('Region code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('issued number is displayed without reissuing', (tester) async {
    await show(tester, row: account(number: 'DSM/FAM/26/001'));
    expect(find.text('DSM/FAM/26/001'), findsOneWidget);
    expect(find.text('Copy number'), findsOneWidget);
    expect(find.text('Issue family number'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no match');
    await tester.pump();
    expect(find.text('DSM/FAM/26/001'), findsNothing);
  });
  testWidgets('unlinked and disabled accounts cannot issue', (tester) async {
    await show(tester, row: account(linked: false));
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
    await show(tester, row: account(status: 'DISABLED'));
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'validates region, confirms guardian and prevents duplicate submission',
    (tester) async {
      final pending = Completer<dynamic>();
      var calls = 0;
      await show(
        tester,
        submit: (path, body) {
          calls++;
          expect(path, '/api/users/12/family-registration');
          expect(body, {'regionCode': 'DSM'});
          return pending.future;
        },
      );
      await tester.tap(find.text('Issue family number'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Confirm and issue'));
      await tester.pump();
      expect(find.text('Enter 2 to 8 letters.'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(find.byType(TextFormField), 'dsm');
      await tester.tap(find.text('Confirm and issue'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Issuing...'),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete({'familyLoginId': 'DSM/FAM/26/001'});
      await tester.pumpAndSettle();
      expect(find.text('DSM/FAM/26/001'), findsOneWidget);
      expect(find.text('Issue family number'), findsNothing);
    },
  );
  testWidgets('failed request keeps dialog and inputs for a safe retry', (
    tester,
  ) async {
    await show(
      tester,
      submit: (_, _) async => throw Exception('private server detail'),
    );
    await tester.tap(find.text('Issue family number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'DSM');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm and issue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Retrying will not create'), findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
    expect(find.text('DSM'), findsOneWidget);
  });
}
