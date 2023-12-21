import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uractor/objects/Movie.dart';

import '../main.dart';
import '../movie_result.dart';
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
    DocumentSnapshot docSnapshot = await userDoc.get();

    if (docSnapshot.exists) {
      Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> items = data['Seen'] ?? [];

      items.remove(id);
      await userDoc.update({'Seen': items});

      if (type == "Movies") {
        currentUser.seenMovies.removeWhere((pair) => pair[1] == id);
      } else if (type == "TVShows") {
        currentUser.seenTVShows.removeWhere((pair) => pair[1] == id);
      }
    }
    return true;
  }

  static Future<bool> writeReview(id, context) {
    reviewId = id.toString();
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

  static Future<bool> editReview(id, context) {
    reviewId = id.toString();

    Completer<bool> completer = Completer();
    reviewInfo = currentUser.reviews[id.toString()];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RatingDialog();
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

  static Future<bool> deleteReview(id, context) async {
    currentUser.reviews.remove(id.toString());
    reviewInfo = {};
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
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
          final userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Reviews");
          await userDoc.update({'Seen': tempReviewsInList});
          currentUser.reviews = {};
          for (var element in tempReviewsInList) {
            element = element as Map;
            currentUser.reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
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
    id = id.toString();
    await userDoc.update({
      'Seen': FieldValue.arrayUnion([id])
    });
    List w;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) async {
        if (doc.id == type) {
          Map movies_result = doc.data() as Map;
          w = movies_result["Seen"];
          if (type == "Movies") {
            currentUser.seenMovies = [];
          } else {
            currentUser.seenTVShows = [];
          }
          for (var element in w) {
            if (type == "Movies") {
              currentUser.seenMovies += [
                [type, element]
              ];
            } else {
              currentUser.seenTVShows += [
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
      var document = await FirebaseFirestore.instance
          .collection(tempUid)
          .doc("Settings")
          .get();
      if (document.exists && document.data()!.containsKey('profile_photo')) {
        profilePhotos.add(document.data()!['profile_photo']);
      } else {
        profilePhotos.add(""); //eplace with your default image URL
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
}

class ApiUtils {
  static Future<dynamic> fetchOmdbData(String imdbId) async {
    final response = await http
        .get(Uri.parse('https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9'));
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

    Map<String, dynamic> data = {
      'cast': jsonDecode(creditsResponse.body)["cast"],
      'crew': jsonDecode(creditsResponse.body)["crew"],
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
