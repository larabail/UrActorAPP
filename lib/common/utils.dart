// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uractor/objects/Movie.dart';

import '../main.dart';
import '../popups/rating_popup.dart';
import 'constants.dart';

class Utils {
  static bool containsMap(List list, Map map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }

  static bool containsList(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == "Movies") {
        return true;
      }
    }
    return false;
  }

  static bool contains_non_type(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]).toString() == map[0].toString()) {
        return true;
      }
    }
    return false;
  }

  static bool contains(List list, List map, String type) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == type) {
        return true;
      }
    }
    return false;
  }
}

class FirebaseUtils {
  static Future<bool> deleteFromWatchedConfirmation(
      String id, BuildContext context, String type) async {
    var userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc(type);
    var seenUserDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Seen");
    DocumentSnapshot docSnapshot = await userDoc.get();
    DocumentSnapshot seenDocSnapshot = await seenUserDoc.get();
    if (seenDocSnapshot.exists) {
      Map<String, dynamic> data =
          seenDocSnapshot.data() as Map<String, dynamic>;
      List<dynamic> items = data[type] ?? [];
      items.remove(id);
      await seenUserDoc.update({type: items});
      currentUser.seen.removeWhere((pair) => pair[1] == id && pair[0] == type);
    }
    if (docSnapshot.exists) {
      Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> items = data['Seen'] ?? [];

      items.remove(id);
      await userDoc.update({'Seen': items});

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
    // Show the dialog like this
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

  static void incrementWatched(String value, String id) {
    if (value != "") {
      var userDoc = FirebaseFirestore.instance
          .collection(currentUser.uid)
          .doc("Rewatched");
      Map<String, int> doc = {};
      currentUser.rewatchedMovies[id] = int.parse(value);
      doc[id] = int.parse(value);
      userDoc.update(doc);
    }
  }

  static void incrementWatchedTV(String value, String id) {
    if (value != "") {
      var userDoc = FirebaseFirestore.instance
          .collection(currentUser.uid)
          .doc("RewatchedTV");
      Map<String, int> doc = {};
      currentUser.rewatchedTVShows[id] = int.parse(value);
      doc[id] = int.parse(value);
      userDoc.update(doc);
    }
  }

  static Future<void> updateProfileSections(Map newSections) async {
    var userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Settings");
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
    final userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc(type);
    final seenUserDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Seen");
    id = id.toString();
    await userDoc.update({
      'Seen': FieldValue.arrayUnion([id])
    });
    await seenUserDoc.update({
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
    final userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Favorites");
    await userDoc.update({
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
    final userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Watchlist");
    await userDoc.update({
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
      var document =
          FirebaseFirestore.instance.collection(tempUid).doc("Settings");
      var content = await document.get();
      var data = content.data() as Map;
      if (content.exists && data.containsKey('profile_photo')) {
        profilePhotos.add(data['profile_photo']);
      } else {
        profilePhotos.add("");
      }
    }
    return profilePhotos;
  }

  static void addToList(
      String id, String listId, List moviesinList, context, String type) async {
    moviesinList.add(id);
    final userDoc = FirebaseFirestore.instance
        .collection("Watchlists")
        .doc(listId.toString());
    if (type == "TVShows") {
      type = "TV Shows";
    }
    await userDoc.update({type: moviesinList});
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

  static void deleteFromList(
      String id, String listId, List moviesinList, context, String type) async {
    moviesinList.remove(id);
    final userDoc = FirebaseFirestore.instance
        .collection("Watchlists")
        .doc(listId.toString());
    if (type == "TVShows") {
      type = "TV Shows";
    }
    await userDoc.update({type: moviesinList});
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
    var userDoc = FirebaseFirestore.instance.collection(uid).doc("Calendar");
    if (dateRange != "") {
      DateTime startDate = DateTime.parse(dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        await userDoc.update({
          dateStr: FieldValue.arrayUnion([newData])
        });
      }
    } else {
      await userDoc.update({
        dateForMap: FieldValue.arrayUnion([newData])
      });
    }
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
    FirebaseFirestore db = FirebaseFirestore.instance;
    var userDoc = db.collection(currentUser.uid).doc("Calendar");
    Map<Object, Object> updatedCalendar = {};
    for (String key in currentUser.calendar.keys) {
      updatedCalendar[key] = currentUser.calendar[key];
    }
    await userDoc.update(updatedCalendar);
  }

  static Future<void> updateSeen(String type, String uid, String id) async {
    var userDoc = FirebaseFirestore.instance.collection(uid).doc(type);
    await userDoc.update({
      'Seen': FieldValue.arrayUnion([id])
    });
    userDoc = FirebaseFirestore.instance.collection(uid).doc("Seen");
    await userDoc.update({
      type: FieldValue.arrayUnion([id])
    });
  }

  static Future<void> updateSeenWith(
      String uid, Map friendsWatchedWith, String id, String type) async {
    var userDoc2 = FirebaseFirestore.instance.collection(uid).doc("SeenWith");
    Map<String, dynamic> item = {};
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    item[id] = watchedWithList;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userDoc2);
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
          transaction.update(userDoc2, {type: moviesMap});
        } else {
          watchedWithList.remove(uid);
          watchedWithList.add(currentUser.uid);
          moviesMap[id] = {"friends": watchedWithList};
          transaction.update(userDoc2, {type: moviesMap});
        }
      } else {
        transaction.set(
            userDoc2,
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

  static Future<void> updateRewatched(String uid, String id) async {
    var userDoc = FirebaseFirestore.instance.collection(uid).doc("Rewatched");
    DocumentSnapshot doc = await userDoc.get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data.containsKey(id)) {
        await userDoc.update({id: FieldValue.increment(1)});
      } else {
        await userDoc.update({id: 1});
      }
    }
  }

  static Future<void> updateRewatchedTV(String uid, String id) async {
    var userDoc = FirebaseFirestore.instance.collection(uid).doc("RewatchedTV");
    DocumentSnapshot doc = await userDoc.get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data.containsKey(id)) {
        await userDoc.update({id: FieldValue.increment(1)});
      } else {
        await userDoc.update({id: 1});
      }
    }
  }

  static Future<void> updateCurrentUserRewatched() async {
    var userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Rewatched");
    Map<Object, Object> updatedRewatched = {};
    for (String key in currentUser.rewatchedMovies.keys) {
      updatedRewatched[key] = currentUser.rewatchedMovies[key];
    }
    await userDoc.update(updatedRewatched);
  }

  static Future<void> updateCurrentUserSeenWith(String uid, String id,
      String type, Map friendsWatchedWith, List watchedWithList) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference userDoc2 =
        firestore.collection(currentUser.uid).doc("SeenWith");
    Map<String, dynamic> item = {};

    item[id] = watchedWithList;

    firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userDoc2);

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
        transaction.update(userDoc2, {type: moviesMap});
      } else {
        transaction.set(
            userDoc2,
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

class ApiUtils {
  static Future<dynamic> fetchOmdbData(String imdbId) async {
    final response = await http
        .get(Uri.parse('https://www.omdbapi.com/?i=$imdbId&apikey=***REMOVED***'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load OMDB data');
    }
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> fetchProviders(
      String movieId, String name, String country, String type) async {
    final response = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$WATCH_PROVIDERS_LINK'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load provider data');
    }

    var data = jsonDecode(response.body);
    List<dynamic> providers = [];
    if (data["results"].keys.contains(country) &&
        data["results"][country]['flatrate'] != null) {
      providers = data["results"][country]['flatrate'].map((provider) {
        return [provider['provider_name'], IMG_LINK + provider['logo_path']];
      }).toList();
    }
    return providers;
  }

  static Future<Map<String, dynamic>> fetchCreditsAndTrailer(
      String movieId, String name, String type) async {
    final creditsResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$CREDITS_LINK'));
    final trailerResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$VIDEOS_LINK'));

    if (creditsResponse.statusCode != 200 ||
        trailerResponse.statusCode != 200) {
      throw Exception('Failed to load credits or trailer data');
    }
    List countedCrew = [];
    List finalCrew = [];
    for (Map crewMember in jsonDecode(creditsResponse.body)["crew"]) {
      if (countedCrew.contains(crewMember["id"])) {
        for (Map credit in finalCrew) {
          if (credit["id"].toString() == crewMember["id"].toString()) {
            credit["job"] = "${credit["job"]} / ${crewMember["job"]}";
          }
        }
      } else {
        finalCrew.add(crewMember);
        countedCrew.add(crewMember["id"]);
      }
    }
    print("DEBUG: $finalCrew");

    Map<String, dynamic> data = {
      'cast': jsonDecode(creditsResponse.body)["cast"],
      'crew': finalCrew,
      'trailer': null
    };

    var trailerResults = jsonDecode(trailerResponse.body)['results'];
    var trailer = trailerResults.firstWhere(
        (element) =>
            element['site'] == "YouTube" && element['type'] == "Trailer",
        orElse: () => null);
    if (trailer != null) {
      data['trailer'] = trailer;
    }

    return data;
  }

  static Future<Map<String, dynamic>> fetchMovieDetails(
      String movieId, String name, String type) async {
    final movieResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$API_KEY'));
    if (movieResponse.statusCode != 200) {
      throw Exception('Failed to load movie details');
    }
    return jsonDecode(movieResponse.body);
  }

  static Future<Map<String, dynamic>> fetchAdditionalMovieData(
      Map json, String movieId, String name, String type) async {
    Map<String, dynamic> additionalData = {};

    var imdbId = json['imdb_id'];
    if (type != "movie") {
      final response2 = await http
          .get(Uri.parse('$TV_SHOW_LINK$movieId-$name$EXTERNAL_IDS_LINK'));
      if (response2.statusCode == 200) {
        imdbId = jsonDecode(response2.body)['imdb_id'];
      }
    }
    if (imdbId != null) {
      var omdbData = await fetchOmdbData(imdbId);
      additionalData['imdb_rating'] =
          omdbData["imdbRating"] != "N/A" ? omdbData["imdbRating"] : "0.0";
      additionalData['year'] = omdbData['Year'] ?? "None";
    } else {
      additionalData['imdb_rating'] = "0.0";
      additionalData['year'] = "None";
    }

    additionalData['providers'] =
        await fetchProviders(movieId, name, currentUser.country, type);
    additionalData.addAll(await fetchCreditsAndTrailer(movieId, name, type));

    return additionalData;
  }

  static List<dynamic> processSeenDates(
      Map calendar, String movieId, String type) {
    List<dynamic> seenDates = [];
    calendar.forEach((key, movies) {
      movies
          .where((movie) => ((movie['id'] == movieId) &&
              (movie.containsKey("type")
                  ? movie["type"] == type
                  : type == "movie"
                      ? true
                      : false)))
          .forEach((movie) {
        seenDates.add([key, movie["friends"]]);
      });
    });
    seenDates
        .sort((a, b) => DateTime.parse(b[0]).compareTo(DateTime.parse(a[0])));
    return seenDates;
  }

  static Future<List> getUpcomingMovies() async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    DateTime oneMonthLater = DateTime(now.year, now.month + 1, now.day);
    if (now.month == 12) {
      oneMonthLater = DateTime(now.year + 1, 1, now.day);
    }
    while (oneMonthLater.month != ((now.month % 12) + 1)) {
      oneMonthLater = DateTime(
          oneMonthLater.year, oneMonthLater.month, oneMonthLater.day - 1);
    }

    String formattedDateOneMonth =
        DateFormat('yyyy-MM-dd').format(oneMonthLater);
    final responseUpcomingMovies = await http.get(Uri.parse(
        "https://api.themoviedb.org/3/discover/movie$API_KEY&include_adult=false&include_video=false&language=en-US&page=1&sort_by=popularity.desc&with_release_type=2|3&release_date.gte=$formattedDate&release_date.lte=$formattedDateOneMonth"));
    List upcomingMovies = [];
    if (responseUpcomingMovies.statusCode == 200) {
      final upcomingMoviesJson = jsonDecode(responseUpcomingMovies.body);
      for (Map movie in upcomingMoviesJson["results"]) {
        Movie tempMovie = Movie(
            id: movie["id"].toString(),
            title: movie["title"],
            coverPhoto: movie["poster_path"]);
        upcomingMovies.add(tempMovie);
      }
    }
    return upcomingMovies;
  }

  static Future<List> searchData(searchTermActor) async {
    String searchLink = "";
    if (searchTermActor != "") {
      searchLink =
          '$SEARCH_BY_NAME_MULTI_LINK${searchTermActor.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['results'];
      }
    }
    return [];
  }

  static Future<List> searchMovies(String searchTerm) async {
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$SEARCH_BY_NAME_MOVIE_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['results'];
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      return [];
    }
  }

  static Future<List> searchTvShows(String searchTerm) async {
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$SEARCH_BY_NAME_TV_SHOW_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        return json['results'];
      } else {
        throw Exception('Failed to load tv show details');
      }
    } else {
      return [];
    }
  }
}
