import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/Media.dart';

class SocialService {
  /// Updates the list of friends a user watched a media item with, stored in the SeenWith document.
  /// @param uid The user ID.
  /// @param friendsWatchedWith A map of friends and their selection state.
  /// @param id The media ID.
  /// @param type The media type.
  static Future<void> updateSeenWith(
      String uid, Map friendsWatchedWith, String id, String type) async {
    var seenWithDoc = await FirestoreCore.getDocument(uid, "SeenWith");
    Map<String, dynamic> item = {};
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    item[id] = watchedWithList;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(seenWithDoc);
      if (!snapshot.exists) {
        throw Exception("Document does not exist!");
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      if (data.containsKey(type) && data[type] is Map<String, dynamic>) {
        Map<String, dynamic> moviesMap = data[type];

        if (moviesMap.containsKey(id)) {
          List existingList = moviesMap[id]["friends"];
          for (String person in watchedWithList) {
            if (!existingList.contains(person) && person != uid) {
              existingList.add(person);
            }
          }
          if (!existingList.contains(currentUser.uid)) {
            existingList.add(currentUser.uid);
          }
          moviesMap[id] = {"friends": existingList};
          transaction.update(seenWithDoc, {type: moviesMap});
        } else {
          watchedWithList.remove(uid);
          watchedWithList.add(currentUser.uid);
          moviesMap[id] = {"friends": watchedWithList};
          transaction.update(seenWithDoc, {type: moviesMap});
        }
      } else {
        transaction.set(
            seenWithDoc,
            {
              type: {
                id: {"friends": watchedWithList}
              }
            },
            SetOptions(merge: true));
      }
    }).catchError((error) {
      print("Failed to update document: $error");
    });
  }

  /// Updates the SeenWith document for the current user with selected friends.
  /// @param uid The user ID.
  /// @param id The media ID.
  /// @param type The media type.
  /// @param friendsWatchedWith A map of friend IDs with selection.
  /// @param watchedWithList A list of user IDs who watched together.
  static Future<void> updateCurrentUserSeenWith(String uid, String id,
      String type, Map friendsWatchedWith, List watchedWithList) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference seenWithDoc =
        await FirestoreCore.getDocument(currentUser.uid, "SeenWith");
    Map<String, dynamic> item = {};

    item[id] = watchedWithList;

    firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(seenWithDoc);

      if (!snapshot.exists) {
        throw Exception("Document does not exist!");
      }
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey(type) && data[type] is Map<String, dynamic>) {
        Map<String, dynamic> moviesMap = data[type];

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
        transaction.update(seenWithDoc, {type: moviesMap});
      } else {
        transaction.set(
            seenWithDoc,
            {
              type: {
                id: {"friends": watchedWithList}
              }
            },
            SetOptions(merge: true));
      }
    }).catchError((error) {
      print("Failed to update document: $error");
    });
  }

  /// Finds friends who have seen a specific media item.
  /// @param uid The user ID.
  /// @param mediaItem The media item object.
  /// @param type The media type ("movie" or "TVShows").
  /// @return A map of friend usernames and their profile photo URLs.
  static Future<Map> friendsWhoHaveSeen(
      String uid, MediaItem mediaItem, String type) async {
    type = type == "movie" ? "Movies" : "TVShows";
    Map friends = {};
    Map friendsDocInfo = await FirestoreCore.getDocumentData(uid, "Friends");
    List allFriends = friendsDocInfo["data"]["friends"];
    for (String friendUid in allFriends) {
      Map friendSeenDocInfo =
          await FirestoreCore.getDocumentData(friendUid, type);
      Map itemsSeen = friendSeenDocInfo["data"];
      bool seen = itemsSeen.values.toList()[0].contains(mediaItem.id);
      if (seen) {
        Map friendsSettingDocInfo =
            await FirestoreCore.getDocumentData(friendUid, "Settings");
        String profilePhoto = friendsSettingDocInfo["data"]["profile_photo"];
        String username = friendsSettingDocInfo["data"]["username"];
        friends["$friendUid-$username"] = profilePhoto;
      }
    }
    return friends;
  }

  /// Checks if a media item is favorited by a user.
  /// @param mediaItem The media item.
  /// @param userUid The user ID.
  /// @param docName The Firestore document name.
  /// @param type The media type.
  /// @return True if the item is in the user's favorites.
  static Future<bool> favedBy(
      MediaItem mediaItem, String userUid, String docName, String type) async {
    Map docData = await FirestoreCore.getDocumentData(userUid, docName);
    Map mediaData = docData["data"];
    List favItems = mediaData[type];
    if (favItems.contains(mediaItem.id)) {
      return true;
    }
    return false;
  }
}
