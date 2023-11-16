// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'common/utils.dart';
import 'common/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'friends.dart';
import 'friends_profile.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'rating_popup.dart';
import 'person_result.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';

String _imageProviderSeen = 'assets/seen_before.png';
String _imageProviderWatchlist = 'assets/watchlist_before.png';
bool reviewed = false;
String _imageProviderList = 'assets/playlists_before.png';
String _imageProviderFav = 'assets/fav_before.png';
bool _isTappedSeen = false;
bool _isTappedWatchlist = false;
bool _isTappedFav = false;
bool _isTappedList = false;
String reviewId = "";
Map reviewInfo = {};
final myController = TextEditingController(text: "");

class MovieResult extends StatefulWidget {
  const MovieResult({super.key});

  @override
  _MovieResultState createState() => _MovieResultState();
}

bool containsMap(List list, List map) {
  for (int i = 0; i < list.length; i++) {
    if ((list[i][1]).toString() == map[1].toString() &&
        (list[i][0]) as String == "Movies") {
      return true;
    }
  }
  return false;
}

void check() {
  if (containsMap(seenMovies, ['Movies', movieResult[0]])) {
    _isTappedSeen = true;
    _imageProviderSeen = 'assets/seen_after.png';
  } else {
    _isTappedSeen = false;
    _imageProviderSeen = 'assets/seen_before.png';
  }
  if (containsMap(watchlist, ['Movies', movieResult[0]])) {
    _isTappedWatchlist = true;
    _imageProviderWatchlist = 'assets/watchlist_after.png';
  } else {
    _isTappedWatchlist = false;
    _imageProviderWatchlist = 'assets/watchlist_before.png';
  }
  if (containsMap(favMovies, ['Movies', movieResult[0]])) {
    _isTappedFav = true;
    _imageProviderFav = 'assets/fav_after.png';
  } else {
    _isTappedFav = false;
    _imageProviderFav = 'assets/fav_before.png';
  }

  if (reviews.keys.toList().contains(movieResult[0].toString())) {
    reviewed = true;
  }
}

