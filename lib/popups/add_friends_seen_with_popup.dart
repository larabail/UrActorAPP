import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/movie.dart';
import '../common/firebase/firestore_core.dart';
import '../common/widgets/app_dialog.dart';
import '../common/widgets/friend_picker.dart';

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
    return AppDialog(
      title: 'Add Friends',
      actions: [
        AppDialogAction(
          label: 'Cancel',
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: 'Apply',
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: _apply,
        ),
      ],
      child: FriendPicker(
        friendIds: List<String>.from(currentUser.friends),
        selected: selectedFriends,
        onChanged: (friendId, value) {
          setState(() => selectedFriends[friendId] = value);
        },
      ),
    );
  }

  Future<void> _apply() async {
    String id = widget.movie.id;
    FirebaseFirestore firestore = FirestoreCore.db;
    for (String friend in selectedFriends.keys.toList()) {
      await FirestoreCore.updateDocument(friend, "Movies", {
        'Seen': FieldValue.arrayUnion([id]),
      });
      await FirestoreCore.updateDocument(friend, "Seen", {
        'Movies': FieldValue.arrayUnion([id]),
      });
      if (currentUser.seenWith.containsKey(friend) &&
          !currentUser.seenWith[friend]["Movies"].contains(id.toString())) {
        currentUser.seenWith[friend]["Movies"].add(id.toString());
      } else if (!currentUser.seenWith.containsKey(friend)) {
        currentUser.seenWith[friend] = {"Movies": [], "TVShows": []};
        currentUser.seenWith[friend]["Movies"].add(id.toString());
      }
      DocumentReference userDoc2 = firestore.collection(friend).doc("SeenWith");
      Map<String, dynamic> item = {};
      List<dynamic> watchedWithList = [currentUser.uid];
      item[id] = watchedWithList;
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userDoc2);

        if (!snapshot.exists) {
          throw Exception("Document does not exist!");
        }
        // Guarded above, so transaction.update below is safe.

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

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
                  id: {"friends": watchedWithList},
                },
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
      // Guarded above, so transaction.update below is safe.

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

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
                id: {"friends": watchedWithList},
              },
            },
            SetOptions(merge: true));
      }
    }).catchError((error) {
      debugPrint("Failed to update document: $error");
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
