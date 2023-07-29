// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uractor/playlists.dart';
import 'package:uractor/person_result.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';

String _imageProviderSeen = 'assets/seen_before.png';
String _imageProviderWatchlist = 'assets/watchlist_before.png';
String _imageProviderList = 'assets/playlists_before.png';
String _imageProviderFav = 'assets/fav_before.png';
bool _isTappedSeen = false;
bool _isTappedWatchlist = false;
bool _isTappedFav = false;
bool _isTappedList = false;

// Assuming the "context" object is available, e.g., from a Flutter widget.

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
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => MovieResult()));
        }
      });
    });
  } else {
    _imageProviderSeen = 'assets/seen_after.png';
  }
}

void markWatched(String id, String title, BuildContext context) async {
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
      final events = doc.data();
      addtoCalendar(id, title, today, context);
    }
  }
}

void addtoCalendar(
    String id, String title, DateTime today, BuildContext context) async {
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
        {'id': id, 'title': title}
      ])
    };

    final userDoc = FirebaseFirestore.instance.collection(uid).doc('Calendar');
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
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MovieResult()));
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
      }
    }
  });
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MovieResult()));
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
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MovieResult()));
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
        Map allFavs = doc.data() as Map;
        allFavs.forEach((key, el) {
          allFavs[key].forEach((element) {
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
      }
    }
  });
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MovieResult()));
}

void unbookmark(String id, context) async {
  await FirebaseFirestore.instance
      .collection(uid)
      .get()
      .then((QuerySnapshot querySnapshot) async {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Watchlist") {
        Map allWatch = doc.data() as Map;
        List movieInWatchlist = allWatch["Movies"];
        int index = movieInWatchlist.indexOf(id);
        if (index > -1) {
          movieInWatchlist.removeAt(index);
        }
        final userDoc =
            FirebaseFirestore.instance.collection(uid).doc("Watchlist");
        await userDoc.update({'Movies': movieInWatchlist});
        watchlist = [];
        allWatch.forEach((key, el) {
          allWatch[key].forEach((element) {
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
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MovieResult()));
      }
    }
  });
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
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MovieResult()));
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
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => MovieResult()));
}

class MovieResult extends StatefulWidget {
  MovieResult();

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
}

class _MovieResultState extends State<MovieResult> {
  final myController = TextEditingController();
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  String credits = "/credits?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500';
  String link = "https://api.themoviedb.org/3/movie/";
  String watch_providers =
      "/watch/providers?api_key=700cd4fab994df56eb41b34d38c4762a";
  String video = "/videos?api_key=700cd4fab994df56eb41b34d38c4762a";

