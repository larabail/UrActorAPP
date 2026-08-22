/// Tests for what deleting an account actually removes.
///
/// Every case here was a document that survived "Delete Account" and should
/// not have. The data model is the reason: a user owns a top-level collection
/// named after their uid, but their playlists, their claimed username and the
/// friend requests they were sent all live somewhere else, and the old
/// deletion walked only the collection. The account vanished; the things
/// naming it did not.
///
/// The account deletion page at uractor.com/profile.html tells users that
/// their lists go with their account. These tests are what make that true.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/account_deletion_service.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = installFakeFirestore();
  });

  /// A playlist document as the app writes one.
  Future<String> seedPlaylist(
    String name,
    List<Map<String, String>> users,
  ) async {
    final doc = firestore.collection('Watchlists').doc();
    await doc.set({
      'Name': name,
      'Movies': <String>[],
      'TV Shows': <String>[],
      'Users': users,
      'memberUids': users.expand((entry) => entry.keys).toList()..sort(),
    });
    return doc.id;
  }

  group('the account own collection', () {
    test('every document in it is deleted', () async {
      await seedUserDoc(firestore, 'gone', 'Movies', {
        'Movies': ['27205']
      });
      await seedUserDoc(firestore, 'gone', 'Settings', {'language': 'en'});

      await AccountDeletionService.purge('gone');

      final left = await firestore.collection('gone').get();
      expect(left.docs, isEmpty);
    });

    test('another account is left alone', () async {
      await seedUserDoc(firestore, 'gone', 'Movies', {'Movies': <String>[]});
      await seedUserDoc(firestore, 'stays', 'Movies', {
        'Movies': ['27205']
      });

      await AccountDeletionService.purge('gone');

      final other = await firestore.collection('stays').get();
      expect(other.docs, hasLength(1));
    });
  });

  group('playlists', () {
    test('one the account owned is deleted with it', () async {
      // The failure this covers: a playlist lives in the top-level Watchlists
      // collection, so deleting the owner's collection left the list, its name
      // and everything in it readable by any signed-in user, forever.
      final id = await seedPlaylist('Noir', [
        {'gone': 'Owner'}
      ]);

      await AccountDeletionService.purge('gone');

      final doc = await firestore.collection('Watchlists').doc(id).get();
      expect(doc.exists, isFalse);
    });

    test('a shared one the account merely joined survives without them',
        () async {
      // Deleting it would destroy someone else's list, so the departing member
      // is stepped out of it instead.
      final id = await seedPlaylist('Westerns', [
        {'host': 'Owner'},
        {'gone': 'Approved'},
      ]);

      await AccountDeletionService.purge('gone');

      final doc = await firestore.collection('Watchlists').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['Users'], [
        {'host': 'Owner'}
      ]);
      expect(doc.data()!['memberUids'], ['host']);
    });

    test('a list the account was never in is untouched', () async {
      final id = await seedPlaylist('Strangers', [
        {'host': 'Owner'}
      ]);

      await AccountDeletionService.purge('gone');

      final doc = await firestore.collection('Watchlists').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['memberUids'], ['host']);
    });
  });

  group('the claimed username', () {
    test('is released so the name can be taken again', () async {
      // It also held the uid, which stayed readable by every signed-in user
      // long after the account it named had gone.
      await firestore
          .collection('usernames')
          .add({'username': 'lara', 'uid': 'gone'});

      await AccountDeletionService.purge('gone');

      final left = await firestore.collection('usernames').get();
      expect(left.docs, isEmpty);
    });

    test('someone else keeps theirs', () async {
      await firestore
          .collection('usernames')
          .add({'username': 'lara', 'uid': 'gone'});
      await firestore
          .collection('usernames')
          .add({'username': 'sam', 'uid': 'stays'});

      await AccountDeletionService.purge('gone');

      final left = await firestore.collection('usernames').get();
      expect(left.docs, hasLength(1));
      expect(left.docs.single.data()['username'], 'sam');
    });
  });

  group('friend requests', () {
    test('the ones sent to the account go too', () async {
      // Firestore does not delete a subcollection with its parent document,
      // so draining this has to be explicit. Deleting the Friends document
      // left the requests underneath it as orphans.
      await firestore
          .collection('gone')
          .doc('Friends')
          .collection('FriendRequests')
          .doc('sender')
          .set({'senderUID': 'sender', 'status': 'pending'});

      await AccountDeletionService.purge('gone');

      final left = await firestore
          .collection('gone')
          .doc('Friends')
          .collection('FriendRequests')
          .get();
      expect(left.docs, isEmpty);
    });

    test('the one held by a friend is cleared as well', () async {
      await seedUserDoc(firestore, 'gone', 'Friends', {
        'friends': ['mate']
      });
      await firestore.collection('mate').doc('Friends').set({
        'friends': ['gone']
      });
      await firestore
          .collection('mate')
          .doc('Friends')
          .collection('FriendRequests')
          .doc('gone')
          .set({'senderUID': 'gone', 'status': 'accepted'});

      await AccountDeletionService.purge('gone');

      final left = await firestore
          .collection('mate')
          .doc('Friends')
          .collection('FriendRequests')
          .get();
      expect(left.docs, isEmpty);
    });
  });

  group('friends of the account', () {
    test('no longer list a uid that cannot load', () async {
      await seedUserDoc(firestore, 'gone', 'Friends', {
        'friends': ['mate', 'other']
      });
      await firestore.collection('mate').doc('Friends').set({
        'friends': ['gone', 'other']
      });
      await firestore.collection('other').doc('Friends').set({
        'friends': ['gone']
      });

      await AccountDeletionService.purge('gone');

      final mate = await firestore.collection('mate').doc('Friends').get();
      expect(mate.data()!['friends'], ['other']);
      final other = await firestore.collection('other').doc('Friends').get();
      expect(other.data()!['friends'], isEmpty);
    });

    test('an account with no Friends document deletes cleanly', () async {
      // Every per-user document is created lazily on first write, so an
      // account that never added anyone has no Friends document to read.
      await seedUserDoc(firestore, 'gone', 'Movies', {'Movies': <String>[]});

      await AccountDeletionService.purge('gone');

      expect((await firestore.collection('gone').get()).docs, isEmpty);
    });

    test('a friend who already removed them does not stop the deletion',
        () async {
      // The write into someone else's document is the one most likely to be
      // refused, and it must not leave the account half-deleted and still
      // signed-in-able.
      await seedUserDoc(firestore, 'gone', 'Friends', {
        'friends': ['ghost']
      });

      await AccountDeletionService.purge('gone');

      expect((await firestore.collection('gone').get()).docs, isEmpty);
    });
  });

  group('usersWithout', () {
    test('drops the entry naming the uid and keeps the rest', () {
      final users = [
        {'host': 'Owner'},
        {'gone': 'Approved'},
        {'guest': 'Approved'},
      ];

      expect(AccountDeletionService.usersWithout(users, 'gone'), [
        {'host': 'Owner'},
        {'guest': 'Approved'},
      ]);
    });

    test('a null Users field is an empty list, not a crash', () {
      // Old playlists predate the field, and a list written by a build that
      // failed partway can be missing it.
      expect(AccountDeletionService.usersWithout(null, 'gone'), isEmpty);
    });

    test('entries that are not maps are discarded', () {
      expect(AccountDeletionService.usersWithout(['junk', 7], 'gone'), isEmpty);
    });
  });
}
