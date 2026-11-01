import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mif_app/src/donor_messaging_workspace.dart';

const recipient = {
  'donorId': '1',
  'donorName': 'Synthetic donor',
  'madrasaName': 'Synthetic madrasa',
  'phone': '255700000000',
  'status': 'PENDING',
};
Map<String, dynamic> draft() => {
  'id': 'message-1',
  'revision': 1,
  'body': 'Synthetic message',
  'senderName': 'Synthetic sender',
  'updatedAt': '2026-10-31T12:00:00Z',
  'recipients': [recipient],
};
void main() {
  testWidgets(
    'history explains failed sends and shows the provider reference',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DonorMessagingWorkspace(
                onSessionExpired: () {},
                load: (path) async => {
                  'ready': true,
                  'hasMore': false,
                  'items': path.contains('/recipients?')
                      ? []
                      : [
                          {
                            ...draft(),
                            'recipients': [
                              {
                                ...recipient,
                                'status': 'FAILED',
                                'reason': 'HTTP_402',
                                'batchId': 'msg_synthetic',
                              },
                            ],
                          },
                        ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Donor messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sent messages'));
      await tester.pumpAndSettle();
      expect(find.text('Sending failed'), findsOneWidget);
      expect(
        find.textContaining('Top up the provider account'),
        findsOneWidget,
      );
      expect(find.text('Provider reference: msg_synthetic'), findsOneWidget);
      expect(find.textContaining('HTTP_402'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compose saves, reviews exact recipients, then queues once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final posts = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DonorMessagingWorkspace(
              onSessionExpired: () {},
              load: (path) async => path.contains('/recipients?')
                  ? {
                      'hasMore': false,
                      'items': [
                        {
                          'id': '1',
                          'name': 'Synthetic donor',
                          'phone': '255700000000',
                          'madrasa': 'Synthetic madrasa',
                          'consent': true,
                        },
                      ],
                    }
                  : {
                      'ready': true,
                      'hasMore': false,
                      'items': path.contains('tab=sent') ? [draft()] : [],
                    },
              post: (path, body) async {
                posts.add(path);
                if (path.endsWith('/drafts')) {
                  expect(body['body'], 'Synthetic message');
                  expect(body['donorIds'], ['1']);
                  return draft();
                }
                return {'queued': true};
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Donor messages'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Synthetic message');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SMS consent given'));
    await tester.tap(find.text('SMS consent given'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.ensureVisible(find.text('Review & send'));
    await tester.tap(find.text('Review & send'));
    await tester.pumpAndSettle();
    expect(posts, ['/funds/messaging/drafts']);
    expect(find.text('Review message'), findsOneWidget);
    expect(find.text('1 estimated credits'), findsWidgets);
    expect(find.text('1 SMS parts per recipient'), findsWidgets);
    expect(find.textContaining('255700000000'), findsWidgets);
    await tester.tap(find.text('Confirm send'));
    await tester.pumpAndSettle();
    expect(posts, [
      '/funds/messaging/drafts',
      '/funds/messaging/message-1/send',
    ]);
    expect(find.text('Your sent and queued messages'), findsOneWidget);
    expect(find.text('Synthetic message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone layout disables recipients without consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DonorMessagingWorkspace(
              onSessionExpired: () {},
              load: (path) async => path.contains('/recipients?')
                  ? {
                      'hasMore': false,
                      'items': [
                        {
                          'id': '1',
                          'name': 'Synthetic donor',
                          'phone': '255700000000',
                          'madrasa': 'Synthetic madrasa',
                          'consent': false,
                        },
                      ],
                    }
                  : {'ready': false, 'hasMore': false, 'items': []},
              post: (_, _) async => draft(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Donor messages'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
