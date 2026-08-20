import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/movie.dart';

class AddFriendsPopUp extends StatefulWidget {
  final Movie movie;
  
  const AddFriendsPopUp({super.key, required this.movie});

  @override
  State<AddFriendsPopUp> createState() => _AddFriendsPopUpState();
}

class _AddFriendsPopUpState extends State<AddFriendsPopUp> {
  Map<String, bool> selectedFriends = {};
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Friends'),
      content: SizedBox(
        height: 250,
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(
              currentUser.friends.length,
              (friendIndex) {
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
                      String userName = data['username'] ?? '';
                      String profilePath = data['profile_photo'] ?? '';
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            ClipOval(
                              child: profilePath != ""
                                  ? Image.network(
                                      profilePath,
                                      height: 25,
                                      width: 25,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/main_profile.png',
                                      height: 25,
                                      width: 25,
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
                        value: selectedFriends.keys
                                .toList()
                                .contains(currentUser.friends[friendIndex])
                            ? selectedFriends[currentUser.friends[friendIndex]]
                            : false,
                        onChanged: (bool? value) {
                          setState(() {
                            selectedFriends[currentUser.friends[friendIndex]] =
                                value!;
                          });
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Apply'),
          onPressed: () async {
            String id = widget.movie.id;
            FirebaseFirestore firestore = FirebaseFirestore.instance;
            for (String friend in selectedFriends.keys.toList()) {
              var userDoc =
                  FirebaseFirestore.instance.collection(friend).doc("Movies");
              await userDoc.update({
                'Seen': FieldValue.arrayUnion([id])
              });
              userDoc =
                  FirebaseFirestore.instance.collection(friend).doc("Seen");
              await userDoc.update({
                'Movies': FieldValue.arrayUnion([id])
              });
              if (currentUser.seenWith.containsKey(friend) &&
                  !currentUser.seenWith[friend]["Movies"]
                      .contains(id.toString())) {
                currentUser.seenWith[friend]["Movies"].add(id.toString());
              } else if (!currentUser.seenWith.containsKey(friend)) {
                currentUser.seenWith[friend] = {"Movies": [], "TVShows": []};
                currentUser.seenWith[friend]["Movies"].add(id.toString());
              }
              DocumentReference userDoc2 =
                  firestore.collection(friend).doc("SeenWith");
              Map<String, dynamic> item = {};
              List<dynamic> watchedWithList = [currentUser.uid];
              item[id] = watchedWithList;
              await firestore.runTransaction((transaction) async {
                DocumentSnapshot snapshot = await transaction.get(userDoc2);

                if (!snapshot.exists) {
                  throw Exception("Document does not exist!");
                }

                Map<String, dynamic> data =
                    snapshot.data() as Map<String, dynamic>;

                if (data.containsKey('Movies') &&
                    data['Movies'] is Map<String, dynamic>) {
                  Map<String, dynamic> moviesMap = data['Movies'];

                  if (moviesMap.containsKey(id)) {
                    List existingList = moviesMap[id]["friends"];
                    for (String person in watchedWithList) {
                      if (!existingList.contains(person)) {
                        existingList.add(person);
                      }
                    }
                    moviesMap[id] = {"friends": existingList};
                    transaction.update(userDoc2, {"Movies": moviesMap});
                  } else {
                    moviesMap[id] = {"friends": watchedWithList};
                    transaction.update(userDoc2, {"Movies": moviesMap});
                  }
                } else {
                  transaction.set(
                      userDoc2,
                      {
                        'Movies': {
                          id: {"friends": watchedWithList}
                        }
                      },
                      SetOptions(merge: true));
                }
              }).catchError((error) {
                debugPrint("Failed to update document: $error");
              });
            }
            DocumentReference userDoc2 =
                firestore.collection(currentUser.uid).doc("SeenWith");

            Map<String, dynamic> item = {};
            List<dynamic> watchedWithList = selectedFriends.keys
                .where((key) => selectedFriends[key] == true)
                .toList();
            item[id] = watchedWithList;
            firestore.runTransaction((transaction) async {
              DocumentSnapshot snapshot = await transaction.get(userDoc2);

              if (!snapshot.exists) {
                throw Exception("Document does not exist!");
              }

              Map<String, dynamic> data =
                  snapshot.data() as Map<String, dynamic>;

              if (data.containsKey('Movies') &&
                  data['Movies'] is Map<String, dynamic>) {
                Map<String, dynamic> moviesMap = data['Movies'];

                if (moviesMap.containsKey(id)) {
                  List existingList = moviesMap[id]["friends"];
                  for (String person in watchedWithList) {
                    if (!existingList.contains(person)) {
                      existingList.add(person);
                    }
                  }
                  moviesMap[id] = {"friends": existingList};
                } else {
                  moviesMap[id] = {"friends": watchedWithList};
                }
                transaction.update(userDoc2, {'Movies': moviesMap});
              } else {
                transaction.set(
                    userDoc2,
                    {
                      'Movies': {
                        id: {"friends": watchedWithList}
                      }
                    },
                    SetOptions(merge: true));
              }
            }).catchError((error) {
              debugPrint("Failed to update document: $error");
            });
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