  Future<Map> getMovieData() async {
    List movieData = movieResult;
    if (rewatchedMovies.keys.toList().contains(movieData[0])) {
      movieData.add(rewatchedMovies[movieData[0]]);
    } else if (containsMap(seenMovies, ['Movies', movieResult[0]])) {
      movieData.add(1);
    } else {
      movieData.add(0);
    }
    myController.text = movieData[3].toString();
    String name = movieData[1]
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$link${movieData[0]}-$name$api_key_actor'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      json["times_seen"] = movieData[3];
      String imdbId = json['imdb_id'];
      String link2 = 'https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9';
      final r = await http.get(Uri.parse(link2));
      if (r.statusCode == 200) {
        json['imdb_rating'] = jsonDecode(r.body)['imdbRating'];
        json['year'] = jsonDecode(r.body)['Year'];
        final r2 = await http
            .get(Uri.parse('$link${movieData[0]}-$name$watch_providers'));
        if (r2.statusCode == 200) {
          json['providers'] = [];
          if (jsonDecode(r2.body)["results"].keys.contains(country)) {
            if (jsonDecode(r2.body)["results"][country]['flatrate'] != null) {
              jsonDecode(r2.body)["results"][country]['flatrate'].forEach(
                (provider) async {
                  String name = provider['provider_name'];
                  String photo = imgLink + provider['logo_path'];
                  json['providers'].add([name, photo]);
                },
              );
              final r3 = await http
                  .get(Uri.parse('$link${movieData[0]}-$name$credits'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http
                    .get(Uri.parse('$link${movieData[0]}-$name$video'));
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
              final r3 = await http
                  .get(Uri.parse('$link${movieData[0]}-$name$credits'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http
                    .get(Uri.parse('$link${movieData[0]}-$name$video'));
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
            final r3 =
                await http.get(Uri.parse('$link${movieData[0]}-$name$credits'));
            if (r3.statusCode == 200) {
              json['cast'] = jsonDecode(r3.body)["cast"];
              json['crew'] = jsonDecode(r3.body)["crew"];
              final r4 =
                  await http.get(Uri.parse('$link${movieData[0]}-$name$video'));
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
      throw Exception('Failed to load movie details');
    }
  }

  @override
  Widget build(BuildContext context) {
    check();

    int selectedIndex = 0;

    // ignore: no_leading_underscores_for_local_identifiers
    void _onTap(String type, String id, String title) {
      setState(
        () {
          switch (type) {
            case 'seen':
              _isTappedSeen = !_isTappedSeen;
              if (_isTappedSeen) {
                markWatched(id, title, context);
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
                  backgroundColor: const Color(0xFF121212),
                  context: context,
                  builder: (_) {
                    return Container(
                      height: 300, // set the height here
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
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        10.0, 10.0, 5.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.45,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                imageLeft,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.45,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                            alignment: Alignment.bottomLeft,
                                            child: Text(
                                              valueLeft,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
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
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.45,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                imageRight,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.45,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.18,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                            alignment: Alignment.bottomLeft,
                                            child: Text(
                                              valueRight,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
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
                        print(playlists);
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

    final List<Widget> pages = [
      const MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
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
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(
                                imgLink + snapshot.data!['backdrop_path'],
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
                                color: Colors.white,
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
                                color: Colors.white,
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
                              color: Colors.white,
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
                        Column(
                          children: [
                            Container(
                              height: 30,
                              margin:
                                  const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color.fromARGB(255, 255, 254, 201)
                                    .withOpacity(0.3),
                              ),
                              child: Text(
                                'Runtime: ${snapshot.data!['runtime']} min',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              height: 30,
                              margin:
                                  const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color.fromARGB(255, 255, 254, 201)
                                    .withOpacity(0.3),
                              ),
                              child: Text(
                                'IMDB Rating: ${snapshot.data!["imdb_rating"]}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ],
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
                            snapshot.data!["title"]),
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
                            snapshot.data!["title"]),
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
                            snapshot.data!["title"]),
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
                            snapshot.data!["title"]),
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
                  Container(
                    margin: const EdgeInsets.all(10.0), // set margin here
                    child: const Text(
                      "Where to Watch?",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  if (snapshot.data!['providers'].length != 0)
                    Container(
                      height: 30, // fixed height
                      margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
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
                                  imgLink +
                                      snapshot.data!['providers'][index][1],
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
                      margin: const EdgeInsets.all(10.0), // set margin here
                      child: const Text(
                        "Nowhere at the moment",
                        style: TextStyle(color: Colors.white, fontSize: 18),
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
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  Row(
                    children: const [],
                  ),
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0.0, 5.0),
                        child: const Text(
                          "Main Cast:",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 190,
                        margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!['cast'].length < 10
                              ? snapshot.data!['cast'].length
                              : 10,
                          itemBuilder: (BuildContext context, int index) {
                            Map person = snapshot.data!['cast'][index];
                            if (person['profile_path'] == null) {
                              person['profile_path'] =
                                  "https://cdn-icons-png.flaticon.com/512/3088/3088765.png";
                            } else {
                              person['profile_path'] =
                                  imgLink + person['profile_path'];
                            }
                            String linkPerson =
                                "https://api.themoviedb.org/3/person/";
                            return GestureDetector(
                                onTap: () {
                                  personResult = person;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PersonResult()),
                                  );
                                },
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          10.0, 10.0, 5.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.18,
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
                                      person["name"],
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ));
                          },
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0, 5.0),
                        child: const Text(
                          "Main Crew:",
                          style: TextStyle(color: Colors.white, fontSize: 18),
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
                            Map person = snapshot.data!['crew'][index];
                            return Text(
                              "${person['job']}: ${person['name']}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            );
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
                        return Center(
                          child: Text('An error occurred: $e'),
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
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121212),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            label: 'Profile',
            backgroundColor: Color(0xFF121212),
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: 2,
        onTap: (int index) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => pages[index]),
          );
        },
      ),
    );
  }
}
