/// Tests for the share sheet.
///
/// Sharing writes into another person's Firestore document, which is the only
/// place in the app where one user appends to another's data, so what it
/// writes and who it writes to are worth pinning exactly.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/share.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser();
    user.settings['username'] = 'Tester';
  });

  /// Registers [uid] as a friend with a display name and no avatar, so the
  /// row renders from the bundled placeholder rather than reaching out for a
  /// profile photo.
  Future<void> addFriend(String uid, String username) async {
    user.friends = [...user.friends, uid];
    await seedUserDoc(firestore, uid, 'Settings', {
      'username': username,
      'profile_photo': '',
    });
  }

  Future<void> openShare(WidgetTester tester) async {
    ignoreInkSplashAdvisory();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            // A modal bottom sheet is how the media page opens this, and the
            // sheet is what supplies the Material the checkbox rows need.
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                builder: (_) => Share(
                  item: Movie(
                    id: '27205',
                    title: 'Inception',
                    coverPhoto: '/cover.jpg',
                  ),
                  type: 'Movies',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>?> notificationsOf(String uid) async {
    final doc = await firestore.collection(uid).doc('Notifications').get();
    return doc.data();
  }

  testWidgets('lists every friend by name', (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');

    await openShare(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('a user with no friends gets no list at all', (tester) async {
    await openShare(tester);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('sends the title only to the friends that were ticked',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {});
    await seedUserDoc(firestore, 'friend-b', 'Notifications', {});

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(await notificationsOf('friend-a'), hasLength(1));
    expect(await notificationsOf('friend-b'), isEmpty);
  });

  testWidgets('a friend ticked and then unticked is not sent anything',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {});

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(await notificationsOf('friend-a'), isEmpty);
  });

  testWidgets('the notification carries what the recipient needs to render it',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {});

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    final notification = (await notificationsOf('friend-a'))!['0'] as Map;
    expect(notification['type'], 'Movies');
    expect(notification['id'], '27205');
    expect(notification['title'], 'Inception');
    expect(notification['coverPhoto'], '/cover.jpg');
    expect(notification['sender'], {'username': 'Tester', 'uid': 'test-uid'});
    expect(notification['read'], isFalse,
        reason: 'the inbox badge counts unread ones');
  });

  testWidgets('an existing notification is kept, not overwritten',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {
      '0': {'type': 'Movies', 'id': '603', 'read': true},
    });

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    final notifications = (await notificationsOf('friend-a'))!;
    expect(notifications, hasLength(2));
    expect(notifications['0']['id'], '603');
    expect(notifications['1']['id'], '27205');
  });

  testWidgets('cancel sends nothing even after ticking someone',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {});

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await notificationsOf('friend-a'), isEmpty);
    expect(find.byType(Share), findsNothing);
  });

  testWidgets(
      'a friend with no inbox yet is skipped without taking the sheet down',
      (tester) async {
    // The document only appears once something has been written to it, so a
    // brand new friend has none. Nobody else being shared with should suffer
    // for that.
    await addFriend('missing-inbox', 'Nadia');
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'Notifications', {});

    await openShare(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Nadia'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await notificationsOf('missing-inbox'), isNull);
    expect(await notificationsOf('friend-a'), hasLength(1));
    expect(find.byType(Share), findsNothing);
  });
}
