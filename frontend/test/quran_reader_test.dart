import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/dashboard_components.dart';
import 'package:mif_app/src/quran_reader.dart';

// Official 1:1 example: Quran Foundation verses-by-chapter-number documentation.
const ayah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
final chapters = {
  'limitedContent': true,
  'chapters': [
    {'id': 1, 'name_simple': 'Al-Fatihah'},
    {'id': 2, 'name_simple': 'Al-Baqarah'},
    {'id': 3, 'name_simple': 'Ali Imran'},
  ],
};
final verses = {
  'chapterId': 1,
  'verses': [
    {'verse_key': '1:1', 'text_uthmani': ayah},
  ],
  'pagination': {'current_page': 1, 'next_page': null, 'total_pages': 1},
};

Future<void> openReader(WidgetTester tester, PageLoader load) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showQuranReader(context, load),
            child: const Text('Read'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Read'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('reader renders at width $width with selectable RTL text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <String>[];
      await openReader(tester, (path) async {
        requests.add(path);
        return path.contains('/verses?') ? verses : chapters;
      });
      expect(find.textContaining('only Al-Fatihah'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(SelectableText),
        150,
        scrollable: find
            .descendant(
              of: find.byType(QuranReader),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, ayah);
      expect(text.textDirection, TextDirection.rtl);
      expect(requests.last, endsWith('/1/verses?page=1&per_page=10'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('3. Ali Imran'), findsNothing);
      expect(find.text('2. Al-Baqarah'), findsOneWidget);
    });
  }

  testWidgets('unavailable provider is safe and retry recovers', (
    tester,
  ) async {
    var unavailable = true;
    await openReader(tester, (path) async {
      if (unavailable) throw const ApiException('private provider detail', 503);
      return path.contains('/verses?') ? verses : chapters;
    });
    expect(find.textContaining('No replacement text'), findsOneWidget);
    expect(find.textContaining('private provider detail'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    unavailable = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(ayah), findsOneWidget);
  });

  for (final status in [401, 403]) {
    testWidgets('access failure $status does not offer retry', (tester) async {
      await openReader(tester, (_) async {
        throw ApiException('private', status);
      });
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(
        find.textContaining(
          status == 401
              ? 'session has expired'
              : 'not available for this account',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('closing during pending request ignores late response', (
    tester,
  ) async {
    final pending = Completer<dynamic>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showQuranReader(context, (_) => pending.future),
              child: const Text('Read'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Read'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Close reader'));
    await tester.pump(const Duration(milliseconds: 400));
    pending.complete(chapters);
    await tester.pumpAndSettle();
    expect(find.text("Qur'an Reader"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
