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
  Friends();

  @override
  _FriendsState createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  final TextEditingController _usernameController = TextEditingController();
  Future<void> _refreshFriends() async {
    var FriendsDoc =
        await FirebaseFirestore.instance.collection(uid).doc("Friends").get();
    Map<String, dynamic> data = FriendsDoc.data() as Map<String, dynamic>;
    friends = data["friends"];
    setState(() {
      friends = friends;
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
      appBar: CustomAppBar(),
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
                    return GestureDetector(
                      onTap: () {
                        // Navigate to Profile Page
                        friendUid = friends[friendIndex];
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
                      //   children: [
                      //     Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //       children: [
                      //         GestureDetector(
                      //           onTap: () {
                      //             // Navigate to Profile Page
                      //             friendUid = friends[friendIndex];
                      //             Navigator.push(
                      //               context,
                      //               MaterialPageRoute(
                      //                 builder: (context) =>
                      //                     FriendProfile(friendUID: friendUid),
                      //               ),
                      //             );
                      //           },
                      //           child: Container(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 16, vertical: 10),
                      //             decoration: BoxDecoration(
                      //               borderRadius: BorderRadius.circular(10),
                      //             ),
                      //             child: const Row(
                      //               children: [
                      //                 Icon(Icons.person, color: Colors.blue),
                      //                 SizedBox(width: 5),
                      //                 Text(
                      //                   'Profile',
                      //                   style: TextStyle(
                      //                     color: Colors.white,
                      //                     fontSize: 12,
                      //                     fontWeight: FontWeight.bold,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //         GestureDetector(
                      //           onTap: () {
                      //             // Navigate to Calendar Page
                      //             friendUid = friends[friendIndex];
                      //             Navigator.push(
                      //               context,
                      //               MaterialPageRoute(
                      //                 builder: (context) =>
                      //                     FriendCalendar(friendUid: friendUid),
                      //               ),
                      //             );
                      //           },
                      //           child: Container(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 16, vertical: 10),
                      //             decoration: BoxDecoration(
                      //               borderRadius: BorderRadius.circular(10),
                      //             ),
                      //             child: const Row(
                      //               children: [
                      //                 Icon(Icons.calendar_today,
                      //                     color: Colors.green),
                      //                 SizedBox(width: 5),
                      //                 Text(
                      //                   'Calendar',
                      //                   style: TextStyle(
                      //                     color: Colors.white,
                      //                     fontSize: 12,
                      //                     fontWeight: FontWeight.bold,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //         GestureDetector(
                      //           onTap: () async {
                      //             bool confirmed = await showDialog(
                      //               context: context,
                      //               builder: (BuildContext context) {
                      //                 return AlertDialog(
                      //                   title: const Text('Confirmation'),
                      //                   content: const Text(
                      //                       'Are you sure you want to remove this friend?'),
                      //                   actions: <Widget>[
                      //                     TextButton(
                      //                       child: const Text('No'),
                      //                       onPressed: () {
                      //                         Navigator.of(context).pop(false);
                      //                       },
                      //                     ),
                      //                     TextButton(
                      //                       child: const Text('Yes'),
                      //                       onPressed: () {
                      //                         Navigator.of(context).pop(true);
                      //                       },
                      //                     ),
                      //                   ],
                      //                 );
                      //               },
                      //             );
                      //             if (confirmed) {
                      //               String friendUID = friends[friendIndex];
                      //               // Reference to the Firestore instance
                      //               FirebaseFirestore firestore =
                      //                   FirebaseFirestore.instance;
                      //               // Remove friend from current user's friend list
                      //               await firestore
                      //                   .collection(friendUID)
                      //                   .doc("Friends")
                      //                   .update({
                      //                 'friends': FieldValue.arrayRemove([uid])
                      //               });
                      //               // Remove current user from friend's friend list
                      //               await firestore
                      //                   .collection(uid)
                      //                   .doc("Friends")
                      //                   .update({
                      //                 'friends':
                      //                     FieldValue.arrayRemove([friendUID])
                      //               });
                      //               setState(() {
                      //                 friends.remove(friendUID);
                      //               });
                      //             }
                      //           },
                      //           child: Container(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 16, vertical: 10),
                      //             decoration: BoxDecoration(
                      //               borderRadius: BorderRadius.circular(10),
                      //             ),
                      //             child: const Row(
                      //               children: [
                      //                 Icon(Icons.remove_circle,
                      //                     color: Colors.red),
                      //                 SizedBox(width: 5),
                      //                 Text(
                      //                   'Remove',
                      //                   style: TextStyle(
                      //                     color: Colors.white,
                      //                     fontSize: 12,
                      //                     fontWeight: FontWeight.bold,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //     const SizedBox(
                      //         height:
                      //             10), // Optional: to add some space between the row and the list
                      //     FutureBuilder<DocumentSnapshot>(
                      //       future: FirebaseFirestore.instance
                      //           .collection(uid)
                      //           .doc('Calendar')
                      //           .get(),
                      //       builder: (context, snapshot) {
                      //         if (snapshot.connectionState ==
                      //             ConnectionState.waiting) {
                      //           return const Center(
                      //               child: CircularProgressIndicator());
                      //         } else if (snapshot.hasError) {
                      //           return Text('Error: ${snapshot.error}');
                      //         } else if (!snapshot.hasData ||
                      //             !snapshot.data!.exists) {
                      //           return const Text('No data found');
                      //         } else {
                      //           var calendar = snapshot.data!.data() as Map;
                      //           List moviesSeenTogether = [];
                      //           for (var date in calendar.keys) {
                      //             for (var movie in calendar[date]) {
                      //               if (movie.containsKey("friends")) {
                      //                 if (movie['friends']
                      //                     .contains(friends[friendIndex])) {
                      //                   moviesSeenTogether.add(movie["title"]);
                      //                 }
                      //               }
                      //             }
                      //           }
                      //           if (moviesSeenTogether.length > 0) {
                      //             return Column(children: [
                      //               Text(moviesSeenTogether.length > 1
                      //                   ? "You have seen ${moviesSeenTogether.length} movies together"
                      //                   : "You have seen ${moviesSeenTogether.length} movie together"),
                      //               Container(
                      //                 height: 125,
                      //                 child: ListView.builder(
                      //                   itemCount: moviesSeenTogether.length,
                      //                   itemBuilder: (context, index) {
                      //                     return ListTile(
                      //                       title: Text(
                      //                         '${index + 1}. ${moviesSeenTogether[index]}',
                      //                         style: const TextStyle(
                      //                             color: Colors.white,
                      //                             fontSize: 16),
                      //                       ),
                      //                     );
                      //                   },
                      //                 ),
                      //               )
                      //             ]);
                      //           } else {
                      //             return const Text(
                      //                 "You haven't watched any movies together yet");
                      //           }
                      //         }
                      //       },
                      //     ),
                      //   ],
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
