// ignore_for_file: non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/playlist.dart';
import '../common/firebase/firestore_core.dart';

class GrantAccessDialog extends StatefulWidget {
  final Playlist listResult;
  const GrantAccessDialog({super.key, required this.listResult});

  @override
  State<GrantAccessDialog> createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<GrantAccessDialog> {
  Map<String, bool> selectedFriends = {};

  @override
  Widget build(BuildContext context) {
    Set uidsInListResult =
        widget.listResult.users.expand((map) => map.keys).toSet();

    // Filter currentUser.friends to get UIDs not in uidsInListResult
    List uniqueFriendIds = currentUser.friends
        .where((friendId) => !uidsInListResult.contains(friendId))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Add rounded corners
      ),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Grant Users Access",
              style: TextStyle(fontSize: 20),
            ),
            if (uniqueFriendIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  height: 125, // Set your desired height here
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: uniqueFriendIds.length,
                    itemBuilder: (context, friendIndex) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirestoreCore.db
                            .collection(uniqueFriendIds[friendIndex])
                            .doc('Settings')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else if (!snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return const Text('No data found');
                          } else {
                            var data =
                                snapshot.data!.data() as Map<String, dynamic>;
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
                                      .contains(uniqueFriendIds[friendIndex])
                                  ? selectedFriends[
                                      uniqueFriendIds[friendIndex]]
                                  : false,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectedFriends[
                                      uniqueFriendIds[friendIndex]] = value!;
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
            if (uniqueFriendIds.isEmpty)
              const Text("All your friends already have access to this list"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.red,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          "Cancel",
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        )
                      ],
                    )),
                const SizedBox(
                  width: 5,
                ),
                ElevatedButton(
                  onPressed: () async {
                    List itemToAdd = [];
                    for (String friendUid in selectedFriends.keys.toList()) {
                      itemToAdd.add({friendUid: "Approved"});
                    }
                    await FirestoreCore.db
                        .collection('Watchlists')
                        .doc(widget.listResult.id)
                        .update({'Users': FieldValue.arrayUnion(itemToAdd)});
                    widget.listResult.users += itemToAdd;
                    if (!context.mounted) return;
                    Navigator.pop(context, widget.listResult);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: Colors.green,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        "Accept",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
