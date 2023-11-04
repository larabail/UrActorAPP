import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class FriendRequestsPage extends StatefulWidget {
  final String currentUserUID;

  FriendRequestsPage({required this.currentUserUID});

  @override
  _FriendRequestsPageState createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  void acceptFriendRequest(String recipientUID, String senderUID) async {
    // Update status to accepted
    await FirebaseFirestore.instance
        .collection(recipientUID)
        .doc('Friends')
        .collection('FriendRequests')
        .doc(senderUID)
        .update({'status': 'accepted'});

    // Add each other to friends list
    await FirebaseFirestore.instance
        .collection(recipientUID)
        .doc('Friends')
        .update({
      'friends': FieldValue.arrayUnion([senderUID]),
    });

    await FirebaseFirestore.instance
        .collection(senderUID)
        .doc('Friends')
        .update({
      'friends': FieldValue.arrayUnion([recipientUID]),
    });
    friends.add(senderUID);
  }

  void rejectFriendRequest(String recipientUID, String senderUID) async {
    await FirebaseFirestore.instance
        .collection(recipientUID)
        .doc('Friends')
        .collection('FriendRequests')
        .doc(senderUID)
        .update({'status': 'rejected'});
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
        title: const Text('Friend Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getFriendRequests(widget.currentUserUID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No friend requests found'));
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
                        title: const Text('Loading...'),
                        subtitle: Text('Status: $status'),
                      );
                    } else if (snapshot.hasError) {
                      return ListTile(
                        title: Text('Error: ${snapshot.error}'),
                        subtitle: Text('Status: $status'),
                      );
                    } else if (!snapshot.hasData || !snapshot.data!.exists) {
                      return ListTile(
                        title: const Text('User not found'),
                        subtitle: Text('Status: $status'),
                      );
                    } else {
                      String senderUsername =
                          snapshot.data!['username'] ?? 'Unknown User';
                      return ListTile(
                        title: Text('Request from: $senderUsername'),
                        subtitle: Text('Status: $status'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                acceptFriendRequest(
                                    widget.currentUserUID, request.id);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                rejectFriendRequest(
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
