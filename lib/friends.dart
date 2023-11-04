// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'friends_calendar.dart';
import 'friends_profile.dart';
import 'inbox.dart';
import 'playlists.dart';
import 'search.dart';
import 'main.dart';

// import 'person_result.dart';
// import 'movie_result.dart';
// import 'login.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:http/http.dart' as http;
// import 'package:fl_chart/fl_chart.dart';
// import 'dart:convert';
// import 'package:provider/provider.dart';
// import 'theme_provider.dart';
String friendUid = "";

class Friends extends StatefulWidget {
  Friends();

  @override
  _FriendsState createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  final TextEditingController _usernameController = TextEditingController();
  Future<void> _refreshFriends() async {
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Friends" && friends.isEmpty) {
          Map f = doc.data() as Map;
          friends = f["friends"];
        }
      }
    });
    setState(() {
      friends = friends;
    });
  }

  @override
  Widget build(BuildContext context) {
    friendUid = "";
    int selectedIndex = 0;

    final List<Widget> pages = [
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    void sendFriendRequest(String recipientUID) async {
      await FirebaseFirestore.instance
          .collection(recipientUID)
          .doc('Friends')
          .collection('FriendRequests')
          .doc(uid)
          .set({
        'senderUID': uid,
        'status': 'pending',
      });
    }

    void addFriend() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Add Friend'),
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
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    String inputUsername = _usernameController.text.trim();
                    if (inputUsername.isNotEmpty) {
                      // Check if the username exists
                      QuerySnapshot query = await FirebaseFirestore.instance
                          .collection('usernames')
                          .where('username', isEqualTo: inputUsername)
                          .get();

                      if (query.docs.isNotEmpty) {
                        // Username exists, get the UID
                        String friendUid = query.docs[0].get("uid");

                        // Add the UID to the current user's friends list
                        // Replace 'currentUserUid' with the UID of the current user
                        sendFriendRequest(friendUid);
                        // var userFriendsRef = FirebaseFirestore.instance
                        //     .collection(uid)
                        //     .doc('Friends');

                        // await userFriendsRef.update({
                        //   'friends': FieldValue.arrayUnion([friendUid])
                        // });

                        Navigator.of(context).pop(); // Close the dialog
                        // setState(() {
                        //   friends.add(friendUid);
                        // }); // Refresh the UI
                      } else {
                        // Username does not exist
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Username does not exist'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
          child: Image.asset(
            'assets/logo_character.png',
            height: 54,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFriends,
        child: ListView.builder(
          itemCount: friends.length + 1, // Increase itemCount by 1
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
                          FriendRequestsPage(currentUserUID: uid),
                    ),
                  );
                },
              );
            } else {
              // Adjust the index to account for the added ListTile
              int friendIndex = index - 1;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection(friends[friendIndex])
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
                    return ExpansionTile(
                      title: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.person, color: Colors.blue),
                              onPressed: () {
                                // Navigate to Profile Page
                                friendUid = friends[friendIndex];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FriendProfile(friendUid: friendUid),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today,
                                  color: Colors.green),
                              onPressed: () {
                                // Navigate to Calendar Page
                                friendUid = friends[friendIndex];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FriendCalendar(friendUid: friendUid),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () async {
                                bool confirmed = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirmation'),
                                      content: const Text(
                                          'Are you sure you want to remove this friend?'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('No'),
                                          onPressed: () {
                                            Navigator.of(context).pop(false);
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Yes'),
                                          onPressed: () {
                                            Navigator.of(context).pop(true);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmed) {
                                  String friendUID = friends[friendIndex];

                                  // Reference to the Firestore instance
                                  FirebaseFirestore firestore =
                                      FirebaseFirestore.instance;

                                  // Remove friend from current user's friend list
                                  await firestore
                                      .collection(friendUID)
                                      .doc("Friends")
                                      .update({
                                    'friends': FieldValue.arrayRemove([uid])
                                  });

                                  // Remove current user from friend's friend list
                                  await firestore
                                      .collection(uid)
                                      .doc("Friends")
                                      .update({
                                    'friends':
                                        FieldValue.arrayRemove([friendUID])
                                  });

                                  setState(() {
                                    friends.remove(friendUID);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
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
        backgroundColor: Colors.lightGreen, // Function to open the dialog
        child: const Icon(
          Icons.add,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          const BottomNavigationBarItem(
            label: 'Friends',
            icon: Icon(Icons.contacts),
          ),
          BottomNavigationBarItem(
            label: 'Profile',
            icon: settings["profile_photo"] != ""
                ? ClipOval(
                    child: Image.network(
                    settings["profile_photo"],
                    height: 27,
                    width: 27,
                    fit: BoxFit.cover,
                  ))
                : const Icon(Icons.person),
          ),
        ],
        currentIndex: 3,
        onTap: _onItemTapped,
      ),
    );
  }
}
