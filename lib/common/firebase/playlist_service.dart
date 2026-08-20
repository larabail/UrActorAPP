import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class PlaylistService {
  /// Every uid appearing in a playlist's `Users` field.
  ///
  /// `Users` is a list of single-key maps ({uid: role}), which Firestore
  /// cannot query for membership: `arrayContains` matches whole elements, and
  /// the role is part of the element, so you cannot ask "is this uid here"
  /// without already knowing their role. `memberUids` is the flat projection
  /// that makes the query possible.
  static List<String> memberUidsFrom(List? users) {
    if (users == null) return [];

    final uids = <String>[];
    for (final entry in users) {
      if (entry is! Map) continue;
      for (final key in entry.keys) {
        if (key is String && key.isNotEmpty && !uids.contains(key)) {
          uids.add(key);
        }
      }
    }
    uids.sort();
    return uids;
  }

  /// The playlists [uid] belongs to.
  ///
  /// This used to be done by downloading the entire Watchlists collection and
  /// filtering on the device, in eight separate copies of the same loop. The
  /// query below asks the server for the handful of documents that matter.
  ///
  /// `memberUids` is maintained by the `syncPlaylistMembers` Cloud Function,
  /// so lists last written by an older build are covered too.
  static Future<Map<String, dynamic>> fetchPlaylists(String uid) async {
    final snapshot = await FirestoreCore.db
        .collection("Watchlists")
        .where("memberUids", arrayContains: uid)
        .get();

    final playlists = <String, dynamic>{};
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data["id"] = doc.id;
      playlists[doc.id] = data;
    }
    return playlists;
  }

  /// Reloads the signed-in user's playlists from Firestore.
  static Future<void> refreshCurrentUserPlaylists() async {
    currentUser.playlists = await fetchPlaylists(currentUser.uid);
  }

  static Future<void> updateList(String id, String listId, List moviesinList,
      context, String type, bool operation) async {
    operation ? moviesinList.add(id) : moviesinList.remove(id);
    await FirestoreCore.updateDocument("Watchlists", listId.toString(),
        {type == "TVShows" ? "TV Shows" : type: moviesinList});
    await refreshCurrentUserPlaylists();
    Navigator.pop(context);
  }
}
