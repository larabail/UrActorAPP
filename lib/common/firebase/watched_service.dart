import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/calendar_service.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class WatchedService {
  /// Marks a media item as watched and optionally adds it to the calendar.
  /// @param id The media ID.
  /// @param title The media title.
  /// @param runtime The runtime of the media.
  /// @param rating The rating given.
  /// @param context The UI context.
  /// @param type The media type.
  /// @return True if the item was successfully marked.
  static Future<bool> markWatched(String id, String title, int runtime,
      double rating, BuildContext context, String type) async {
    id = id.toString();
    await FirestoreCore.updateDocument(currentUser.uid, type, {
      'Seen': FieldValue.arrayUnion([id])
    });
    await FirestoreCore.updateDocument(currentUser.uid, "Seen", {
      type: FieldValue.arrayUnion([id])
    });
    List w;
    await FirestoreCore.db
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == type) {
          Map moviesResult = doc.data() as Map;
          w = moviesResult["Seen"];
          if (type == "Movies") {
            currentUser.seenMovies = [];
          } else {
            currentUser.seenTVShows = [];
          }
          currentUser.seen = [];
          for (var element in w) {
            if (type == "Movies") {
              currentUser.seenMovies += [
                [type, element]
              ];
              currentUser.seen += [
                [type, element]
              ];
            } else {
              currentUser.seenTVShows += [
                [type, element]
              ];
              currentUser.seen += [
                [type, element]
              ];
            }
          }
        }
      }
    });
    if (type == "Movies") {
      final today = DateTime.now();
      final snapshot =
          await FirestoreCore.db.collection(currentUser.uid).get();
      if (!context.mounted) return true;
      for (var doc in snapshot.docs) {
        if (doc.id == 'Calendar') {
          if (!currentUser.dontAskCalendar) {
            await CalendarService.addtoCalendar(
                id, title, runtime, rating, today, context);
          }
        }
      }
    }

    return true;
  }

  /// Adds a media item to the user's "Seen" list in Firestore.
  /// @param type The media type.
  /// @param uid The user ID.
  /// @param id The media ID.
  static Future<void> updateSeen(String type, String uid, String id) async {
    await FirestoreCore.updateDocument(uid, type, {
      'Seen': FieldValue.arrayUnion([id])
    });
    await FirestoreCore.updateDocument(uid, "Seen", {
      type: FieldValue.arrayUnion([id])
    });
  }

  /// Increments the rewatched count for a given media item in Firestore.
  /// @param uid The user ID.
  /// @param id The media ID.
  /// @param type The media type.
  static Future<void> updateRewatched(
      String uid, String id, String type) async {
    Map info = await FirestoreCore.getDocumentData(
        uid, type == "movie" ? "Rewatched" : "RewatchedTV");
    Map data = info["data"];
    if (data.containsKey(id)) {
      await FirestoreCore.updateDocument(uid,
          type == "movie" ? "Rewatched" : "RewatchedTV",
          {id: FieldValue.increment(1)});
    } else {
      await FirestoreCore.updateDocument(
          uid, type == "movie" ? "Rewatched" : "RewatchedTV", {id: 1});
    }
  }

  /// Sets the rewatched count for a media item in Firestore.
  /// @param uid The user ID.
  /// @param id The media ID.
  /// @param value The new rewatch count value.
  /// @param type The media type.
  static Future<void> setRewatched(
      String uid, String id, int value, String type) async {
    Map info = await FirestoreCore.getDocumentData(
        uid, type == "movie" ? "Rewatched" : "RewatchedTV");
    Map data = info["data"];
    if (data.containsKey(id)) {
      await FirestoreCore.updateDocument(
          uid, type == "movie" ? "Rewatched" : "RewatchedTV", {id: value});
    } else {
      await FirestoreCore.updateDocument(
          uid, type == "movie" ? "Rewatched" : "RewatchedTV", {id: 1});
    }
  }

  /// Pushes the current user's rewatched movie count to Firestore.
  static Future<void> updateCurrentUserRewatched() async {
    Map<Object, Object> updatedRewatched = {};
    for (String key in currentUser.rewatchedMovies.keys) {
      updatedRewatched[key] = currentUser.rewatchedMovies[key];
    }
    await FirestoreCore.updateDocument(
        currentUser.uid, "Rewatched", updatedRewatched);
  }

  /// Deletes a watched item from the user's data and optionally removes it from friends' data as well.
  /// @param id The media ID.
  /// @param context The current UI context.
  /// @param type The media type (e.g., Movies, TVShows).
  /// @return True if deletion was successful.
  static Future<bool> deleteFromWatchedConfirmation(
      String id, BuildContext context, String type) async {
    Map typeDocData =
        await FirestoreCore.getDocumentData(currentUser.uid, type);
    DocumentReference typeSnapshot = typeDocData["snapshot"];
    DocumentSnapshot typeDoc = typeDocData["doc"];
    Map typeData = typeDocData["data"];

    Map seenDocData =
        await FirestoreCore.getDocumentData(currentUser.uid, "Seen");
    DocumentReference seenSnapshot = seenDocData["snapshot"];
    DocumentSnapshot seenDoc = seenDocData["doc"];
    Map seenData = seenDocData["data"];

    if (seenDoc.exists) {
      // Guarded by the exists check above, so `update` can't hit `not-found`
      // here; left as-is rather than converted for its own sake.
      List<dynamic> items = seenData[type] ?? [];
      items.remove(id);
      await seenSnapshot.update({type: items});
      currentUser.seen.removeWhere((pair) => pair[1] == id && pair[0] == type);
    }
    if (typeDoc.exists) {
      // Same reasoning as above: guarded by the exists check.
      List<dynamic> items = typeData['Seen'] ?? [];
      items.remove(id);
      await typeSnapshot.update({'Seen': items});
      currentUser.seen.removeWhere((pair) => pair[1] == id && pair[0] == type);
      if (type == "Movies") {
        currentUser.seenMovies.removeWhere((pair) => pair[1] == id);
      } else if (type == "TVShows") {
        currentUser.seenTVShows.removeWhere((pair) => pair[1] == id);
      }
    }
    return true;
  }

  /// Increments the rewatch count of a media item in Firestore.
  /// @param uid The user ID.
  /// @param value The new rewatch count as a string.
  /// @param id The media ID.
  /// @param type The media type (movie or TV).
  static void incrementWatched(
      String uid, String value, String id, String type) async {
    if (value != "") {
      currentUser.rewatchedMovies[id] = int.parse(value);
      await FirestoreCore.updateDocument(
          uid,
          type == "movie" ? "Rewatched" : "RewatchedTV",
          {id: int.parse(value)});
    }
  }
}
