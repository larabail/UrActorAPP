import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  group('rollbackCreatedAuthAccountAfterProfileFailure', () {
    test('deletes the newly created auth account after profile setup fails, '
        'so the email can be used for another signup attempt', () async {
      var deleteCalled = false;

      final result = await rollbackCreatedAuthAccountAfterProfileFailure(
        deleteAccount: () async {
          deleteCalled = true;
        },
        profileError: StateError('profile batch failed'),
      );

      expect(result, CreatedAuthAccountRollbackResult.deleted);
      expect(deleteCalled, isTrue);
    });

    test('reports the original profile setup error when auth rollback also '
        'fails, because that is what broke signup first', () async {
      // A failed delete means the email may still be stuck, but the log must
      // preserve the profile-write failure that actually made signup fail.
      final profileError = StateError('profile batch failed');
      final rollbackError = StateError('network unavailable');
      final reports = <FlutterErrorDetails>[];

      final result = await rollbackCreatedAuthAccountAfterProfileFailure(
        deleteAccount: () async => throw rollbackError,
        profileError: profileError,
        reportError: reports.add,
      );

      expect(result, CreatedAuthAccountRollbackResult.failed);
      expect(reports, hasLength(2));
      expect(reports.first.exception, same(profileError));
      expect(reports.last.exception, same(rollbackError));
    });

    test('reports the original profile setup error when there is no auth user '
        'to delete, because cleanup cannot be assumed to have happened',
        () async {
      // Firebase normally returns a user after account creation, but this keeps
      // a null credential from being treated like a successful rollback.
      final profileError = StateError('profile batch failed');
      final reports = <FlutterErrorDetails>[];

      final result = await rollbackCreatedAuthAccountAfterProfileFailure(
        deleteAccount: null,
        profileError: profileError,
        reportError: reports.add,
      );

      expect(result, CreatedAuthAccountRollbackResult.unavailable);
      expect(reports, hasLength(1));
      expect(reports.single.exception, same(profileError));
    });
  });
}
