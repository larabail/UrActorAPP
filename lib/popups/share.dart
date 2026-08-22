import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/media.dart';
import '../common/firebase/firestore_core.dart';
import '../common/widgets/app_dialog.dart';
import '../common/widgets/friend_picker.dart';

class Share extends StatefulWidget {
  final MediaItem item;
  final String type;

  const Share({super.key, required this.item, required this.type});

  @override
  State<Share> createState() => _ShareState();
}

class _ShareState extends State<Share> {
  FirebaseFirestore db = FirestoreCore.db;
  Map<String, bool> selectedFriends = {};

  Future<void> sendNotification(
    String friendId,
    MediaItem media,
    String type,
  ) async {
    try {
      Map tempNotification = {
        'type': type,
        'id': media.id,
        "title": media.title,
        "coverPhoto": media.coverPhoto,
        'sender': {
          "username": currentUser.settings["username"],
          "uid": currentUser.uid,
        },
        "read": false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      var friendNotificationDoc =
          FirestoreCore.db.collection(friendId).doc("Notifications");
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

  Future<void> _send() async {
    for (final friendId in selectedFriends.keys) {
      if (selectedFriends[friendId] == true) {
        await sendNotification(friendId, widget.item, widget.type);
      }
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final friendIds = List<String>.from(currentUser.friends);
    return AppDialog(
      actions: [
        AppDialogAction(
          label: "Cancel",
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context, true),
        ),
        AppDialogAction(
          label: "Accept",
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: _send,
        ),
      ],
      child: FriendPicker(
        friendIds: friendIds,
        selected: selectedFriends,
        onChanged: (friendId, value) {
          setState(() => selectedFriends[friendId] = value);
        },
      ),
    );
  }
}
