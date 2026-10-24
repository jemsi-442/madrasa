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
    {'id': 1, 'name_simple': 'Al-Fatihah', 'verses_count': 7},
    {'id': 2, 'name_simple': 'Al-Baqarah'},
    {'id': 3, 'name_simple': 'Ali Imran'},
  ],
};
final verses = {
  'chapterId': 1,
  'verses': [
    {'verse_key': '1:1', 'verse_number': 1, 'text_uthmani': ayah},
  ],
  'pagination': {'current_page': 1, 'next_page': null, 'total_pages': 1},
};

Future<void> openReader(
  WidgetTester tester,
  PageLoader load, {
  int? initialChapterId,
  int? ayahFrom,
  int? ayahTo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showQuranReader(
              context,
              load,
              initialChapterId: initialChapterId,
              ayahFrom: ayahFrom,
              ayahTo: ayahTo,
            ),
            child: const Text('Read'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Read'));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find
        .descendant(
          of: find.byType(QuranReader),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'tracker passage opens and marks its provider verse without writes',
    (tester) async {
      final paths = <String>[];
      await openReader(
        tester,
        (path) async {
          paths.add(path);
          return path.contains('/verses?') ? verses : chapters;
        },
        initialChapterId: 1,
        ayahFrom: 1,
        ayahTo: 1,
      );
      expect(paths.last, endsWith('/1/verses?page=1&per_page=10'));
      await reveal(tester, 'Selected in tracker');
      expect(find.text('Selected in tracker'), findsOneWidget);
      expect(find.text(ayah), findsOneWidget);
    },
  );

  testWidgets('unavailable tracker surah never silently opens another chapter', (
    tester,
  ) async {
    final paths = <String>[];
    await openReader(
      tester,
      (path) async {
        paths.add(path);
        return chapters;
      },
      initialChapterId: 67,
      ayahFrom: 11,
      ayahTo: 15,
    );
    expect(paths, hasLength(1));
    await reveal(
      tester,
      'The tracker surah is unavailable in this environment. Choose another surah to read without changing your tracker.',
    );
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('invalid tracker range makes no verse request', (tester) async {
    final paths = <String>[];
    await openReader(
      tester,
      (path) async {
        paths.add(path);
        return chapters;
      },
      initialChapterId: 1,
      ayahFrom: 1,
      ayahTo: 8,
    );
    expect(paths, hasLength(1));
    await reveal(
      tester,
      'The tracker passage is outside the available surah. Check the selected ayahs in the tracker.',
    );
    expect(find.byType(SelectableText), findsNothing);
  });
  testWidgets(
    'surah search filters locally and cancellation preserves reading',
    (tester) async {
      final requests = <String>[];
      await openReader(tester, (path) async {
        requests.add(path);
        return path.contains('/verses?') ? verses : chapters;
      });
      await tester.tap(find.byTooltip('Search surahs'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'baqarah');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Al-Baqarah'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Al-Fatihah'), findsNothing);
      await tester.enterText(find.byType(TextField), '3');
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching surahs'), findsOneWidget);
      expect(requests, hasLength(2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(ayah), findsOneWidget);
      expect(requests, hasLength(2));
    },
  );

  testWidgets('numeric surah search opens the selected chapter at page one', (
    tester,
  ) async {
    final requests = <String>[];
    await openReader(tester, (path) async {
      requests.add(path);
      if (path.contains('/2/verses')) {
        throw const ApiException('Unavailable', 503);
      }
      return path.contains('/verses?') ? verses : chapters;
    });
    await tester.tap(find.byTooltip('Search surahs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 2 ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Al-Baqarah'));
    await tester.pumpAndSettle();
    expect(requests.last, endsWith('/2/verses?page=1&per_page=10'));
    expect(find.text(ayah), findsNothing);
    expect(find.text('Find a surah'), findsNothing);
  });

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
      await tester.tap(find.byTooltip('Search surahs'));
      await tester.pumpAndSettle();
      expect(find.text('Find a surah'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
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

  testWidgets(
    'changing surah clears old verses and retries the selected surah',
    (tester) async {
      final requests = <String>[];
      final pending = Completer<dynamic>();
      var secondAttempts = 0;
      await openReader(tester, (path) async {
        requests.add(path);
        if (path.contains('/2/verses')) {
          secondAttempts++;
          if (secondAttempts == 1) return pending.future;
          throw const ApiException('private', 503);
        }
        return path.contains('/verses?') ? verses : chapters;
      });
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Al-Baqarah').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(ayah), findsNothing);
      expect(find.text('Loading Quran content...'), findsOneWidget);
      pending.completeError(const ApiException('private', 503));
      await tester.pumpAndSettle();
      expect(find.text(ayah), findsNothing);
      await reveal(tester, 'Try again');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(secondAttempts, 2);
      expect(requests.last, endsWith('/2/verses?page=1&per_page=10'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed next page hides old content and allows returning', (
    tester,
  ) async {
    final requests = <String>[];
    await openReader(tester, (path) async {
      requests.add(path);
      if (!path.contains('/verses?')) return chapters;
      if (path.contains('page=2&')) throw const ApiException('private', 503);
      // Synthetic pagination only; Quran text remains the official 1:1 fixture.
      return {
        ...verses,
        'pagination': {'current_page': 1, 'next_page': 2, 'total_pages': 2},
      };
    });
    await reveal(tester, 'Next');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text(ayah), findsNothing);
    await reveal(tester, 'Try again');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(requests.last, endsWith('page=2&per_page=10'));
    await reveal(tester, 'Previous page');
    await tester.tap(find.text('Previous page'));
    await tester.pumpAndSettle();
    expect(requests.last, endsWith('page=1&per_page=10'));
    expect(find.text(ayah), findsOneWidget);
  });

  testWidgets('invalid pagination cannot show content or loop navigation', (
    tester,
  ) async {
    await openReader(tester, (path) async {
      if (!path.contains('/verses?')) return chapters;
      return {
        ...verses,
        'pagination': {'current_page': 1, 'next_page': 1, 'total_pages': 2},
      };
    });
    expect(find.text(ayah), findsNothing);
    expect(find.text('Next'), findsNothing);
    await reveal(tester, 'Try again');
    expect(find.text('Try again'), findsOneWidget);
  });

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
