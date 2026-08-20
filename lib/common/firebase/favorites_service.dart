import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class FavoritesService {
  /// Adds a media item to the user's list of favorites in Firestore and updates local state.
  /// @param id The media ID.
  /// @param context The UI context.
  /// @param type The media type (Movies or TVShows).
  /// @return True if the operation succeeded.
  static Future<bool> favorite(String id, context, String type) async {
    await FirestoreCore.updateDocument(currentUser.uid, "Favorites", {
      type: FieldValue.arrayUnion([id])
    });
    if (type == "Movies") {
      currentUser.favMovies = [];
    } else {
      currentUser.favTVShows = [];
    }
    await FirestoreCore.db
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Favorites") {
          Map allFavs = doc.data() as Map;
          allFavs[type].forEach((element) {
            if (type == "Movies") {
              currentUser.favMovies += [
                [type, element]
              ];
            } else {
              currentUser.favTVShows += [
                [type, element]
              ];
            }
          });
        }
      }
    });
    return true;
  }

  /// Removes a media item from the user's list of favorites in Firestore and updates local state.
  /// @param id The media ID.
  /// @param context The UI context.
  /// @param type The media type (Movies or TVShows).
  /// @return True if the operation succeeded.
  static Future<bool> unfavorite(String id, context, String type) async {
    await FirestoreCore.db
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Favorites") {
          Map allFavs = doc.data() as Map;
          List movieInFavs = allFavs[type];
          int index = movieInFavs.indexOf(id);
          if (index > -1) {
            movieInFavs.removeAt(index);
          }
          await FirestoreCore.updateDocument(
              currentUser.uid, "Favorites", {type: movieInFavs});
          if (type == "Movies") {
            currentUser.favMovies = [];
          } else {
            currentUser.favTVShows = [];
          }
          allFavs[type].forEach((element) {
            if (type == "Movies") {
              currentUser.favMovies += [
                [type, element]
              ];
            } else {
              currentUser.favTVShows += [
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
