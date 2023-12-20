import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/Playlist.dart';

class GrantAccessDialog extends StatefulWidget {
  final Playlist list_result;
  const GrantAccessDialog({Key? key, required this.list_result})
      : super(key: key);

  @override
  _GrantAccessDialogState createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<GrantAccessDialog> {
  Map<String, bool> selectedFriends = {};

  @override
  Widget build(BuildContext context) {
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
            if (currentUser.friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  height: 125, // Set your desired height here
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentUser.friends.length,
                    itemBuilder: (context, friendIndex) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection(currentUser.friends[friendIndex])
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
                              value: selectedFriends.keys.toList().contains(
                                      currentUser.friends[friendIndex])
                                  ? selectedFriends[
                                      currentUser.friends[friendIndex]]
                                  : false,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectedFriends[currentUser
                                      .friends[friendIndex]] = value!;
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
                    await FirebaseFirestore.instance
                        .collection('Watchlists')
                        .doc(widget.list_result.id)
                        .update({'Users': FieldValue.arrayUnion(itemToAdd)});
                    widget.list_result.users += itemToAdd;
                    Navigator.pop(context, widget.list_result);
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
