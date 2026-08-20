/// Tests for the grant-access dialogue.
///
/// The dialogue's job is to offer the friends who are *not* already on a
/// playlist and then write both halves of membership. Writing `Users` without
/// `memberUids` leaves someone who can see the list in the app but is refused
/// by the security rules, which is the failure this covers.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/objects/playlist.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/grant_access_dialogue.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  Playlist? dialogResult;
  bool dialogClosed = false;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser();
    dialogResult = null;
    dialogClosed = false;
  });

  Future<void> addFriend(String uid, String username) async {
    user.friends = [...user.friends, uid];
    await seedUserDoc(firestore, uid, 'Settings', {
      'username': username,
      'profile_photo': '',
    });
  }

  Playlist playlist({List? users}) => Playlist(
        id: 'list-1',
        name: 'Film club',
        movies: [],
        tvshows: [],
        backdrop: '',
        accesscode: 'code',
        users: users ??
            [
              {'test-uid': 'Owner'}
            ],
      );

  /// Opens the dialogue. What it returns when it closes lands in
  /// [dialogResult], which a test reads after tapping one of the buttons --
  /// awaiting the open call itself would deadlock against the taps.
  Future<void> openDialog(WidgetTester tester, Playlist list) async {
    ignoreInkSplashAdvisory();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showDialog<Playlist>(
                  context: context,
                  builder: (_) => GrantAccessDialog(listResult: list),
                );
                dialogClosed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>?> storedList() async {
    final doc = await firestore.collection('Watchlists').doc('list-1').get();
    return doc.data();
  }

  testWidgets('offers only the friends who are not on the list yet',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');

    await openDialog(
      tester,
      playlist(users: [
        {'test-uid': 'Owner'},
        {'friend-a': 'Approved'},
      ]),
    );

    expect(find.text('Ana'), findsNothing);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('says so when there is nobody left to invite', (tester) async {
    await addFriend('friend-a', 'Ana');

    await openDialog(
      tester,
      playlist(users: [
        {'test-uid': 'Owner'},
        {'friend-a': 'Approved'},
      ]),
    );

    expect(find.text('All your friends already have access to this list'),
        findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('a user with no friends is told the same thing', (tester) async {
    await openDialog(tester, playlist());

    expect(find.text('All your friends already have access to this list'),
        findsOneWidget);
  });

  testWidgets('accepting records the friend as approved and as a member',
      (tester) async {
    // memberUids is what the security rules read. A friend added to Users
    // alone can open the list in the app and then be refused by Firestore.
    await addFriend('friend-a', 'Ana');
    await firestore.collection('Watchlists').doc('list-1').set({
      'Name': 'Film club',
      'Users': [
        {'test-uid': 'Owner'}
      ],
      'memberUids': ['test-uid'],
    });

    await openDialog(tester, playlist());
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    final stored = (await storedList())!;
    expect(stored['Users'], [
      {'test-uid': 'Owner'},
      {'friend-a': 'Approved'},
    ]);
    expect(stored['memberUids'], ['test-uid', 'friend-a']);
  });

  testWidgets('the caller gets the list back with the new member on it',
      (tester) async {
    // The playlist screen renders from the object it passed in, so a returned
    // list that has not been updated shows the invite as having done nothing.
    await addFriend('friend-a', 'Ana');
    await firestore.collection('Watchlists').doc('list-1').set({
      'Users': [
        {'test-uid': 'Owner'}
      ],
      'memberUids': ['test-uid'],
    });

    final list = playlist();
    await openDialog(tester, list);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(dialogResult, same(list));
    expect(list.users, [
      {'test-uid': 'Owner'},
      {'friend-a': 'Approved'},
    ]);
  });

  testWidgets('cancelling invites nobody and returns nothing', (tester) async {
    await addFriend('friend-a', 'Ana');
    await firestore.collection('Watchlists').doc('list-1').set({
      'Users': [
        {'test-uid': 'Owner'}
      ],
      'memberUids': ['test-uid'],
    });

    final list = playlist();
    await openDialog(tester, list);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(dialogResult, isNull);
    expect((await storedList())!['memberUids'], ['test-uid']);
    expect(list.users, [
      {'test-uid': 'Owner'}
    ]);
  });

  testWidgets('a friend whose settings are missing shows as having no data',
      (tester) async {
    // Nothing guarantees a friend document exists, and the dialogue has to
    // stay usable for the friends that do rather than render a broken row.
    user.friends = ['ghost-uid'];

    await openDialog(tester, playlist());

    expect(find.text('No data found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
