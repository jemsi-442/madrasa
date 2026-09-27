import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/admin_theme.dart';
import 'package:mif_app/src/api_client.dart';
import 'package:mif_app/src/family_messages_page.dart';
import 'package:mif_app/src/workspace.dart';

const student = {
  'id': '4',
  'fullName': 'Amina Hassan',
  'admissionNo': 'MIF001',
  'currentClass': {'name': 'Level 1A'},
};
const contact = {'id': '9', 'fullName': 'Teacher Ahmad'};
const other = {'id': '10', 'fullName': 'Teacher Ayesha'};
const base = '/api/family-messages';

class MessageFixture {
  final loads = <String>[];
  final writes = <(String, Map<String, dynamic>)>[];
  bool failSend = false, failHistory = false, empty = false, failRead = false;
  Completer<dynamic>? sendWait;
  final messages = <Map<String, dynamic>>[
    {
      'id': '11',
      'senderId': '9',
      'body': 'Please revise Al-Mulk.',
      'createdAt': '2026-09-27T08:00:00Z',
    },
    {
      'id': '12',
      'senderId': '1',
      'body': 'Thank you, teacher.',
      'createdAt': '2026-09-27T08:05:00Z',
    },
  ];
  Future<dynamic> load(String path) async {
    loads.add(path);
    if (path.contains('/contacts?')) {
      return {
        'items': empty
            ? []
            : [
                {'student': student, 'contact': contact},
              ],
        'meta': {'totalPages': 1},
      };
    }
    if (path.contains('/conversations?')) {
      return {
        'items': empty
            ? []
            : [
                {
                  'id': '20',
                  'student': student,
                  'contact': contact,
                  'unread': 1,
                  'latestMessage': {'body': 'Learning update'},
                },
                {
                  'id': '21',
                  'student': {
                    ...student,
                    'id': '5',
                    'fullName': 'Yusuf Hassan',
                  },
                  'contact': other,
                  'unread': 0,
                },
              ],
        'meta': {'totalPages': 2},
      };
    }
    if (path.contains('/conversations/')) {
      if (failHistory) throw const ApiException('No longer available', 404);
      return {
        'id': path.contains('/21') ? '21' : '20',
        'student': student,
        'contact': path.contains('/21') ? other : contact,
        'readThrough': '0',
        'otherReadThrough': '12',
        'hasOlder': !path.contains('before='),
        'nextBefore': '11',
        'messages': path.contains('before=')
            ? [
                {
                  'id': '5',
                  'senderId': '9',
                  'body': 'An earlier conversation.',
                  'createdAt': '2026-09-01T08:00:00Z',
                },
              ]
            : messages,
      };
    }
    throw StateError('Unexpected load $path');
  }

  Future<dynamic> submit(String path, Map<String, dynamic> body) async {
    writes.add((path, Map.of(body)));
    if (path.endsWith('/read')) {
      if (failRead) throw const ApiException('Offline', 0);
      return {'readThrough': body['throughId']};
    }
    if (path.endsWith('/messages')) {
      if (failSend) {
        failSend = false;
        throw const ApiException('Response lost', 0);
      }
      if (sendWait != null) await sendWait!.future;
      final message = {
        'id': '13',
        'senderId': '1',
        'body': body['body'],
        'createdAt': '2026-09-27T08:10:00Z',
      };
      messages.add(message);
      return {'message': message};
    }
    if (path.endsWith('/conversations')) return {'id': '20'};
    throw StateError('Unexpected write $path');
  }
}

