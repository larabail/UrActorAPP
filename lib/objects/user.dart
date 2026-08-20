import 'package:cloud_firestore/cloud_firestore.dart';

import '../common/firebase/playlist_service.dart';
import '../main.dart';
import '../common/firebase/firestore_core.dart';

class AppUser {
  String uid;
  String userName;
  String country;
  Map settings = {};
  Map calendar = {};
  bool dontAskCalendar = false;
  List allMovies = [];
  List favActors = [];
  List friends = [];
  List favDirectors = [];
  List favWriters = [];
  List favMovies = [];
  List favTVShows = [];
  List seenMovies = [];
  List seenTVShows = [];
  List watchlist = [];
  List watchlistTVShows = [];
  Map reviews = {};
  Map tvShowReviews = {};
  Map rewatchedMovies = {};
  Map rewatchedTVShows = {};
  Map playlists = {};
  Map seenWith = {};
  List seen = [];
  List allReviews = [];
  Map recommendations = {};
  Map<String, dynamic> notifications = {};

  AppUser({
    required this.uid,
    this.userName = "",
    this.country = "",
  });

  void setUserName(String newUserName) {
    userName = newUserName;
  }

  Future<bool> getFirebaseData() async {
    clearUserData();
    await FirestoreCore.db
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Country") {
          country = (doc['Country']);
        } else if (doc.id == "Calendar") {
          calendar = doc.data() as Map;
        } else if (doc.id == "FavActors") {
          Map tempFavActors = doc.data() as Map;
          favActors = tempFavActors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          favActors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "FavDirectors") {
          Map tempFavDirectors = doc.data() as Map;
          favDirectors = tempFavDirectors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          favDirectors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "FavWriters") {
          Map tempFavWriters = doc.data() as Map;
          favWriters = tempFavWriters.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          favWriters.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "Favorites") {
          Map allFavs = doc.data() as Map;
          allFavs.forEach((key, el) {
            allFavs[key].forEach((element) {
              if (key == "Movies") {
                favMovies += [
                  [key, element]
                ];
              } else {
                favTVShows += [
                  [key, element]
                ];
              }
            });
          });
        } else if (doc.id == "Movies") {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              seenMovies += [
                ["Movies", element]
              ];
            });
          });
        } else if (doc.id == "SeenWith") {
          Map data = doc.data() as Map;
          seenWith = {};
          for (String movieId in data["Movies"].keys) {
            List friendsWhoHaveSeenThisMovie =
                data["Movies"][movieId]["friends"];

            for (String friendUid in friendsWhoHaveSeenThisMovie) {
              if (!seenWith.containsKey(friendUid)) {
                seenWith[friendUid] = {"Movies": [], "TVShows": []};
              }
              seenWith[friendUid]["Movies"].add(movieId);
            }
          }
          for (String movieId in data["TVShows"].keys) {
            List friendsWhoHaveSeenThisMovie =
                data["TVShows"][movieId]["friends"];

            for (String friendUid in friendsWhoHaveSeenThisMovie) {
              if (!seenWith.containsKey(friendUid)) {
                seenWith[friendUid] = {"Movies": [], "TVShows": []};
              }
              seenWith[friendUid]["TVShows"].add(movieId);
            }
          }
        } else if (doc.id == "Settings") {
          settings = doc.data() as Map;
          dontAskCalendar = settings["dontAskCalendar"];
        } else if (doc.id == "Reviews" && reviews.keys.isEmpty) {
          Map reviewsMap = doc.data() as Map;
          List reviewsList = reviewsMap["Movies"];
          List allMovieReviews = [];
          for (var element in reviewsList) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
            allMovieReviews += [
              [
                "Movies",
                element.keys.toList()[0],
                element[element.keys.toList()[0]]
              ]
            ];
          }
          List tvShowReviewsList = reviewsMap["TVShows"];
          List allTvShowRevies = [];
          for (var element in tvShowReviewsList) {
            element = element as Map;
            tvShowReviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
            allTvShowRevies += [
              [
                "TVShows",
                element.keys.toList()[0],
                element[element.keys.toList()[0]]
              ]
            ];
          }
          allReviews += allTvShowRevies;
          allReviews += allMovieReviews;
          allReviews = allReviews.reversed.toList();
        } else if (doc.id == "Rewatched") {
          rewatchedMovies = doc.data() as Map;
        } else if (doc.id == "RewatchedTV") {
          rewatchedTVShows = doc.data() as Map;
        } else if (doc.id == "TVShows") {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              seenTVShows += [
                ["TVShows", element]
              ];
            });
          });
        } else if (doc.id == "Watchlist") {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              if (key == "Movies") {
                watchlist += [
                  [key, element]
                ];
              } else {
                watchlistTVShows += [
                  [key, element]
                ];
              }
            });
          });
        } else if (doc.id == "Friends") {
          Map f = doc.data() as Map;
          friends = f["friends"];
        } else if (doc.id == "Notifications") {
          Map f = doc.data() as Map;
          notifications = f as Map<String, dynamic>;
        } else if (doc.id == "Seen") {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              seen += [
                [key, element]
              ];
            });
          });
        } else if (doc.id == "Recommendations") {
          Map w = doc.data() as Map;
          recommendations = w;
        }
      }
    });
    playlists = await PlaylistService.fetchPlaylists(uid);
    await FirestoreCore.db
        .collection("Oscars")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map d = doc.data() as Map;
        oscars[d["tmdb_id"].toString()] = doc.data();
      }
    });
    return true;
  }

  void clearUserData() {
    country = '';
    calendar = {};
    allMovies = [];
    favActors = [];
    favDirectors = [];
    favWriters = [];
    favMovies = [];
    favTVShows = [];
    friends = [];
    seenMovies = [];
    seenTVShows = [];
    watchlist = [];
    watchlistTVShows = [];
    reviews = {};
    tvShowReviews = {};
    allReviews = [];
    rewatchedMovies = {};
    rewatchedTVShows = {};
    playlists = {};
    seenWith = {};
    settings = {};
    friends = [];
    notifications = {};
  }

  void clearUser() {
    uid = '';
  }
}
