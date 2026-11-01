import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/platform_madrasas_page.dart';
import 'package:mif_app/src/live_data.dart';

Map<String, dynamic> directory(String name) => {
  'total': 1,
  'summary': {'total': 1, 'active': 1, 'onboarding': 0, 'assignedAdmins': 0},
  'locations': <String>[],
  'items': [
    {
      'id': '1',
      'name': name,
      'code': 'synthetic',
      'status': 'ACTIVE',
      'admins': [],
      'locations': [],
      'students': 0,
      'teachers': 0,
    },
  ],
};

void main() {
  testWidgets(
    'directory refreshes on timer and writes but protects unfinished search and profiles',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformMadrasasPage(
              onApplications: () {},
              onSessionExpired: () {},
              load: (_) async => directory('Synthetic madrasa ${++reads}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(reads, 2);
      await dataWrite(() async => null);
      await tester.pumpAndSettle();
      expect(reads, 3);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Unsaved search');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('Unsaved search'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.ensureVisible(find.text('Manage →'));
      await tester.tap(find.text('Manage →'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('Back to Madrasas'), findsOneWidget);
    },
  );

  testWidgets(
    'late poll cannot replace directory data behind a newly opened profile',
    (tester) async {
      var reads = 0;
      final pending = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformMadrasasPage(
              onApplications: () {},
              onSessionExpired: () {},
              load: (_) {
                reads++;
                return reads == 1
                    ? Future.value(directory('Original madrasa'))
                    : pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.ensureVisible(find.text('Manage →'));
      await tester.tap(find.text('Manage →'));
      await tester.pumpAndSettle();
      pending.complete(directory('Changed madrasa'));
      await tester.pumpAndSettle();
      expect(find.text('Original madrasa'), findsWidgets);
      expect(find.text('Changed madrasa'), findsNothing);
    },
  );

  testWidgets('temporary failure retains data and automatically recovers', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformMadrasasPage(
            onApplications: () {},
            onSessionExpired: () {},
            load: (_) async {
              reads++;
              if (reads == 2) throw Exception('offline');
              return directory('Synthetic madrasa $reads');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic madrasa 1'), findsOneWidget);
    expect(find.textContaining('Reconnecting automatically'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic madrasa 3'), findsOneWidget);
    expect(find.textContaining('Reconnecting automatically'), findsNothing);
  });
}
