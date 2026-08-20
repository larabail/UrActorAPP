import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/firestore_core.dart';

import '../../main.dart';

class FirebaseUtils {
  /// Updates the profile sections in the user's settings document.
  /// @param newSections A map of the updated profile sections.
  static Future<void> updateProfileSections(Map newSections) async {
    currentUser.settings["profileSections"] = newSections;
    await FirestoreCore.updateDocument(
        currentUser.uid, "Settings", currentUser.settings);
  }

  /// Retrieves the profile photos for a list of user IDs.
  /// @param uids A list of user UIDs.
  /// @return A list of profile photo URLs.
  static Future<List<String>> getProfilePhotos(List uids) async {
    List<String> profilePhotos = [];
    for (String tempUid in uids) {
      Map settingsDocData =
          await FirestoreCore.getDocumentData(tempUid, "Settings");
      DocumentSnapshot settingsDoc = settingsDocData["doc"];
      Map data = settingsDocData["data"];
      if (settingsDoc.exists && data.containsKey('profile_photo')) {
        profilePhotos.add(data['profile_photo']);
      } else {
        profilePhotos.add("");
      }
    }
    return profilePhotos;
  }
}
