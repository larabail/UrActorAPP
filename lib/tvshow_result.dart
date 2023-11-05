import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_app_bar.dart';
import 'friends.dart';
import 'profile.dart';
import 'search.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'playlists.dart';
import 'person_result.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

String _imageProviderSeen = 'assets/seen_before.png';
String _imageProviderWatchlist = 'assets/watchlist_before.png';
String _imageProviderList = 'assets/playlists_before.png';
String _imageProviderFav = 'assets/fav_before.png';
bool _isTappedSeen = false;
bool _isTappedWatchlist = false;
bool _isTappedFav = false;
bool _isTappedList = false;

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
        if (doc.id == "TVShows") {
          Map tvshowResults = doc.data() as Map;
          w = tvshowResults["Seen"];
          int index = w.indexOf(id);

          if (index > -1) {
            w.removeAt(index);
          }
          var userDoc =
              FirebaseFirestore.instance.collection(uid).doc("TVShows");
          await userDoc.update({'Seen': w});
          seenTVShows = [];
          for (var element in w) {
            seenTVShows += [
              ["TVShows", element]
            ];
          }
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => TVShowResult()));
        }
      });
    });
  } else {
    _imageProviderSeen = 'assets/seen_after.png';
  }
}

void markWatched(String id, String title, BuildContext context) async {
  final userDoc = FirebaseFirestore.instance.collection(uid).doc('TVShows');
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
      if (doc.id == "TVShows") {
        Map tvshowResult = doc.data() as Map;
        w = tvshowResult["Seen"];
        seenTVShows = [];
        for (var element in w) {
          seenTVShows += [
            ["TVShows", element]
          ];
        }
      }
    });
  });

  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => TVShowResult()));
}

void favorite(String id, context) async {
  final userDoc = FirebaseFirestore.instance.collection(uid).doc("Favorites");
  await userDoc.update({
    'TVShows': FieldValue.arrayUnion([id])
  });
  favTVShows = [];
  await FirebaseFirestore.instance
      .collection(uid)
      .get()
      .then((QuerySnapshot querySnapshot) {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Favorites") {
        Map allFavs = doc.data() as Map;
        allFavs["TVShows"].forEach((element) {
          favTVShows += [
            ["TVShows", element]
          ];
        });
      }
    }
  });
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => TVShowResult()));
}

void unfavorite(String id, context) async {
  await FirebaseFirestore.instance
      .collection(uid)
      .get()
      .then((QuerySnapshot querySnapshot) async {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Favorites") {
        Map allFavs = doc.data() as Map;
        List tvshowsInFavs = allFavs["TVShows"];
        int index = tvshowsInFavs.indexOf(id);
        if (index > -1) {
          tvshowsInFavs.removeAt(index);
        }
        final userDoc =
            FirebaseFirestore.instance.collection(uid).doc("Favorites");
        await userDoc.update({'TVShows': tvshowsInFavs});
        favTVShows = [];
        allFavs["TVShows"].forEach((element) {
          favTVShows += [
            ["TVShows", element]
          ];
        });
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => TVShowResult()));
      }
    }
  });
}

void bookmark(String id, context) async {
  final userDoc = FirebaseFirestore.instance.collection(uid).doc("Watchlist");
  await userDoc.update({
    'TVShows': FieldValue.arrayUnion([id])
  });
  watchlistTVShows = [];
  await FirebaseFirestore.instance
      .collection(uid)
      .get()
      .then((QuerySnapshot querySnapshot) {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Watchlist") {
        Map watchlistAll = doc.data() as Map;
        watchlistAll["TVShows"].forEach((element) {
          watchlistTVShows += [
            ["TVShows", element]
          ];
        });
      }
    }
  });
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => TVShowResult()));
}

void unbookmark(String id, context) async {
  await FirebaseFirestore.instance
      .collection(uid)
      .get()
      .then((QuerySnapshot querySnapshot) async {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Watchlist") {
        Map allWatch = doc.data() as Map;
        List tvShowinWatchlist = allWatch["TVShows"];
        int index = tvShowinWatchlist.indexOf(id);
        if (index > -1) {
          tvShowinWatchlist.removeAt(index);
        }
        final userDoc =
            FirebaseFirestore.instance.collection(uid).doc("Watchlist");
        await userDoc.update({'TVShows': tvShowinWatchlist});
        watchlistTVShows = [];
        tvShowinWatchlist.forEach((element) {
          watchlistTVShows += [
            ["TVShows", element]
          ];
        });
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => TVShowResult()));
      }
    }
  });
}

