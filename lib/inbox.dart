import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        .doc('Settings')
        .update({
      'friends': FieldValue.arrayUnion([senderUID]),
    });

    await FirebaseFirestore.instance
        .collection(senderUID)
        .doc('Settings')
        .update({
      'friends': FieldValue.arrayUnion([recipientUID]),
    });
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
        title: Text('Friend Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getFriendRequests(widget.currentUserUID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No friend requests found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var request = snapshot.data!.docs[index];
                String senderUID = request.id;
                String status = request['status'];

                return ListTile(
                  title: Text('Request from UID: $senderUID'),
                  subtitle: Text('Status: $status'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () {
                          acceptFriendRequest(widget.currentUserUID, senderUID);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          rejectFriendRequest(widget.currentUserUID, senderUID);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
