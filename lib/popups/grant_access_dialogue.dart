import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../common/firebase/firestore_core.dart';
import '../common/widgets/app_dialog.dart';
import '../common/widgets/friend_picker.dart';
import '../objects/playlist.dart';

class GrantAccessDialog extends StatefulWidget {
  final Playlist listResult;
  const GrantAccessDialog({super.key, required this.listResult});

  @override
  State<GrantAccessDialog> createState() => _GrantAccessDialogState();
}

class _GrantAccessDialogState extends State<GrantAccessDialog> {
  Map<String, bool> selectedFriends = {};

  Future<void> _grant() async {
    final itemToAdd = [
      for (final friendUid in selectedFriends.keys) {friendUid: "Approved"},
    ];
    await FirestoreCore.mergeInto(
      FirestoreCore.db.collection('Watchlists').doc(widget.listResult.id),
      {
        'Users': FieldValue.arrayUnion(itemToAdd),
        'memberUids': FieldValue.arrayUnion(selectedFriends.keys.toList()),
      },
    );
    widget.listResult.users += itemToAdd;
    if (!mounted) return;
    Navigator.pop(context, widget.listResult);
  }

  @override
  Widget build(BuildContext context) {
    final Set uidsInListResult =
        widget.listResult.users.expand((map) => map.keys).toSet();

    // Only friends who are not already on the list are worth offering.
    final uniqueFriendIds = List<String>.from(
      currentUser.friends.where(
        (friendId) => !uidsInListResult.contains(friendId),
      ),
    );

    return AppDialog(
      title: "Grant Users Access",
      actions: [
        AppDialogAction(
          label: "Cancel",
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: "Accept",
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: _grant,
        ),
      ],
      child: uniqueFriendIds.isEmpty
          ? const Text("All your friends already have access to this list")
          : FriendPicker(
              friendIds: uniqueFriendIds,
              selected: selectedFriends,
              onChanged: (friendId, value) {
                setState(() => selectedFriends[friendId] = value);
              },
            ),
    );
  }
}
