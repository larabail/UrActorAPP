// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/l10n/l10n.dart';

import 'main.dart';

/// Performs the Firestore writes needed to accept a friend request: marks
/// the request accepted, then adds each user to the other's `Friends` list.
///
/// Kept separate from `_FriendRequestsPageState.acceptFriendRequest` (and not
/// private) so it can be tested directly against a `FakeFirebaseFirestore`
/// installed through `FirestoreCore.db`, without a BuildContext or
/// `currentUser` mutation in the way.
@visibleForTesting
Future<void> acceptFriendRequestWrites(
    String recipientUID, String senderUID) async {
  // Update status to accepted. Deliberately left as `update`, not a merging
  // `set`: this mutates a friend request that must already exist, and if it
  // doesn't we want a `not-found` failure rather than to fabricate an
  // "accepted" request out of nothing.
  await FirestoreCore.db
      .collection(recipientUID)
      .doc('Friends')
      .collection('FriendRequests')
      .doc(senderUID)
      .update({'status': 'accepted'});

  // Add each other to friends list. Routed through FirestoreCore so a
  // missing `Friends` document (which is exactly what caused one-sided
  // friendships in production) is created instead of throwing `not-found`;
  // `arrayUnion` still works correctly through the merge.
  await FirestoreCore.updateDocument(recipientUID, 'Friends', {
    'friends': FieldValue.arrayUnion([senderUID]),
  });

  await FirestoreCore.updateDocument(senderUID, 'Friends', {
    'friends': FieldValue.arrayUnion([recipientUID]),
  });
}

/// Performs the Firestore write needed to reject a friend request. See
/// [acceptFriendRequestWrites] for why this is a separate, testable
/// top-level function and why the status write stays as `update`.
@visibleForTesting
Future<void> rejectFriendRequestWrite(
    String recipientUID, String senderUID) async {
  // See the comment in acceptFriendRequestWrites: deliberately left as
  // `update` since a request that doesn't exist can't be rejected.
  await FirestoreCore.db
      .collection(recipientUID)
      .doc('Friends')
      .collection('FriendRequests')
      .doc(senderUID)
      .update({'status': 'rejected'});
}

class FriendRequestsPage extends StatefulWidget {
  final String currentUserUID;

  const FriendRequestsPage({super.key, required this.currentUserUID});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  Future<void> acceptFriendRequest(String recipientUID, String senderUID) async {
    try {
      await acceptFriendRequestWrites(recipientUID, senderUID);

      // Only mutate local state once every write above has actually
      // succeeded, so it can't disagree with the server on failure.
      currentUser.friends.add(senderUID);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.friendRequestActionFailedError)),
      );
    }
  }

  Future<void> rejectFriendRequest(String recipientUID, String senderUID) async {
    try {
      await rejectFriendRequestWrite(recipientUID, senderUID);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.friendRequestActionFailedError)),
      );
    }
  }

  Stream<QuerySnapshot> getFriendRequests(String recipientUID) {
    return FirebaseFirestore.instance
        .collection(recipientUID)
        .doc('Friends')
        .collection('FriendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.friendRequests),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getFriendRequests(widget.currentUserUID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(S.of(context)!.noData));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var request = snapshot.data!.docs[index];
                String status = request['status'];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection(request.id)
                      .doc("Settings")
                      .get(),
                  builder: (BuildContext context,
                      AsyncSnapshot<DocumentSnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text(S.of(context)!.loading),
                        subtitle: Text(S.of(context)!.status(status)),
                      );
                    } else if (snapshot.hasError) {
                      return ListTile(
                        title: Text('Error: ${snapshot.error}'),
                        subtitle: Text(S.of(context)!.status(status)),
                      );
                    } else if (!snapshot.hasData || !snapshot.data!.exists) {
                      return ListTile(
                        title: Text(S.of(context)!.noSuchUser),
                        subtitle: Text(S.of(context)!.status(status)),
                      );
                    } else {
                      String senderUsername =
                          snapshot.data!['username'] ?? 'Unknown User';
                      return ListTile(
                        title: Text(S.of(context)!.requestFrom(senderUsername)),
                        subtitle: Text(S.of(context)!.status(status)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await acceptFriendRequest(
                                    widget.currentUserUID, request.id);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await rejectFriendRequest(
                                    widget.currentUserUID, request.id);
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
