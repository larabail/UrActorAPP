// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'friends_profile.dart';
import 'inbox.dart';
import 'main.dart';

String friendUid = "";

class Friends extends StatefulWidget {
  const Friends();

  @override
  _FriendsState createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  final TextEditingController _usernameController = TextEditingController();
  Future<void> _refreshFriends() async {
    var FriendsDoc = await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .doc("Friends")
        .get();
    Map<String, dynamic> data = FriendsDoc.data() as Map<String, dynamic>;
    currentUser.friends = data["friends"];
    setState(() {
      currentUser.friends = currentUser.friends;
    });
  }

  @override
  Widget build(BuildContext context) {
    friendUid = "";

    void sendFriendRequest(String recipientUID) async {
      await FirebaseFirestore.instance
          .collection(recipientUID)
          .doc('Friends')
          .collection('FriendRequests')
          .doc(currentUser.uid)
          .set({
        'senderUID': currentUser.uid,
        'status': 'pending',
      });
    }

    void addFriend() {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: const Text(
                'Add Friend',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String inputUsername = _usernameController.text.trim();
                      if (inputUsername.isNotEmpty) {
                        QuerySnapshot query = await FirebaseFirestore.instance
                            .collection('usernames')
                            .where('username', isEqualTo: inputUsername)
                            .get();

                        if (query.docs.isNotEmpty) {
                          String friendUid = query.docs[0].get("uid");

                          sendFriendRequest(friendUid);
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Username does not exist'),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          });
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshFriends,
        child: ListView.builder(
          itemCount: currentUser.friends.length + 1, // Increase itemCount by 1
          itemBuilder: (context, index) {
            if (index == 0) {
              // Add a custom ListTile at the beginning
              return ListTile(
                leading: const Padding(
                  padding: EdgeInsets.only(left: 16.0), // Add left padding
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center vertically
                    children: [
                      Icon(Icons.mail), // Icon to the left
                    ],
                  ),
                ),
                title: const Text(
                    'Friend requests'), // Text to the right of the icon
                subtitle: const Text(
                    'Approve or reject requests'), // Subtitle below the title
                onTap: () {
                  // Navigate to FriendRequestsPage when ListTile is tapped
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FriendRequestsPage(currentUserUID: currentUser.uid),
                    ),
                  );
                },
              );
            } else {
              // Adjust the index to account for the added ListTile
              int friendIndex = index - 1;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection(currentUser.friends[friendIndex])
                    .doc('Settings')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('No data found');
                  } else {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    String profilePath = data['profile_photo'] ?? '';
                    String userName = data['username'] ?? '';
                    return GestureDetector(
                      onTap: () {
                        // Navigate to Profile Page
                        friendUid = currentUser.friends[friendIndex];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FriendProfile(friendUID: friendUid),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        margin: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          children: [
                            ClipOval(
                              child: profilePath != ""
                                  ? Image.network(
                                      profilePath,
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/main_profile.png',
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: Text(
                                userName,
                                style: const TextStyle(fontSize: 16.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addFriend,
        backgroundColor: Colors.grey[900],
        child: const Icon(
          Icons.add,
          color: Colors.green,
          size: 30,
        ),
      ),
      bottomNavigationBar: CommonBottomAppBar(2),
    );
  }
}
