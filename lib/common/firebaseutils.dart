import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../popups/rating_popup.dart';

class FirebaseUtils {
  static Future<Map> getDocumentData(String uid, String docName) async {
    var snapshot = FirebaseFirestore.instance.collection(uid).doc(docName);
    DocumentSnapshot doc = await snapshot.get();
    Map data = {};
    if (doc.exists) {
      data = doc.data() as Map;
    }
    return {"snapshot": snapshot, "doc": doc, "data": data};
  }

  static Future<DocumentReference> getDocument(
      String uid, String docName) async {
    DocumentReference userDoc =
        FirebaseFirestore.instance.collection(uid).doc(docName);
    return userDoc;
  }

  static Future<void> updateDocument(String uid, String docName, data) async {
    DocumentReference doc = await getDocument(uid, docName);
    doc.update(data);
  }

  static Future<bool> deleteFromWatchedConfirmation(
      String id, BuildContext context, String type) async {
    Map typeDocData = await getDocumentData(currentUser.uid, type);
    DocumentReference typeSnapshot = typeDocData["snapshot"];
    DocumentSnapshot typeDoc = typeDocData["doc"];
    Map typeData = typeDocData["data"];

    Map seenDocData = await getDocumentData(currentUser.uid, "Seen");
    DocumentReference seenSnapshot = seenDocData["snapshot"];
    DocumentSnapshot seenDoc = seenDocData["doc"];
    Map seenData = seenDocData["data"];

    if (seenDoc.exists) {
      List<dynamic> items = seenData[type] ?? [];
      items.remove(id);
      await seenSnapshot.update({type: items});
      currentUser.seen.removeWhere((pair) => pair[1] == id && pair[0] == type);
    }
    if (typeDoc.exists) {
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

  static Future<bool> writeReview(id, type, context) {
    reviewId = id.toString();
    reviewType = type;
    Completer<bool> completer = Completer();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    ).then((value) => completer.complete(true));
    return completer.future;
  }

  static Future<bool> editReview(id, type, context) {
    reviewId = id.toString();
    reviewType = type;

    Completer<bool> completer = Completer();
    if (type == "Movies") {
      reviewInfo = currentUser.reviews[id.toString()];
    } else {
      reviewInfo = currentUser.tvShowReviews[id.toString()];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    ).then((value) => completer.complete(true));
    return completer.future;
  }

  static void incrementWatched(
      String uid, String value, String id, String type) async {
    if (value != "") {
      currentUser.rewatchedMovies[id] = int.parse(value);
      await updateDocument(uid, type == "movie" ? "Rewatched" : "RewatchedTV",
          {id: int.parse(value)});
    }
  }

  static Future<void> updateProfileSections(Map newSections) async {
    var userDoc = await getDocument(currentUser.uid, "Settings");
    currentUser.settings["profileSections"] = newSections;
    userDoc.update(currentUser.settings as Map<String, dynamic>);
  }

  static Future<bool> deleteReview(id, type, context) async {
    reviewInfo = {};
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews") {
          Map reviewsMap = doc.data() as Map;
          List reviewsInList = reviewsMap[type] as List;
          List tempReviewsInList = [];
          for (var element in reviewsInList) {
            element = element as Map;
            if (element.keys.toList()[0].toString() != id.toString()) {
              tempReviewsInList.add(element);
            }
          }
          final userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Reviews");
          await userDoc.update({type: tempReviewsInList});
          if (type == "Movies") {
            currentUser.reviews = {};
          } else {
            currentUser.tvShowReviews = {};
          }

          currentUser.allReviews.removeWhere((element) => element[0] == type);
          for (var element in tempReviewsInList) {
            element = element as Map;
            if (type == "Movies") {
              currentUser.reviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            } else {
              currentUser.tvShowReviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            }
            currentUser.allReviews += [
              [
                type,
                element.keys.toList()[0],
                element[element.keys.toList()[0]]
              ]
            ];
          }
        }
      }
    });
    return true;
  }

  static Future<bool> markWatched(String id, String title, int runtime,
      double rating, BuildContext context, String type) async {
    final typeDoc = await getDocument(currentUser.uid, type);
    final seenDoc = await getDocument(currentUser.uid, "Seen");
    id = id.toString();
    await typeDoc.update({
      'Seen': FieldValue.arrayUnion([id])
    });
    await seenDoc.update({
      type: FieldValue.arrayUnion([id])
    });
    List w;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) async {
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
      });
    });
    if (type == "Movies") {
      final today = DateTime.now();
      final snapshot =
          await FirebaseFirestore.instance.collection(currentUser.uid).get();
      for (var doc in snapshot.docs) {
        if (doc.id == 'Calendar') {
          if (!currentUser.dontAskCalendar) {
            await addtoCalendar(id, title, runtime, rating, today, context);
          }
        }
      }
    }

    return true;
  }

  static Future<bool> addtoCalendar(String id, String title, int runtime,
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

      final userDoc = FirebaseFirestore.instance
          .collection(currentUser.uid)
          .doc('Calendar');
      await userDoc.update(myObject);
      currentUser.calendar = {};
      await FirebaseFirestore.instance
          .collection(currentUser.uid)
          .get()
          .then((QuerySnapshot querySnapshot) {
        querySnapshot.docs.forEach((doc) async {
          if (doc.id == "Calendar") {
            currentUser.calendar = doc.data() as Map;
          }
        });
      });
      return true;
    }
    return false;
  }

  static Future<bool> favorite(String id, context, String type) async {
    final favoritesDoc = await getDocument(currentUser.uid, "Favorites");
    await favoritesDoc.update({
      type: FieldValue.arrayUnion([id])
    });
    if (type == "Movies") {
      currentUser.favMovies = [];
    } else {
      currentUser.favTVShows = [];
    }
    await FirebaseFirestore.instance
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

  static Future<bool> unfavorite(String id, context, String type) async {
    await FirebaseFirestore.instance
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
          final userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Favorites");
          await userDoc.update({type: movieInFavs});
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

  static Future<bool> bookmark(String id, context, String type) async {
    final watchlistDoc = await getDocument(currentUser.uid, "Watchlist");
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

  static Future<List<String>> getProfilePhotos(List uids) async {
    List<String> profilePhotos = [];
    for (String tempUid in uids) {
      Map settingsDocData = await getDocumentData(tempUid, "Settings");
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

  static void updateList(String id, String listId, List moviesinList, context,
      String type, bool operation) async {
    operation ? moviesinList.add(id) : moviesinList.remove(id);
    await updateDocument("Watchlists", listId.toString(),
        {type == "TVShows" ? "TV Shows" : type: moviesinList});
    currentUser.playlists = {};
    await FirebaseFirestore.instance
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

  static Future<void> updateCalendar(
      String dateRange, String uid, Map newData, String dateForMap) async {
    if (dateRange != "") {
      DateTime startDate = DateTime.parse(dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        await updateDocument(uid, "Calendar", {
          dateStr: FieldValue.arrayUnion([newData])
        });
      }
    } else {
      await updateDocument(uid, "Calendar", {
        dateForMap: FieldValue.arrayUnion([newData])
      });
    }
  }

  static Future<void> deleteFromCalendar(
      String uid, String id, String title, String date) async {
    Map calendarDocInfo = await getDocumentData(uid, "Calendar");
    FirebaseFirestore.instance.collection(uid).doc("Calendar");
    Map calendarData = calendarDocInfo["data"];
    Map<Object, Object> updatedCalendar = {};
    for (String key in calendarData.keys) {
      if (key == date) {
        if (calendarData[key].length == 1) {
          var movie = calendarData[key][0];
          if (movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString()) {
            calendarData[key] = [];
          }
        } else {
          List movies = calendarData[key];

          int movieIndex = movies.indexWhere((movie) =>
              movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString());

          if (movieIndex != -1) {
            movies.removeAt(movieIndex);
          }
          break;
        }
      }
    }
    for (String key in calendarData.keys) {
      if (calendarData[key].isNotEmpty) {
        updatedCalendar[key] = calendarData[key];
      } else {
        updatedCalendar[key] = [];
      }
    }
    await updateDocument(uid, "Calendar", updatedCalendar);
  }

  static void updateCurrentUserCalendar(
      String dateRange, Map newData, String dateForMap) {
    if (dateRange != "") {
      DateTime startDate = DateTime.parse(dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        if (currentUser.calendar.keys.toList().contains(dateStr)) {
          currentUser.calendar[dateStr].add(newData);
        } else {
          currentUser.calendar[dateStr] = [
            newData,
          ];
        }
      }
    } else {
      if (currentUser.calendar.keys.toList().contains(dateForMap)) {
        currentUser.calendar[dateForMap].add(newData);
      } else {
        currentUser.calendar[dateForMap] = [
          newData,
        ];
      }
    }
  }

  // Can I add this to the updateCurrentUserCalendar function? Instead of making it a whole new one?
  static Future<void> updateCurrentUserCalendarDocument() async {
    Map<Object, Object> updatedCalendar = {};
    for (String key in currentUser.calendar.keys) {
      updatedCalendar[key] = currentUser.calendar[key];
    }
    await updateDocument(currentUser.uid, "Calendar", updatedCalendar);
  }

  static Future<void> updateSeen(String type, String uid, String id) async {
    await updateDocument(uid, type, {
      'Seen': FieldValue.arrayUnion([id])
    });
    await updateDocument(uid, "Seen", {
      type: FieldValue.arrayUnion([id])
    });
  }

  static Future<void> updateSeenWith(
      String uid, Map friendsWatchedWith, String id, String type) async {
    var seenWithDoc = await getDocument(uid, "SeenWith");
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

  static Future<void> updateRewatched(
      String uid, String id, String type) async {
    Map info = await getDocumentData(
        uid, type == "movie" ? "Rewatched" : "RewatchedTV");
    DocumentReference rewatchedDoc = info["snapshot"];
    Map data = info["data"];
    if (data.containsKey(id)) {
      await rewatchedDoc.update({id: FieldValue.increment(1)});
    } else {
      await rewatchedDoc.update({id: 1});
    }
  }

  static Future<void> setRewatched(
      String uid, String id, int value, String type) async {
    Map info = await getDocumentData(
        uid, type == "movie" ? "Rewatched" : "RewatchedTV");
    DocumentReference rewatchedDoc = info["snapshot"];
    Map data = info["data"];
    if (data.containsKey(id)) {
      await rewatchedDoc.update({id: value});
    } else {
      await rewatchedDoc.update({id: 1});
    }
  }

  static Future<void> updateCurrentUserRewatched() async {
    Map<Object, Object> updatedRewatched = {};
    for (String key in currentUser.rewatchedMovies.keys) {
      updatedRewatched[key] = currentUser.rewatchedMovies[key];
    }
    await updateDocument(currentUser.uid, "Rewatched", updatedRewatched);
  }

  static Future<void> updateCurrentUserSeenWith(String uid, String id,
      String type, Map friendsWatchedWith, List watchedWithList) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference seenWithDoc =
        await getDocument(currentUser.uid, "SeenWith");
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
}
