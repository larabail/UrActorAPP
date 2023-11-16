import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../movie_result.dart';
import '../rating_popup.dart';

class Utils {
  static bool containsMap(
      List<Map<String, dynamic>> list, Map<String, dynamic> map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }
}

class FirebaseUtils {
  static Future<void> deleteFromWatchedConfirmation(
      String id, BuildContext context) async {
    // Display a dialog box for confirmation. You will have to create a custom dialog for this.
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Delete from watched?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed) {
      List w;
      await FirebaseFirestore.instance
          .collection(uid)
          .get()
          .then((QuerySnapshot querySnapshot) {
        querySnapshot.docs.forEach((doc) async {
          if (doc.id == "Movies") {
            Map movies_result = doc.data() as Map;
            w = movies_result["Seen"];
            int index = w.indexOf(id);

            if (index > -1) {
              w.removeAt(index);
            }
            var userDoc =
                FirebaseFirestore.instance.collection(uid).doc("Movies");
            await userDoc.update({'Seen': w});
            seenMovies = [];
            for (var element in w) {
              seenMovies += [
                ["Movies", element]
              ];
            }
          }
        });
      });
    }
  }

  static void writeReview(id, context) {
    reviewId = id.toString();
    // Show the dialog like this
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    );
  }

  static void editReview(id, context) {
    reviewId = id.toString();
    reviewInfo = reviews[id.toString()];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    );
  }

  static void incrementWatched(String value, String id) {
    if (value != "") {
      var userDoc = FirebaseFirestore.instance.collection(uid).doc("Rewatched");
      Map<String, int> doc = {};
      rewatchedMovies[id] = int.parse(value);
      doc[id] = int.parse(value);
      userDoc.update(doc);
    }
  }

  static Future<void> deleteReview(id, context) async {
    reviews.remove(id.toString());
    reviewInfo = {};
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews") {
          Map allreviews = doc.data() as Map;
          List reviewsInList = allreviews["Seen"] as List;
          List tempReviewsInList = [];
          for (var element in reviewsInList) {
            element = element as Map;
            if (element.keys.toList()[0].toString() != id.toString()) {
              tempReviewsInList.add(element);
            }
          }
          final userDoc =
              FirebaseFirestore.instance.collection(uid).doc("Reviews");
          await userDoc.update({'Seen': tempReviewsInList});
          reviews = {};
          for (var element in tempReviewsInList) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          }
        }
      }
    });
  }

  static void markWatched(String id, String title, int runtime, double rating,
      BuildContext context) async {
    final userDoc = FirebaseFirestore.instance.collection(uid).doc('Movies');
    id = id.toString();
    await userDoc.update({
      'Seen': FieldValue.arrayUnion([id])
    });
    // store id in shared preferences or another way
    List w;
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) async {
        if (doc.id == "Movies") {
          Map movies_result = doc.data() as Map;
          w = movies_result["Seen"];
          seenMovies = [];
          for (var element in w) {
            seenMovies += [
              ["Movies", element]
            ];
          }
        }
      });
    });

    final today = DateTime.now();

    final snapshot = await FirebaseFirestore.instance.collection(uid).get();
    for (var doc in snapshot.docs) {
      if (doc.id == 'Calendar') {
        if (!dontAskCalendar) {
          addtoCalendar(id, title, runtime, rating, today, context);
        }
      }
    }
  }

  static void addtoCalendar(String id, String title, int runtime,
      double imdbRating, DateTime today, BuildContext context) async {
    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Did you watch this movie today?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed) {
      final myObject = {
        today.toString().split(" ")[0]: FieldValue.arrayUnion([
          {'id': id, 'title': title, 'runtime': runtime, 'rating': imdbRating}
        ])
      };

      final userDoc =
          FirebaseFirestore.instance.collection(uid).doc('Calendar');
      await userDoc.update(myObject);
      calendar = {};
      await FirebaseFirestore.instance
          .collection(uid)
          .get()
          .then((QuerySnapshot querySnapshot) {
        querySnapshot.docs.forEach((doc) async {
          if (doc.id == "Calendar") {
            calendar = doc.data() as Map;
          }
        });
      });
    }
  }

  static void favorite(String id, context) async {
    final userDoc = FirebaseFirestore.instance.collection(uid).doc("Favorites");
    await userDoc.update({
      'Movies': FieldValue.arrayUnion([id])
    });
    favMovies = [];
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Favorites") {
          Map allFavs = doc.data() as Map;
          allFavs["Movies"].forEach((element) {
            favMovies += [
              ["Movies", element]
            ];
          });
        }
      }
    });
  }

  static void unfavorite(String id, context) async {
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Favorites") {
          Map allFavs = doc.data() as Map;
          List movieInFavs = allFavs["Movies"];
          int index = movieInFavs.indexOf(id);
          if (index > -1) {
            movieInFavs.removeAt(index);
          }
          final userDoc =
              FirebaseFirestore.instance.collection(uid).doc("Favorites");
          await userDoc.update({'Movies': movieInFavs});
          favMovies = [];
          allFavs["Movies"].forEach((element) {
            favMovies += [
              ["Movies", element]
            ];
          });
        }
      }
    });
  }

  static void bookmark(String id, context) async {
    final userDoc = FirebaseFirestore.instance.collection(uid).doc("Watchlist");
    await userDoc.update({
      'Movies': FieldValue.arrayUnion([id])
    });
    watchlist = [];
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Watchlist") {
          Map watchlistAll = doc.data() as Map;
          watchlistAll["Movies"].forEach((element) {
            watchlist += [
              ["Movies", element]
            ];
          });
        }
      }
    });
  }

  static void unbookmark(String id, context) async {
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Watchlist") {
          Map watchlistAll = doc.data() as Map;
          List movieInWatchlist = watchlistAll["Movies"];
          int index = movieInWatchlist.indexOf(id);
          if (index > -1) {
            movieInWatchlist.removeAt(index);
          }
          final userDoc =
              FirebaseFirestore.instance.collection(uid).doc("Watchlist");
          await userDoc.update({'Movies': movieInWatchlist});
          watchlist = [];
          watchlistAll["Movies"].forEach((element) {
            watchlist += [
              ["Movies", element]
            ];
          });
        }
      }
    });
  }

  static Future<List<String>> getProfilePhotos(List uids) async {
    List<String> profilePhotos = [];

    for (String tempUid in uids) {
      var document = await FirebaseFirestore.instance
          .collection(tempUid)
          .doc("Settings")
          .get();
      if (document.exists && document.data()!.containsKey('profile_photo')) {
        print(tempUid);
        profilePhotos.add(document.data()!['profile_photo']);
      } else {
        profilePhotos.add(""); //eplace with your default image URL
      }
    }

    return profilePhotos;
  }

  static void addToList(
      String id, String listId, List moviesinList, context) async {
    moviesinList.add(id);
    final userDoc = FirebaseFirestore.instance
        .collection("Watchlists")
        .doc(listId.toString());
    await userDoc.update({'Movies': moviesinList});
    playlists = {};
    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map keysOfDoc = doc.data() as Map;
        List users = keysOfDoc['Users'] as List;
        for (var element in users) {
          Map el = element as Map;
          if (el.keys.contains(uid)) {
            playlists[doc.id] = doc.data();
          }
        }
      }
    });
    Navigator.pop(context);
  }

  static void deleteFromList(
      String id, String listId, List moviesinList, context) async {
    moviesinList.remove(id);
    final userDoc = FirebaseFirestore.instance
        .collection("Watchlists")
        .doc(listId.toString());
    await userDoc.update({'Movies': moviesinList});
    playlists = {};
    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map keysOfDoc = doc.data() as Map;
        List users = keysOfDoc['Users'] as List;
        for (var element in users) {
          Map el = element as Map;
          if (el.keys.contains(uid)) {
            playlists[doc.id] = doc.data();
          }
        }
      }
    });
    Navigator.pop(context);
  }
}