void addToList(String id, String listId, List tvshowsInList, context) async {
  tvshowsInList.add(id);
  final userDoc = FirebaseFirestore.instance
      .collection("Watchlists")
      .doc(listId.toString());
  await userDoc.update({'TV Shows': tvshowsInList});
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
      context, MaterialPageRoute(builder: (context) => TVShowResult()));
}

void deleteFromList(
    String id, String listId, List tvshowsInList, context) async {
  tvshowsInList.remove(id);
  final userDoc = FirebaseFirestore.instance
      .collection("Watchlists")
      .doc(listId.toString());
  await userDoc.update({'TV Shows': tvshowsInList});
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
      context, MaterialPageRoute(builder: (context) => TVShowResult()));
}

class TVShowResult extends StatefulWidget {
  TVShowResult();

  @override
  _TVShowResultState createState() => _TVShowResultState();
}

bool containsMap(List list, List map) {
  for (int i = 0; i < list.length; i++) {
    if ((list[i][1]) as String == map[1].toString() &&
        (list[i][0]) as String == map[0].toString()) {
      return true;
    }
  }
  return false;
}

void check() {
  if (containsMap(seenTVShows, ['TVShows', tvShowResult[0]])) {
    _isTappedSeen = true;
    _imageProviderSeen = 'assets/seen_after.png';
  } else {
    _isTappedSeen = false;
    _imageProviderSeen = 'assets/seen_before.png';
  }
  if (containsMap(watchlistTVShows, ['TVShows', tvShowResult[0]])) {
    _isTappedWatchlist = true;
    _imageProviderWatchlist = 'assets/watchlist_after.png';
  } else {
    _isTappedWatchlist = false;
    _imageProviderWatchlist = 'assets/watchlist_before.png';
  }
  if (containsMap(favTVShows, ['TVShows', tvShowResult[0]])) {
    _isTappedFav = true;
    _imageProviderFav = 'assets/fav_after.png';
  } else {
    _isTappedFav = false;
    _imageProviderFav = 'assets/fav_before.png';
  }
}

class _TVShowResultState extends State<TVShowResult> {
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  String credits = "/credits?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500';
  String link = "https://api.themoviedb.org/3/tv/";
  String id = "/external_ids?api_key=700cd4fab994df56eb41b34d38c4762a";
  String watch_providers =
      "/watch/providers?api_key=700cd4fab994df56eb41b34d38c4762a";
  String video = "/videos?api_key=700cd4fab994df56eb41b34d38c4762a";

  Future<Map> getMovieData() async {
    List movieData = tvShowResult;
    String name = movieData[1]
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$link${movieData[0]}-$name$api_key_actor'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final response2 =
          await http.get(Uri.parse('$link${movieData[0]}-$name$id'));
      if (response2.statusCode == 200) {
        String imdbId = jsonDecode(response2.body)['imdb_id'];
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

    int _selectedIndex = 0;

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
                            moviesLeft = playlists[keyLeft]['TV Shows'];
                          }
                          if (keyRight != null) {
                            valueRight = playlists[keyRight]['Name'];
                            imageRight = playlists[keyRight]['CoverPhoto'];
                            moviesRight = playlists[keyRight]['TV Shows'];
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
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[_selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
            child: Image.asset(
          'assets/logo_character.png',
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
                        if (snapshot.data!['backdrop_path'] != "")
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
                              "${snapshot.data!['name']} (${snapshot.data!['year']})",
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
                                style: const TextStyle(fontSize: 18),
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
                                style: const TextStyle(fontSize: 18),
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
                            snapshot.data!["name"]),
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
                            snapshot.data!["name"]),
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
                            snapshot.data!["name"]),
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
                            snapshot.data!["name"]),
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
                      style: TextStyle(fontSize: 18),
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
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: TextEditingController(),
                      decoration: const InputDecoration(
                        labelText: 'Times Seen',
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
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
                        height: 100,
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
                            return GestureDetector(
                              onTap: () {
                                personResult = person;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PersonResult()),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                    10.0, 10.0, 5.0, 0),
                                width: MediaQuery.of(context).size.width * 0.18,
                                height:
                                    MediaQuery.of(context).size.height * 0.18,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(27),
                                  image: DecorationImage(
                                    image: NetworkImage(person['profile_path']),
                                    fit: BoxFit.fitWidth,
                                  ),
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
                            Map person = snapshot.data!['crew'][index];
                            return Text(
                              "${person['job']}: ${person['name']}",
                              style: const TextStyle(fontSize: 15),
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
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
