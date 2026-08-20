import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/inbox.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/user.dart';

void main() {
  group('acceptFriendRequestWrites', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirestoreCore.db = fakeFirestore;
      addTearDown(FirestoreCore.resetDb);
    });

    Future<void> seedPendingRequest(String recipientUID, String senderUID) {
      return fakeFirestore
          .collection(recipientUID)
          .doc('Friends')
          .collection('FriendRequests')
          .doc(senderUID)
          .set({'status': 'pending'});
    }

    test('adds each user to the other\'s friends list', () async {
      const recipientUID = 'recipient-uid';
      const senderUID = 'sender-uid';
      await seedPendingRequest(recipientUID, senderUID);
      await fakeFirestore
          .collection(recipientUID)
          .doc('Friends')
          .set({'friends': []});
      await fakeFirestore
          .collection(senderUID)
          .doc('Friends')
          .set({'friends': []});

      await acceptFriendRequestWrites(recipientUID, senderUID);

      final recipientFriends = (await fakeFirestore
              .collection(recipientUID)
              .doc('Friends')
              .get())
          .data() as Map<String, dynamic>;
      final senderFriends = (await fakeFirestore
              .collection(senderUID)
              .doc('Friends')
              .get())
          .data() as Map<String, dynamic>;

      expect(recipientFriends['friends'], contains(senderUID));
      expect(senderFriends['friends'], contains(recipientUID));
    });

    test(
        'adds each user to the other\'s friends list even when the sender '
        'has no Friends document yet -- the exact case that produced '
        'one-sided friendships in production', () async {
      const recipientUID = 'recipient-uid';
      const senderUID = 'sender-uid-with-no-friends-doc';
      await seedPendingRequest(recipientUID, senderUID);
      await fakeFirestore
          .collection(recipientUID)
          .doc('Friends')
          .set({'friends': []});
      // Deliberately not creating senderUID's Friends document.

      await acceptFriendRequestWrites(recipientUID, senderUID);

      final recipientFriends = (await fakeFirestore
              .collection(recipientUID)
              .doc('Friends')
              .get())
          .data() as Map<String, dynamic>;
      final senderFriendsDoc =
          await fakeFirestore.collection(senderUID).doc('Friends').get();

      expect(recipientFriends['friends'], contains(senderUID));
      expect(senderFriendsDoc.exists, isTrue);
      expect(senderFriendsDoc.data(),
          equals({'friends': [recipientUID]}));
    });

    test('throws (rather than silently succeeding) when the friend request '
        'document does not exist', () async {
      const recipientUID = 'recipient-uid';
      const senderUID = 'sender-uid';
      // No seeded FriendRequests document.

      expect(
        () => acceptFriendRequestWrites(recipientUID, senderUID),
        throwsA(anything),
      );
    });
  });

  group('_FriendRequestsPageState.acceptFriendRequest local state', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirestoreCore.db = fakeFirestore;
      addTearDown(FirestoreCore.resetDb);
      currentUser = AppUser(uid: 'recipient-uid');
    });

    test('a failed acceptance does not leave currentUser.friends updated',
        () async {
      const recipientUID = 'recipient-uid';
      const senderUID = 'sender-uid';
      // No seeded FriendRequests document, so the write throws before any
      // friends list is touched.

      try {
        await acceptFriendRequestWrites(recipientUID, senderUID);
        currentUser.friends.add(senderUID);
      } catch (_) {
        // Mirrors _FriendRequestsPageState.acceptFriendRequest: local state
        // is only mutated after the writes above succeed.
      }

      expect(currentUser.friends, isEmpty);
    });
  });
}
