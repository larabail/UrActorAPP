import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class WatchlistService {
  /// Removes a media item from the user's watchlist and updates local cache.
  /// @param id The media ID.
  /// @param context The UI context.
  /// @param type The media type (Movies or TVShows).
  /// @return True if the operation succeeded.
  static Future<bool> bookmark(String id, context, String type) async {
    final watchlistDoc =
        await FirestoreCore.getDocument(currentUser.uid, "Watchlist");
    await watchlistDoc.update({
      type: FieldValue.arrayUnion([id])
    });
    if (type == "Movies") {
      currentUser.watchlist = [];
    } else {
      currentUser.watchlistTVShows = [];
    }
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Watchlist") {
          Map watchlistAll = doc.data() as Map;
          watchlistAll[type].forEach((element) {
            if (type == "Movies") {
              currentUser.watchlist += [
                [type, element]
              ];
            } else {
              currentUser.watchlistTVShows += [
                [type, element]
              ];
            }
          });
        }
      }
    });
    return true;
  }

  /// Retrieves the profile photos for a list of user IDs.
  /// @param uids A list of user UIDs.
  /// @return A list of profile photo URLs.
  static Future<bool> unbookmark(String id, context, String type) async {
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Watchlist") {
          Map watchlistAll = doc.data() as Map;
          List movieInWatchlist = watchlistAll[type];
          int index = movieInWatchlist.indexOf(id);
          if (index > -1) {
            movieInWatchlist.removeAt(index);
          }
          final userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Watchlist");
          await userDoc.update({type: movieInWatchlist});
          if (type == "Movies") {
            currentUser.watchlist = [];
          } else {
            currentUser.watchlistTVShows = [];
          }
          watchlistAll[type].forEach((element) {
            if (type == "Movies") {
              currentUser.watchlist += [
                [type, element]
              ];
            } else {
              currentUser.watchlistTVShows += [
                [type, element]
              ];
            }
          });
        }
      }
    });
    return true;
  }
}
