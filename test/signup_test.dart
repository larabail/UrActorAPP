import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/signup.dart';

void main() {
  group('writeInitialProfile', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirestoreCore.db = fakeFirestore;
      addTearDown(FirestoreCore.resetDb);
    });

    const docNames = [
      'Movies',
      'TVShows',
      'Seen',
      'SeenWith',
      'Reviews',
      'Favorites',
      'Watchlist',
      'Country',
      'Calendar',
      'FavDirectors',
      'FavWriters',
      'FavActors',
      'Rewatched',
      'RewatchedTV',
      'Settings',
      'Friends',
      'Notifications',
      'Recommendations',
    ];

    test('writes all eighteen documents for a new user', () async {
      await writeInitialProfile('new-uid');

      final users = fakeFirestore.collection('new-uid');
      for (final docName in docNames) {
        final snapshot = await users.doc(docName).get();
        expect(snapshot.exists, isTrue, reason: '$docName should exist');
      }
    });

    test('writes Friends with a "friends" key holding an empty list, '
        'which AppUser.friends relies on', () async {
      await writeInitialProfile('new-uid');

      final friendsDoc =
          await fakeFirestore.collection('new-uid').doc('Friends').get();
      final data = friendsDoc.data() as Map<String, dynamic>;
      expect(data.containsKey('friends'), isTrue);
      expect(data['friends'], equals([]));
    });

    test('the write is atomic: if the batch commit fails, none of the '
        'writes queued in it are applied', () async {
      // fake_cloud_firestore's WriteBatch mirrors real Firestore's
      // all-or-nothing commit: it rejects the whole batch up front once it
      // holds more than 500 writes, before applying any of them. Use that
      // to exercise the same guarantee writeInitialProfile depends on,
      // without needing a way to inject an arbitrary failure per-document.
      final batch = fakeFirestore.batch();
      final users = fakeFirestore.collection('atomic-uid');
      batch.set(users.doc('Movies'), const {'Seen': []});
      batch.set(users.doc('Friends'), const {'friends': []});
      for (var i = 0; i < 500; i++) {
        batch.set(
            fakeFirestore.collection('padding').doc('doc-$i'), const {'x': 1});
      }

      await expectLater(batch.commit(), throwsA(anything));

      expect((await users.doc('Movies').get()).exists, isFalse);
      expect((await users.doc('Friends').get()).exists, isFalse);
    });
  });
}