class _MovieResultState extends State<MovieResult> {
  Future<void> deleteFromWatchedConfirmation(
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
            setState(() {
              seenMovies = seenMovies;
            });
          }
        });
      });
    } else {
      _imageProviderSeen = 'assets/seen_after.png';
    }
  }

  void writeReview(id, context) {
    reviewId = id.toString();
    // Show the dialog like this
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    );
  }

  void editReview(id, context) {
    reviewId = id.toString();
    reviewInfo = reviews[id.toString()];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    );
  }

  void incrementWatched(String value, String id) {
    if (value != "") {
      var userDoc = FirebaseFirestore.instance.collection(uid).doc("Rewatched");
      Map<String, int> doc = {};
      rewatchedMovies[id] = int.parse(value);
      doc[id] = int.parse(value);
      userDoc.update(doc);
    }
  }

  Future<void> deleteReview(id, context) async {
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
          setState(() {
            reviews = reviews;
          });
        }
      }
    });
  }

  void markWatched(String id, String title, int runtime, double rating,
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
        } else {
          setState(() {
            seenMovies = seenMovies;
          });
        }
      }
    }
  }

  void addtoCalendar(String id, String title, int runtime, double imdbRating,
      DateTime today, BuildContext context) async {
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
    setState(() {
      calendar = calendar;
    });
  }

  void favorite(String id, context) async {
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
    setState(() {
      favMovies = favMovies;
    });
  }

  void unfavorite(String id, context) async {
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
          setState(() {
            favMovies = favMovies;
          });
        }
      }
    });
  }

  void bookmark(String id, context) async {
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
    setState(() {
      watchlist = watchlist;
    });
  }

  void unbookmark(String id, context) async {
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
          setState(() {
            watchlist = watchlist;
          });
        }
      }
    });
  }

  Future<List<String>> getProfilePhotos(List uids) async {
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

  void addToList(String id, String listId, List moviesinList, context) async {
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

  void deleteFromList(
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

  Future<Map> getMovieData() async {
    List movieData = movieResult;
    if (rewatchedMovies.keys.toList().contains(movieData[0])) {
      movieData.add(rewatchedMovies[movieData[0]]);
    } else if (containsMap(seenMovies, ['Movies', movieResult[0]])) {
      movieData.add(1);
    } else {
      movieData.add(0);
    }
    movieData.add(null);
    if (reviewed) {
      movieData[4] = (reviews[movieData[0].toString()] as Map);
    }
    String name = movieData[1]
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$MOVIE_LINK${movieData[0]}-$name$API_KEY'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      json["times_seen"] = movieData[3];
      json["review"] = movieData[4];
      json["seen_dates"] = [];
      for (String key in calendar.keys) {
        for (var movie in calendar[key]) {
          if (movie['id'] == movieData[0].toString()) {
            json["seen_dates"].add([key, movie["friends"]]);
          }
        }
      }
      json["seen_dates"].sort((a, b) {
        var dateA = DateTime.parse(a[0]);
        var dateB = DateTime.parse(b[0]);
        return dateB.compareTo(dateA);
      });

      if (json["backdrop_path"] == null) {
        json["backdrop_path"] = "";
      }
      var imdbId = json['imdb_id'];
      if (imdbId != null) {
        String link2 = 'https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9';
        final r = await http.get(Uri.parse(link2));
        if (r.statusCode == 200) {
          if (jsonDecode(r.body)["imdbRating"] != null &&
              jsonDecode(r.body)["imdbRating"] != "N/A") {
            json["imdb_rating"] = jsonDecode(r.body)["imdbRating"];
          } else {
            json["imdb_rating"] = "0.0";
          }
          json['year'] = jsonDecode(r.body)['Year'];
          final r2 = await http.get(Uri.parse(
              '$MOVIE_LINK${movieData[0]}-$name$WATCH_PROVIDERS_LINK'));
          if (r2.statusCode == 200) {
            json['providers'] = [];
            if (jsonDecode(r2.body)["results"].keys.contains(country)) {
              if (jsonDecode(r2.body)["results"][country]['flatrate'] != null) {
                jsonDecode(r2.body)["results"][country]['flatrate'].forEach(
                  (provider) async {
                    String name = provider['provider_name'];
                    String photo = IMG_LINK + provider['logo_path'];
                    json['providers'].add([name, photo]);
                  },
                );
                final r3 = await http.get(
                    Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
                if (r3.statusCode == 200) {
                  json['cast'] = jsonDecode(r3.body)["cast"];
                  json['crew'] = jsonDecode(r3.body)["crew"];
                  final r4 = await http.get(Uri.parse(
                      '$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                  if (r4.statusCode == 200) {
                    bool got = false;
                    jsonDecode(r4.body)['results'].forEach((element) {
                      if (element['site'] == "YouTube" &&
                          element['type'] == "Trailer" &&
                          !got) {
                        json['trailer'] = element;
                        got = true;
                      }
                    });
                    return json;
                  }
                  throw Exception('Failed to load movie details');
                }
                throw Exception('Failed to load movie details');
              } else {
                json['providers'] = [];
                final r3 = await http.get(
                    Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
                if (r3.statusCode == 200) {
                  json['cast'] = jsonDecode(r3.body)["cast"];
                  json['crew'] = jsonDecode(r3.body)["crew"];
                  final r4 = await http.get(Uri.parse(
                      '$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                  if (r4.statusCode == 200) {
                    bool got = false;
                    jsonDecode(r4.body)['results'].forEach((element) {
                      if (element['site'] == "YouTube" &&
                          element['type'] == "Trailer" &&
                          !got) {
                        json['trailer'] = element;
                        got = true;
                      }
                    });
                    return json;
                  }
                  throw Exception('Failed to load movie details');
                }
                throw Exception('Failed to load movie details');
              }
            } else {
              json['providers'] = [];
              final r3 = await http.get(
                  Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http.get(
                    Uri.parse('$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                if (r4.statusCode == 200) {
                  bool got = false;
                  jsonDecode(r4.body)['results'].forEach((element) {
                    if (element['site'] == "YouTube" &&
                        element['type'] == "Trailer" &&
                        !got) {
                      json['trailer'] = element;
                      got = true;
                    }
                  });
                  return json;
                }
                throw Exception('Failed to load movie details');
              }
              throw Exception('Failed to load movie details');
            }
          } else {
            throw Exception('Failed to load movie details');
          }
        } else {
          throw Exception('Failed to load movie details');
        }
      } else {
        json['imdb_rating'] = "0.0";
        json['year'] = "None";
        final r2 = await http.get(
            Uri.parse('$MOVIE_LINK${movieData[0]}-$name$WATCH_PROVIDERS_LINK'));
        if (r2.statusCode == 200) {
          json['providers'] = [];
          if (jsonDecode(r2.body)["results"].keys.contains(country)) {
            if (jsonDecode(r2.body)["results"][country]['flatrate'] != null) {
              jsonDecode(r2.body)["results"][country]['flatrate'].forEach(
                (provider) async {
                  String name = provider['provider_name'];
                  String photo = IMG_LINK + provider['logo_path'];
                  json['providers'].add([name, photo]);
                },
              );
              final r3 = await http.get(
                  Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http.get(
                    Uri.parse('$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                if (r4.statusCode == 200) {
                  bool got = false;
                  jsonDecode(r4.body)['results'].forEach((element) {
                    if (element['site'] == "YouTube" &&
                        element['type'] == "Trailer" &&
                        !got) {
                      json['trailer'] = element;
                      got = true;
                    }
                  });
                  return json;
                }
                throw Exception('Failed to load movie details');
              }
              throw Exception('Failed to load movie details');
            } else {
              json['providers'] = [];
              final r3 = await http.get(
                  Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http.get(
                    Uri.parse('$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                if (r4.statusCode == 200) {
                  bool got = false;
                  jsonDecode(r4.body)['results'].forEach((element) {
                    if (element['site'] == "YouTube" &&
                        element['type'] == "Trailer" &&
                        !got) {
                      json['trailer'] = element;
                      got = true;
                    }
                  });
                  return json;
                }
                throw Exception('Failed to load movie details');
              }
              throw Exception('Failed to load movie details');
            }
          } else {
            json['providers'] = [];
            final r3 = await http.get(
                Uri.parse('$MOVIE_LINK${movieData[0]}-$name$CREDITS_LINK'));
            if (r3.statusCode == 200) {
              json['cast'] = jsonDecode(r3.body)["cast"];
              json['crew'] = jsonDecode(r3.body)["crew"];
              final r4 = await http.get(
                  Uri.parse('$MOVIE_LINK${movieData[0]}-$name$VIDEOS_LINK'));
              if (r4.statusCode == 200) {
                bool got = false;
                jsonDecode(r4.body)['results'].forEach((element) {
                  if (element['site'] == "YouTube" &&
                      element['type'] == "Trailer" &&
                      !got) {
                    json['trailer'] = element;
                    got = true;
                  }
                });
                return json;
              }
              throw Exception('Failed to load movie details');
            }
            throw Exception('Failed to load movie details');
          }
        } else {
          throw Exception('Failed to load movie details');
        }
      }
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  @override
  Widget build(BuildContext context) {
    reviewed = false;
    check();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rewatchedMovies.keys.toList().contains(movieResult[0].toString())) {
        myController.text =
            (rewatchedMovies[movieResult[0].toString()]).toString();
      } else if (containsMap(seenMovies, ['Movies', movieResult[0]])) {
        myController.text = "1";
      } else {
        myController.text = "0";
      }
    });

    void _onTap(
        String type, String id, String title, int runtime, double rating) {
      setState(
        () {
          switch (type) {
            case 'seen':
              _isTappedSeen = !_isTappedSeen;
              if (_isTappedSeen) {
                markWatched(id, title, runtime, rating, context);
              } else {
                deleteFromWatchedConfirmation(id, context);
              }
              break;
            case 'watchlist':
              _isTappedWatchlist = !_isTappedWatchlist;
              if (_isTappedWatchlist) {
                bookmark(id, context);
              } else {
                unbookmark(id, context);
              }
              break;
            case 'fav':
              _isTappedFav = !_isTappedFav;
              if (_isTappedFav) {
                favorite(id, context);
              } else {
                unfavorite(id, context);
              }
              break;
            case 'list':
              _isTappedList = !_isTappedList;
              if (_isTappedList) {
                _imageProviderList = 'assets/playlists_after.png';
                showModalBottomSheet(
                  context: context,
                  builder: (_) {
                    return SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: (playlists.length / 2).ceil(),
                        itemBuilder: (context, index) {
                          final leftMovieIndex = index * 2;
                          final rightMovieIndex = index * 2 + 1;
                          final keyLeft = (leftMovieIndex < playlists.length)
                              ? playlists.keys.elementAt(leftMovieIndex)
                              : null;
                          final keyRight = (rightMovieIndex < playlists.length)
                              ? playlists.keys.elementAt(rightMovieIndex)
                              : null;
                          dynamic valueLeft,
                              imageLeft,
                              moviesLeft,
                              valueRight,
                              imageRight,
                              moviesRight;
                          if (keyLeft != null) {
                            valueLeft = playlists[keyLeft]['Name'];
                            imageLeft = playlists[keyLeft]['CoverPhoto'];
                            moviesLeft = playlists[keyLeft]['Movies'];
                          }
                          if (keyRight != null) {
                            valueRight = playlists[keyRight]['Name'];
                            imageRight = playlists[keyRight]['CoverPhoto'];
                            moviesRight = playlists[keyRight]['Movies'];
                          }
                          return Row(
                            children: [
                              if (keyLeft != null)
                                GestureDetector(
                                  onTap: () {
                                    if (moviesLeft.contains(id)) {
                                      deleteFromList(
                                          id, keyLeft, moviesLeft, context);
                                    } else {
                                      addToList(
                                          id, keyLeft, moviesLeft, context);
                                    }
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            10.0, 10.0, 5.0, 0),
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.45,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.18,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(27),
                                          image: DecorationImage(
                                            image: NetworkImage(imageLeft),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(27),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(1),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            5.0, 10.0, 10.0, 0),
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.45,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.18,
                                        // Use Align to position the text
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              valueLeft,
                                              style: const TextStyle(
                                                color: Colors
                                                    .white, // Make sure the text is visible on the gradient
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.25,
                                                wordSpacing: 1.75,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (moviesLeft.contains(id))
                                        const Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Icon(Icons.check_circle,
                                              color: Colors.green),
                                        ),
                                    ],
                                  ),
                                ),
                              if (keyRight != null)
                                GestureDetector(
                                  onTap: () {
                                    if (moviesRight.contains(id)) {
                                      deleteFromList(
                                          id, keyRight, moviesRight, context);
                                    } else {
                                      addToList(
                                          id, keyRight, moviesRight, context);
                                    }
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            5.0, 10.0, 10.0, 0),
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.45,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.18,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(27),
                                          image: DecorationImage(
                                            image: NetworkImage(imageRight),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(27),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(1),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            5.0, 10.0, 10.0, 0),
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.45,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.18,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              valueRight,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.25,
                                                wordSpacing: 1.75,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (moviesRight.contains(id))
                                        const Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Icon(Icons.check_circle,
                                              color: Colors.green),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ).then((value) => {
                      setState(() {
                        _imageProviderList = 'assets/playlists_before.png';
                        _isTappedList = !_isTappedList;
                      })
                    });
              } else {
                _imageProviderList = 'assets/playlists_before.png';
              }
              break;
            default:
              break;
          }
        },
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: getMovieData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Stack(
                      children: [
                        if (snapshot.data!['backdrop_path'] != "")
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(
                                  IMG_LINK + snapshot.data!['backdrop_path'],
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (snapshot.data!['backdrop_path'] == "")
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: const DecorationImage(
                                image: AssetImage(
                                  "assets/logo.png",
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(1),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              "${snapshot.data!['title']} (${snapshot.data!['year']})",
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                wordSpacing: 2,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.data!['overview'] != null &&
                      snapshot.data!['overview'] != "")
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          height: 85, // fixed height
                          padding: const EdgeInsets.all(8), // optional padding
                          child: ListView(
                            children: [
                              Text(
                                snapshot.data!['overview'],
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontSize: 15,
                                  wordSpacing: 2,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    height: 30, // fixed height
                    margin: const EdgeInsets.fromLTRB(20.0, 5.0, 0, 5.0),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!['genres'].length,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.3),
                          ),
                          child: Text(
                            snapshot.data!['genres'][index]['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 45,
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 30,
                          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey[
                                900], // Adjust the background color opacity as needed
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min, // Use min to wrap content
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors
                                      .white), // Replace with your desired icon
                              const SizedBox(width: 5),
                              Text(
                                '${snapshot.data!['runtime']} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 30,
                          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey[
                                900], // Adjust the background color opacity as needed
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min, // Use min to wrap content
                            children: [
                              const Icon(Icons.star,
                                  color: Colors
                                      .white), // Replace with your desired icon
                              const SizedBox(width: 5),
                              Text(
                                'IMDB: ${snapshot.data!["imdb_rating"]}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _onTap(
                            'seen',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["title"],
                            snapshot.data!["runtime"],
                            double.parse(snapshot.data!["imdb_rating"])),
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderSeen,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onTap(
                            'watchlist',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["title"],
                            snapshot.data!["runtime"],
                            double.parse(snapshot.data!["imdb_rating"])),
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderWatchlist,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onTap(
                            'fav',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["title"],
                            snapshot.data!["runtime"],
                            double.parse(snapshot.data!["imdb_rating"])),
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderFav,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onTap(
                            'list',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["title"],
                            snapshot.data!["runtime"],
                            double.parse(snapshot.data!["imdb_rating"])),
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderList,
                            height: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reviewed)
                    ExpansionTile(
                        title: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reviews),
                            SizedBox(width: 8),
                            Text(
                              "Your Review",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                wordSpacing: 2,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Align(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.8,
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                      255, 26, 25, 25), // dark grey background
                                  borderRadius: BorderRadius.circular(
                                      27), // border radius
                                ),
                                padding: const EdgeInsets.all(
                                    15), // optional padding
                                child: Column(
                                  children: [
                                    Text(
                                      'Opinion: ${snapshot.data!["review"]["Opinion"]}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        wordSpacing: 2,
                                        height: 1.5,
                                      ),
                                    ),
                                    Text(
                                      'Rating: ${snapshot.data!["review"]["Rating"]}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        wordSpacing: 2,
                                        height: 1.5,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            editReview(
                                                snapshot.data!["id"], context);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit,
                                                    color: Colors.blue),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Edit',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        GestureDetector(
                                          onTap: () {
                                            deleteReview(
                                                snapshot.data!["id"], context);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    color: Colors.red),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                  if (!reviewed &&
                      containsMap(seenMovies,
                          ['Movies', snapshot.data!["id"].toString()]))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              writeReview(snapshot.data!["id"], context);
                            },
                            child: const Text('Write A Review')),
                      ],
                    ),
                  Container(
                    margin: const EdgeInsets.all(20.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.play_circle_fill, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Where to Watch?",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (snapshot.data!['providers'].length != 0)
                          Container(
                            height: 30, // fixed height
                            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 0, 5.0),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: snapshot.data!['providers'].length,
                              itemBuilder: (BuildContext context, int index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        IMG_LINK +
                                            snapshot.data!['providers'][index]
                                                [1],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (snapshot.data!['providers'].length == 0)
                          Container(
                            margin: const EdgeInsets.all(10.0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 5.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "Nowhere at the moment",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: myController,
                      decoration: const InputDecoration(
                        labelText: "Times seen",
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        incrementWatched(
                            value.toString(),
                            snapshot.data!["id"]
                                .toString()); // replace 'yourDocumentId' with your actual document ID
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (containsMap(seenMovies, ['Movies', movieResult[0]]))
                    ExpansionTile(
                      title: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text(
                            "Watching History",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              wordSpacing: 2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        // if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                        //   Padding(
                        //     padding: const EdgeInsets.all(12.0),
                        //     child: Row(
                        //       children: [
                        //         const SizedBox(
                        //             width: 16), // Added margin to the left
                        //         const Icon(Icons.access_time,
                        //             color: Colors.green),
                        //         const SizedBox(width: 8),
                        //         Text(
                        //           "Last watched: ${intl.DateFormat('dd MMMM, yyyy').format(DateTime.parse(snapshot.data!['seen_dates'][0][0]))}",
                        //           style: const TextStyle(
                        //               fontSize: 16,
                        //               fontWeight: FontWeight.bold,
                        //               color: Colors.green),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // Rest of the dates in a smaller font
                        if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (snapshot.data!['seen_dates'] as List)
                                  .map<Widget>((date) {
                                // Assuming date[1] is a list of friend UIDs who watched the movie on this date
                                List friendsWhoWatched = date[1] ?? [];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                          width:
                                              16), // Added margin to the left
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        intl.DateFormat('dd MMMM, yyyy')
                                            .format(DateTime.parse(date[0])),
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700]),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Expanded(
                                        child: FutureBuilder<List<String>>(
                                          // Assuming getProfilePhotos returns a Future of List<String> where each String is a URL
                                          future: getProfilePhotos(
                                              friendsWhoWatched),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const SizedBox(
                                                height:
                                                    32.0, // Adjust the size as needed
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              );
                                            } else if (snapshot.hasError) {
                                              return const SizedBox(
                                                height:
                                                    32.0, // Adjust the size as needed
                                                child: Center(
                                                    child: Text(
                                                        'Error loading images')),
                                              );
                                            } else if (snapshot.hasData) {
                                              var images = snapshot.data!;
                                              return SizedBox(
                                                height:
                                                    32.0, // Adjust the size as needed
                                                child: Stack(
                                                  children: List.generate(
                                                      images.length, (index) {
                                                    // Calculate the left offset for each photo
                                                    double offset = index *
                                                        10.0; // Adjust the multiplier as needed for the desired overlap
                                                    return Positioned(
                                                      left: offset,
                                                      child: ClipOval(
                                                        child: images[index] !=
                                                                ""
                                                            ? Image.network(
                                                                images[index],
                                                                height: 25,
                                                                width: 25,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : Image.asset(
                                                                'assets/main_profile.png',
                                                                height: 25,
                                                                width: 25,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              );
                                            } else {
                                              // In case there's no data yet (which shouldn't happen since we're checking ConnectionState above)
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                          const SizedBox(height: 15),
                        // Message when 'seen_dates' is empty
                        if ((snapshot.data!['seen_dates'] as List).isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              "No watching history available.",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.red),
                            ),
                          ),
                        if (seenWith.entries
                            .where((entry) =>
                                entry.value["Movies"]
                                    ?.contains(movieResult[0].toString()) ??
                                false)
                            .isNotEmpty)
                          const Text("People watched with",
                              style: TextStyle(
                                fontSize: 16,
                              )),
                        FutureBuilder(
                          future: Future.wait(
                            seenWith.entries
                                .where((entry) =>
                                    entry.value["Movies"]
                                        ?.contains(movieResult[0].toString()) ??
                                    false)
                                .map((entry) => FirebaseFirestore.instance
                                    .collection(entry.key)
                                    .doc("Settings")
                                    .get()),
                          ),
                          builder: (BuildContext context,
                              AsyncSnapshot<List> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  "Failed to load friends' profiles.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            } else if (snapshot.hasData) {
                              // Now you have a list of DocumentSnapshots for each friend who watched the movie
                              return GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(), // to disable GridView's scrolling
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 3 / 1,
                                ),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  var doc = snapshot.data![index];
                                  var userData =
                                      doc.data() as Map<String, dynamic>;
                                  var profilePhoto = userData['profile_photo'];
                                  var username =
                                      userData['username'] ?? 'Unknown';

                                  return GestureDetector(
                                      onTap: () async {
                                        // Navigate to Profile Page
                                        var querySnapshot =
                                            await FirebaseFirestore.instance
                                                .collection('usernames')
                                                .where('username',
                                                    isEqualTo: username)
                                                .limit(1)
                                                .get();

                                        friendUid = querySnapshot.docs.first
                                            .data()['uid'];
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FriendProfile(
                                                friendUID: friendUid),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[900],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ClipOval(
                                                child: profilePhoto != ""
                                                    ? Image.network(
                                                        profilePhoto,
                                                        height: 25,
                                                        width: 25,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.asset(
                                                        'assets/main_profile.png',
                                                        height: 25,
                                                        width: 25,
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      username,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    // ... other text elements if needed ...
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ));
                                },
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                Map<String, bool> selectedFriends =
                                    {}; // Maps friend UID to selection status
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title:
                                          const Text('Add Friends Who Watched'),
                                      content: SizedBox(
                                        height:
                                            250, // Set your desired height here
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: List.generate(
                                              friends.length,
                                              (friendIndex) {
                                                return FutureBuilder<
                                                    DocumentSnapshot>(
                                                  future: FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                          friends[friendIndex])
                                                      .doc('Settings')
                                                      .get(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return const Center(
                                                          child:
                                                              CircularProgressIndicator());
                                                    } else if (snapshot
                                                        .hasError) {
                                                      return Text(
                                                          'Error: ${snapshot.error}');
                                                    } else if (!snapshot
                                                            .hasData ||
                                                        !snapshot
                                                            .data!.exists) {
                                                      return const Text(
                                                          'No data found');
                                                    } else {
                                                      var data =
                                                          snapshot.data!.data()
                                                              as Map<String,
                                                                  dynamic>;
                                                      String userName =
                                                          data['username'] ??
                                                              '';
                                                      String profilePath = data[
                                                              'profile_photo'] ??
                                                          '';
                                                      return CheckboxListTile(
                                                        title: Row(
                                                          children: [
                                                            ClipOval(
                                                              child: profilePath !=
                                                                      ""
                                                                  ? Image
                                                                      .network(
                                                                      profilePath,
                                                                      height:
                                                                          25,
                                                                      width: 25,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    )
                                                                  : Image.asset(
                                                                      'assets/main_profile.png',
                                                                      height:
                                                                          25,
                                                                      width: 25,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                            ),
                                                            const SizedBox(
                                                                width: 16.0),
                                                            Expanded(
                                                              child: Text(
                                                                userName,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        16.0),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        value: selectedFriends
                                                                .keys
                                                                .toList()
                                                                .contains(friends[
                                                                    friendIndex])
                                                            ? selectedFriends[
                                                                friends[
                                                                    friendIndex]]
                                                            : false,
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            selectedFriends[friends[
                                                                    friendIndex]] =
                                                                value!;
                                                          });
                                                        },
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Apply'),
                                          onPressed: () async {
                                            // TODO: Update the Firebase database with the selected friends
                                            // Implement the logic to update the 'seenWith' document for both the current user and the selected friends
                                            String id =
                                                movieResult[0].toString();
                                            FirebaseFirestore firestore =
                                                FirebaseFirestore.instance;
                                            for (String friend
                                                in selectedFriends.keys
                                                    .toList()) {
                                              var userDoc = FirebaseFirestore
                                                  .instance
                                                  .collection(friend)
                                                  .doc("Movies");
                                              await userDoc.update({
                                                'Seen':
                                                    FieldValue.arrayUnion([id])
                                              });
                                              if (seenWith
                                                      .containsKey(friend) &&
                                                  !seenWith[friend]["Movies"]
                                                      .contains(
                                                          id.toString())) {
                                                seenWith[friend]["Movies"]
                                                    .add(id.toString());
                                              } else if (!seenWith
                                                  .containsKey(friend)) {
                                                seenWith[friend] = {
                                                  "Movies": [],
                                                  "TVShows": []
                                                };
                                                seenWith[friend]["Movies"]
                                                    .add(id.toString());
                                              }
                                              DocumentReference userDoc2 =
                                                  firestore
                                                      .collection(friend)
                                                      .doc("SeenWith");
                                              Map<String, dynamic> item = {};
                                              List<dynamic> watchedWithList = [
                                                uid
                                              ];
                                              item[id] = watchedWithList;
                                              await firestore.runTransaction(
                                                  (transaction) async {
                                                // Get the document snapshot
                                                DocumentSnapshot snapshot =
                                                    await transaction
                                                        .get(userDoc2);

                                                if (!snapshot.exists) {
                                                  throw Exception(
                                                      "Document does not exist!");
                                                }

                                                Map<String, dynamic> data =
                                                    snapshot.data()
                                                        as Map<String, dynamic>;

                                                if (data.containsKey(
                                                        'Movies') &&
                                                    data['Movies'] is Map<
                                                        String, dynamic>) {
                                                  Map<String, dynamic>
                                                      moviesMap =
                                                      data['Movies'];

                                                  if (moviesMap
                                                      .containsKey(id)) {
                                                    List existingList =
                                                        moviesMap[id]
                                                            ["friends"];
                                                    for (String person
                                                        in watchedWithList) {
                                                      if (!existingList
                                                          .contains(person)) {
                                                        existingList
                                                            .add(person);
                                                      }
                                                    }
                                                    moviesMap[id] = {
                                                      "friends": existingList
                                                    };
                                                    transaction.update(userDoc2,
                                                        {"Movies": moviesMap});
                                                  } else {
                                                    moviesMap[id] = {
                                                      "friends": watchedWithList
                                                    };
                                                    transaction.update(userDoc2,
                                                        {"Movies": moviesMap});
                                                  }
                                                } else {
                                                  transaction.set(
                                                      userDoc2,
                                                      {
                                                        'Movies': {
                                                          id: {
                                                            "friends":
                                                                watchedWithList
                                                          }
                                                        }
                                                      },
                                                      SetOptions(merge: true));
                                                }
                                              }).catchError((error) {
                                                print(
                                                    "Failed to update document: $error");
                                              });
                                            }
                                            DocumentReference userDoc2 =
                                                firestore
                                                    .collection(uid)
                                                    .doc("SeenWith");

                                            Map<String, dynamic> item = {};
                                            List<dynamic> watchedWithList =
                                                selectedFriends.keys
                                                    .where((key) =>
                                                        selectedFriends[key] ==
                                                        true)
                                                    .toList();
                                            item[id] = watchedWithList;
                                            firestore.runTransaction(
                                                (transaction) async {
                                              // Get the document snapshot
                                              DocumentSnapshot snapshot =
                                                  await transaction
                                                      .get(userDoc2);

                                              if (!snapshot.exists) {
                                                throw Exception(
                                                    "Document does not exist!");
                                              }

                                              // Get the current data
                                              Map<String, dynamic> data =
                                                  snapshot.data()
                                                      as Map<String, dynamic>;

                                              // Check if 'Movies' map exists and if the 'id' is already a key in the 'Movies' map
                                              if (data.containsKey('Movies') &&
                                                  data['Movies']
                                                      is Map<String, dynamic>) {
                                                Map<String, dynamic> moviesMap =
                                                    data['Movies'];

                                                // Check if the 'id' already exists in the 'Movies' map
                                                if (moviesMap.containsKey(id)) {
                                                  // If it exists, append the new list to the existing one
                                                  List existingList =
                                                      moviesMap[id]["friends"];
                                                  for (String person
                                                      in watchedWithList) {
                                                    if (!existingList
                                                        .contains(person)) {
                                                      existingList.add(person);
                                                    }
                                                  }
                                                  moviesMap[id] = {
                                                    "friends": existingList
                                                  };
                                                } else {
                                                  // If the 'id' doesn't exist, add the new key-value pair
                                                  moviesMap[id] = {
                                                    "friends": watchedWithList
                                                  };
                                                }
                                                // Update the 'Movies' map
                                                transaction.update(userDoc2,
                                                    {'Movies': moviesMap});
                                              } else {
                                                // If 'Movies' map doesn't exist, create it and add the 'id' and list
                                                transaction.set(
                                                    userDoc2,
                                                    {
                                                      'Movies': {
                                                        id: {
                                                          "friends":
                                                              watchedWithList
                                                        }
                                                      }
                                                    },
                                                    SetOptions(merge: true));
                                              }
                                            }).catchError((error) {
                                              print(
                                                  "Failed to update document: $error");
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ).then((_) {
                              setState(() {});
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            width: 145,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.person_add, color: Colors.green),
                                SizedBox(width: 10),
                                Text(
                                  'Add Friends',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  const Row(
                    children: [],
                  ),
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0.0, 5.0),
                        child: const Text(
                          "Main Cast:",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.25,
                        margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!['cast'].length < 10
                              ? snapshot.data!['cast'].length
                              : 10,
                          itemBuilder: (BuildContext context, int index) {
                            Map person = snapshot.data!['cast'][index];
                            print(person);
                            if (person['profile_path'] == null) {
                              person['profile_path'] =
                                  "https://cdn-icons-png.flaticon.com/512/3088/3088765.png";
                            } else {
                              person['profile_path'] =
                                  IMG_LINK + person['profile_path'];
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(5.0, 0.0, 5.0, 0.0),
                              child: GestureDetector(
                                onTap: () {
                                  personResult = person;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PersonResult()),
                                  );
                                },
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          10.0, 10.0, 5.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.25,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(27),
                                        child: Image.network(
                                          person['profile_path'],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        height:
                                            10), // optional: to give some space between image and text
                                    Text(
                                      '${person["name"]}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '(${person["character"]})',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0, 5.0),
                        child: const Text(
                          "Main Crew:",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 1,
                        height: 100,
                        margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
                        child: ListView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: snapshot.data!['crew'].length < 5
                              ? snapshot.data!['crew'].length
                              : 5,
                          itemBuilder: (BuildContext context, int index) {
                            // Find the director in the crew list
                            var director = snapshot.data!['crew'].firstWhere(
                              (person) => person['job'] == 'Director',
                              orElse: () => null,
                            );

                            // If we're at the first index and a director exists, return the director
                            if (index == 0 && director != null) {
                              return GestureDetector(
                                  onTap: () {
                                    personResult = director;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const PersonResult()),
                                    );
                                  },
                                  child: Text(
                                    "Director: ${director['name']}",
                                    style: const TextStyle(fontSize: 15),
                                  ));
                            }

                            // Adjust the index if the director is present
                            int adjustedIndex =
                                director != null ? index - 1 : index;

                            // Skip the director since it's already shown
                            if (director != null &&
                                snapshot.data!['crew'][adjustedIndex] ==
                                    director) {
                              adjustedIndex++;
                            }

                            // Make sure we don't go out of bounds after adjustments
                            if (adjustedIndex < snapshot.data!['crew'].length) {
                              Map person =
                                  snapshot.data!['crew'][adjustedIndex];
                              return GestureDetector(
                                  onTap: () {
                                    personResult = person;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const PersonResult()),
                                    );
                                  },
                                  child: Text(
                                    "${person['job']}: ${person['name']}",
                                    style: const TextStyle(fontSize: 15),
                                  ));
                            } else {
                              return Container(); // Return an empty container to avoid errors
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (BuildContext context) {
                      try {
                        // Widget tree that may throw an exception
                        return Container(
                          // fixed height
                          margin:
                              const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
                          child: YoutubePlayer(
                            controller: YoutubePlayerController(
                              initialVideoId: snapshot.data!["trailer"]["key"],
                              flags: const YoutubePlayerFlags(
                                autoPlay: false,
                                mute: false,
                                hideControls: false,
                              ),
                            ),
                            showVideoProgressIndicator: true,
                          ),
                        );
                      } catch (e) {
                        // Handle the exception
                        return const Center(
                          child: Text(''),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text("Failed to load movie details"),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
