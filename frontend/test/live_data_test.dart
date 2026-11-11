import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/live_data.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/api_client.dart';

void main() {
  testWidgets('missing scoped record clears old data and can be retried', (
    tester,
  ) async {
    var reads = 0;
    var available = true;
    Future<dynamic> fetch() => liveRead(() async {
      reads++;
      if (!available) throw const ApiException('Not found', 404);
      return 'Synthetic course activity $reads';
    });
    var future = fetch();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PageResult(
              future: future,
              onRetry: () => setState(() {
                future = fetch();
              }),
              builder: (value) => Text('$value'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 1'), findsOneWidget);
    available = false;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 1'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(reads, 2);
    available = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 4'), findsOneWidget);
  });

  testWidgets('temporary failure retains data and recovers automatically', (
    tester,
  ) async {
    var reads = 0;
    final future = liveRead(() async {
      reads++;
      if (reads == 2) throw const ApiException('Unavailable', 503);
      return 'Synthetic course activity $reads';
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageResult(
            future: future,
            onRetry: () {},
            builder: (value) => Text('$value'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 1'), findsOneWidget);
    expect(
      find.byTooltip(
        'Showing previous data. Updates will retry automatically.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic course activity 3'), findsOneWidget);
    expect(
      find.byTooltip(
        'Showing previous data. Updates will retry automatically.',
      ),
      findsNothing,
    );
  });

  testWidgets('permission loss clears read-only data and stops polling', (
    tester,
  ) async {
    var reads = 0;
    final future = liveRead(() async {
      reads++;
      if (reads > 1) throw const ApiException('Denied', 403);
      return 'Synthetic restricted data';
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageResult(
            future: future,
            onRetry: () {},
            builder: (data) => Text('$data'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic restricted data'), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    expect(reads, 2);
  });
  testWidgets(
    'shared results update on writes and intervals without a loading reset',
    (tester) async {
      var reads = 0;
      final future = liveRead(() async => ++reads);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageResult(
              future: future,
              onRetry: () {},
              builder: (value) => Text('Value $value'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Value 1'), findsOneWidget);
      await dataWrite(() async => null);
      await tester.pumpAndSettle();
      expect(find.text('Value 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Value 3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('inline form text survives blur, timers and writes elsewhere', (
    tester,
  ) async {
    var reads = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final future = liveRead(() async => ++reads);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageResult(
            future: future,
            onRetry: () {},
            builder: (_) => Form(child: TextFormField(controller: controller)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Unsaved synthetic text',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await dataWrite(() async => null);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(controller.text, 'Unsaved synthetic text');
  });

  testWidgets('does not apply an in-flight read after an editor opens', (
    tester,
  ) async {
    var reads = 0, editing = false;
    final response = Completer<dynamic>();
    final future = liveRead(() {
      reads++;
      return reads == 1 ? Future.value('original') : response.future;
    });
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PageResult(
                future: future,
                onRetry: () {},
                builder: (data) => Column(
                  children: [Text('$data'), if (editing) const TextField()],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    update(() => editing = true);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    response.complete('new server value');
    await tester.pumpAndSettle();
    expect(find.text('original'), findsOneWidget);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.text('new server value'), findsNothing);
  });

  testWidgets('dialogs pause background reads until closed', (tester) async {
    var reads = 0;
    final future = liveRead(() async => ++reads);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Scaffold(
              body: PageResult(
                future: future,
                onRetry: () {},
                builder: (data) => Text('$data'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: TextField()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dialog draft');
    await tester.pump(const Duration(seconds: 31));
    expect(reads, 1);
    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(reads, 2);
  });
}
