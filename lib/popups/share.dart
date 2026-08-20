import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/media.dart';

class Share extends StatefulWidget {
  final MediaItem item;
  final String type;

  const Share({super.key, required this.item, required this.type});

  @override
  State<Share> createState() => _ShareState();
}

class _ShareState extends State<Share> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  Map<String, bool> selectedFriends = {};

  Future<void> sendNotification(
      String friendId, MediaItem media, String type) async {
    try {
      Map tempNotification = {
        'type': type,
        'id': media.id,
        "title": media.title,
        "coverPhoto": media.coverPhoto,
        'sender': {
          "username": currentUser.settings["username"],
          "uid": currentUser.uid
        },
        "read": false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      var friendNotificationDoc =
          FirebaseFirestore.instance.collection(friendId).doc("Notifications");
      var friendNotifications = await friendNotificationDoc.get();
      var finalNotifications =
          friendNotifications.data() as Map<String, dynamic>;
      finalNotifications[finalNotifications.keys.toList().length.toString()] =
          tempNotification;
      await friendNotificationDoc.set(finalNotifications);
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 500,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser.friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  height: 125,
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
                      Navigator.pop(context, true);
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
                    String itemType = widget.type;
                    for (var friendId in selectedFriends.keys) {
                      if (selectedFriends[friendId] == true) {
                        await sendNotification(friendId, widget.item, itemType);
                      }
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
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
