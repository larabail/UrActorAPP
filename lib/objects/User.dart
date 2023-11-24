import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import '../theme_provider.dart';

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
  List favMovies = [];
  List favTVShows = [];
  List seenMovies = [];
  List seenTVShows = [];
  List watchlist = [];
  List watchlistTVShows = [];
  Map reviews = {};
  Map rewatchedMovies = {};
  Map playlists = {};
  Map seenWith = {};

  AppUser({
    required this.uid,
    this.userName = "",
    this.country = "",
  });

  setUserName(String newUserName) {
    userName = newUserName;
  }

  Future<bool> getFirebaseData() async {
    clearUserData();
    await FirebaseFirestore.instance
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
          themeProvider.setDarkMode(settings["darkMode"]);
        } else if (doc.id == "Reviews" && reviews.keys.isEmpty) {
          Map reviewsMap = doc.data() as Map;
          List reviewsList = reviewsMap["Seen"];
          for (var element in reviewsList) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          }
        } else if (doc.id == "Rewatched") {
          rewatchedMovies = doc.data() as Map;
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
        }
      }
    });
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
            Map docData = doc.data() as Map;
            docData["id"] = doc.id;
            playlists[doc.id] = docData;
          }
        }
      }
    });
    await FirebaseFirestore.instance
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
    favMovies = [];
    favTVShows = [];
    seenMovies = [];
    seenTVShows = [];
    watchlist = [];
    watchlistTVShows = [];
    reviews = {};
    rewatchedMovies = {};
    playlists = {};
    seenWith = {};
    settings = {};
    friends = [];
  }

  void clearUser() {
    uid = '';
  }
}