Widget host(
  MessageFixture fixture, {
  GlobalKey<FamilyMessagesPageState>? pageKey,
  bool teacher = false,
}) => MaterialApp(
  theme: adminTheme(ThemeData()),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FamilyMessagesPage(
          key: pageKey,
          load: fixture.load,
          submit: fixture.submit,
          userId: teacher ? '9' : '1',
          teacherMode: teacher,
        ),
      ),
    ),
  ),
);
void screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> openFirst(WidgetTester tester) async {
  await tester.tap(find.text('Teacher Ahmad').first);
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'private messaging belongs to parents and teachers, not other roles',
    () {
      for (final role in ['PARENT', 'TEACHER']) {
        expect(
          sectionsForRole(role).any((s) => s.path == '$base/conversations'),
          isTrue,
        );
      }
      for (final role in ['ADMIN', 'ACCOUNTANT', 'LEARNER']) {
        expect(
          sectionsForRole(role).any((s) => s.path == '$base/conversations'),
          isFalse,
        );
      }
    },
  );
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('inbox, conversation and contact picker fit at $width', (
      tester,
    ) async {
      screen(tester, width);
      await tester.pumpWidget(host(MessageFixture()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openFirst(tester);
      expect(find.text('Please revise Al-Mulk.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(tester, 'New message');
      expect(find.text('Search contacts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'failed send retains exact UUID and body; confirmed retry clears the draft',
    (tester) async {
      screen(tester, 1440);
      final fixture = MessageFixture()..failSend = true;
      await tester.pumpWidget(host(fixture));
      await tester.pumpAndSettle();
      await openFirst(tester);
      final composer = find.byKey(const ValueKey('message-composer'));
      await tester.enterText(composer, 'We will revise tonight.');
      await click(tester, 'Send');
      expect(find.textContaining('Delivery not confirmed.'), findsOneWidget);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'We will revise tonight.',
      );
      expect(tester.widget<TextField>(composer).readOnly, isTrue);
      await click(tester, 'Retry send');
      final sends = fixture.writes
          .where((w) => w.$1.endsWith('/messages'))
          .toList();
      expect(sends, hasLength(2));
      expect(sends[0].$2, sends[1].$2);
      expect(sends[0].$2['clientId'], matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      expect(find.text('We will revise tonight.'), findsOneWidget);
      expect(find.text('Retry send'), findsNothing);
    },
  );
  testWidgets(
    'read acknowledgement uses newest displayed ID, not an unbounded read-all',
    (tester) async {
      screen(tester, 1440);
      final fixture = MessageFixture();
      await tester.pumpWidget(host(fixture));
      await tester.pumpAndSettle();
      await openFirst(tester);
      final reads = fixture.writes
          .where((w) => w.$1.endsWith('/read'))
          .toList();
      expect(reads, hasLength(1));
      expect(reads.single.$2, {'throughId': '12'});
      expect(find.textContaining('| Read'), findsOneWidget);
      await click(tester, 'Older messages');
      expect(fixture.loads, contains('$base/conversations/20?before=11'));
      expect(find.text('An earlier conversation.'), findsOneWidget);
      await click(tester, 'Latest messages');
      expect(find.text('Please revise Al-Mulk.'), findsOneWidget);
    },
  );
  testWidgets(
    'changing conversations or leaving the page requires draft confirmation',
    (tester) async {
      screen(tester, 1440);
      final key = GlobalKey<FamilyMessagesPageState>();
      await tester.pumpWidget(host(MessageFixture(), pageKey: key));
      await tester.pumpAndSettle();
      await openFirst(tester);
      final composer = find.byKey(const ValueKey('message-composer'));
      await tester.enterText(composer, 'Unsent draft');
      await click(tester, 'Teacher Ayesha');
      expect(find.text('Leave this message?'), findsOneWidget);
      await click(tester, 'Keep draft');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Unsent draft',
      );
      final leave = key.currentState!.confirmLeave();
      await tester.pumpAndSettle();
      await click(tester, 'Discard draft');
      expect(await leave, isTrue);
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      await click(tester, 'Teacher Ayesha');
      expect(find.textContaining('Teacher for Amina Hassan'), findsOneWidget);
    },
  );
  testWidgets('new conversation uses verified contact and student IDs', (
    tester,
  ) async {
    screen(tester, 1440);
    final fixture = MessageFixture();
    await tester.pumpWidget(host(fixture));
    await tester.pumpAndSettle();
    await click(tester, 'New message');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Teacher Ahmad'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      fixture.writes.where((w) => w.$1.endsWith('/conversations')).single.$2,
      {'studentId': '4', 'contactId': '9'},
    );
    expect(find.text('Please revise Al-Mulk.'), findsOneWidget);
  });
  testWidgets(
    'permission failure hides composer and context instead of exposing old messages',
    (tester) async {
      screen(tester, 1440);
      final fixture = MessageFixture();
      await tester.pumpWidget(host(fixture));
      await tester.pumpAndSettle();
      await openFirst(tester);
      fixture.failHistory = true;
      await click(tester, 'Refresh messages');
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Please revise Al-Mulk.'), findsNothing);
      expect(find.byKey(const ValueKey('message-composer')), findsNothing);
      expect(find.text('Student context'), findsNothing);
    },
  );
  testWidgets(
    'empty contact directory offers office guidance without fake contacts',
    (tester) async {
      screen(tester, 768);
      final fixture = MessageFixture()..empty = true;
      await tester.pumpWidget(host(fixture));
      await tester.pumpAndSettle();
      expect(find.textContaining('No conversations found'), findsOneWidget);
      await click(tester, 'New message');
      expect(
        find.textContaining('No authorised contacts found'),
        findsOneWidget,
      );
      expect(find.text('Teacher Ahmad'), findsNothing);
    },
  );
  testWidgets('send in flight cannot be double clicked or abandoned', (
    tester,
  ) async {
    screen(tester, 1440);
    final fixture = MessageFixture()..sendWait = Completer();
    final key = GlobalKey<FamilyMessagesPageState>();
    await tester.pumpWidget(host(fixture, pageKey: key));
    await tester.pumpAndSettle();
    await openFirst(tester);
    await tester.enterText(
      find.byKey(const ValueKey('message-composer')),
      'One message',
    );
    await tester.ensureVisible(find.text('Send'));
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Sending...'), findsOneWidget);
    expect(await key.currentState!.confirmLeave(), isFalse);
    expect(
      fixture.writes.where((w) => w.$1.endsWith('/messages')),
      hasLength(1),
    );
    fixture.sendWait!.complete({});
    await tester.pumpAndSettle();
    expect(find.text('Send'), findsOneWidget);
  });
  testWidgets(
    'teacher mode uses the same private chat without admin controls',
    (tester) async {
      screen(tester, 1440);
      final fixture = MessageFixture()..failRead = true;
      await tester.pumpWidget(host(fixture, teacher: true));
      await tester.pumpAndSettle();
      await openFirst(tester);
      expect(find.textContaining('Only verified parents'), findsOneWidget);
      expect(find.textContaining('Read status was not saved'), findsOneWidget);
      expect(find.text('Delete conversation'), findsNothing);
    },
  );
}
