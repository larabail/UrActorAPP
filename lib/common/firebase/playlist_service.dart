import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class PlaylistService {
  static void updateList(String id, String listId, List moviesinList, context,
      String type, bool operation) async {
    operation ? moviesinList.add(id) : moviesinList.remove(id);
    await FirestoreCore.updateDocument("Watchlists", listId.toString(),
        {type == "TVShows" ? "TV Shows" : type: moviesinList});
    currentUser.playlists = {};
    await FirestoreCore.db
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map keysOfDoc = doc.data() as Map;
        List users = keysOfDoc['Users'] as List;
        for (var element in users) {
          Map el = element as Map;
          if (el.keys.contains(currentUser.uid)) {
            currentUser.playlists[doc.id] = doc.data();
          }
        }
      }
    });
    Navigator.pop(context);
  }
}
