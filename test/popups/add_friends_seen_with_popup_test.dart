/// Tests for the "who did you watch this with" popup.
///
/// Applying writes into three places at once: the friend's seen lists, the
/// friend's seen-with record and the user's own. All three have to agree, or
/// a film shows as watched together on one profile and alone on the other.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/add_friends_seen_with_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser();
  });

  /// Adds a friend with a name, an empty seen-with record and no avatar.
  Future<void> addFriend(String uid, String username) async {
    user.friends = [...user.friends, uid];
    await seedUserDoc(firestore, uid, 'Settings', {
      'username': username,
      'profile_photo': '',
    });
    await seedUserDoc(firestore, uid, 'SeenWith', {
      'Movies': <String, dynamic>{},
      'TVShows': <String, dynamic>{},
    });
  }

  Future<void> openPopup(WidgetTester tester) async {
    await seedUserDoc(firestore, 'test-uid', 'SeenWith', {
      'Movies': <String, dynamic>{},
      'TVShows': <String, dynamic>{},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AddFriendsPopUp(
                  movie: Movie(
                    id: '27205',
                    title: 'Inception',
                    coverPhoto: '/cover.jpg',
                  ),
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

  Future<void> tick(WidgetTester tester, String username) async {
    await tester.tap(find.widgetWithText(CheckboxListTile, username));
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>?> docOf(String uid, String name) async {
    final doc = await firestore.collection(uid).doc(name).get();
    return doc.data();
  }

  testWidgets('lists the friends who can be tagged', (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');

    await openPopup(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('marks the film as seen on the friend that was tagged',
      (tester) async {
    // Watching something together means they have seen it too, and the app
    // records that for them rather than making them log it again.
    await addFriend('friend-a', 'Ana');

    await openPopup(tester);
    await tick(tester, 'Ana');
    await apply(tester);

    expect((await docOf('friend-a', 'Movies'))!['Seen'], ['27205']);
    expect((await docOf('friend-a', 'Seen'))!['Movies'], ['27205']);
  });

  testWidgets('records the pairing on both sides', (tester) async {
    await addFriend('friend-a', 'Ana');

    await openPopup(tester);
    await tick(tester, 'Ana');
    await apply(tester);

    expect((await docOf('friend-a', 'SeenWith'))!['Movies'], {
      '27205': {
        'friends': ['test-uid']
      }
    });
    expect((await docOf('test-uid', 'SeenWith'))!['Movies'], {
      '27205': {
        'friends': ['friend-a']
      }
    });
  });

  testWidgets('the in-memory pairing is updated so the page can show it',
      (tester) async {
    await addFriend('friend-a', 'Ana');

    await openPopup(tester);
    await tick(tester, 'Ana');
    await apply(tester);

    expect(user.seenWith['friend-a']['Movies'], ['27205']);
  });

  testWidgets('someone already recorded against the film is not duplicated',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'SeenWith', {
      'Movies': {
        '27205': {
          'friends': ['test-uid']
        }
      },
      'TVShows': <String, dynamic>{},
    });

    await openPopup(tester);
    await tick(tester, 'Ana');
    await apply(tester);

    expect((await docOf('friend-a', 'SeenWith'))!['Movies']['27205']['friends'],
        ['test-uid']);
  });

  testWidgets('another film they watched together is left alone',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await seedUserDoc(firestore, 'friend-a', 'SeenWith', {
      'Movies': {
        '603': {
          'friends': ['test-uid']
        }
      },
      'TVShows': <String, dynamic>{},
    });

    await openPopup(tester);
    await tick(tester, 'Ana');
    await apply(tester);

    final movies = (await docOf('friend-a', 'SeenWith'))!['Movies'];
    expect(movies['603']['friends'], ['test-uid']);
    expect(movies['27205']['friends'], ['test-uid']);
  });

  testWidgets('cancelling records nothing', (tester) async {
    await addFriend('friend-a', 'Ana');

    await openPopup(tester);
    await tick(tester, 'Ana');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await docOf('friend-a', 'Movies'), isNull);
    expect((await docOf('friend-a', 'SeenWith'))!['Movies'], isEmpty);
    expect(find.byType(AddFriendsPopUp), findsNothing);
  });

  testWidgets('applying with nobody tagged marks no friend as having seen it',
      (tester) async {
    await addFriend('friend-a', 'Ana');

    await openPopup(tester);
    await apply(tester);

    expect(await docOf('friend-a', 'Movies'), isNull);
    expect((await docOf('friend-a', 'SeenWith'))!['Movies'], isEmpty);
    // The user's own record still gains the film with nobody against it,
    // which is harmless but is what happens, and is worth knowing if the
    // seen-with screen ever starts listing films instead of people.
    expect((await docOf('test-uid', 'SeenWith'))!['Movies'], {
      '27205': {'friends': []}
    });
    expect(find.byType(AddFriendsPopUp), findsNothing);
  });
}
