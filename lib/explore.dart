// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uractor/objects/Person.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'common/utils.dart';
import 'objects/Movie.dart';
import 'movie_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'person_result.dart';

List _items = [];
int page = 1;
int newItems = 0;

Map _imageSeenProviders = {};
Map _imageWatchlistProviders = {};
Map _imageFavProviders = {};
Map _imageListsProviders = {};
Map _isSeenTapped = {};
Map _isWatchlistTapped = {};
Map _isFavTapped = {};
int itemsPerPage = 20;
Map _isListsTapped = {};
List docIds = [];
int added = 0;
String actor_of_the_week = "";

bool areAllFiltersPresent(List<String> genreFilters, List genreMaps) {
  return genreFilters
      .every((filter) => genreMaps.any((map) => map['name'] == filter));
}

class Genre {
  String name;
  bool isSelected;
  Genre(this.name, this.isSelected);
  String getAssetImagePath() {
    if (name == "Science Fiction") {
      name = "SciFi";
    }
    if (isSelected) {
      return 'assets/${name.toLowerCase()}_after.svg';
    } else {
      return 'assets/${name.toLowerCase()}_before.svg';
    }
  }
}

Future<void> deleteFromWatchedConfirmation(
    String id, BuildContext context) async {
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
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) async {
        if (doc.id == "Movies") {
          Map moviesResult = doc.data() as Map;
          w = moviesResult["Seen"];
          int index = w.indexOf(id);

          if (index > -1) {
            w.removeAt(index);
          }
          var userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Movies");
          await userDoc.update({'Seen': w});
          currentUser.seenMovies = [];
          for (var element in w) {
            currentUser.seenMovies += [
              ["Movies", element]
            ];
          }
        }
      });
    });
  } else {
    _imageSeenProviders[id] = 'assets/seen_after.png';
  }
}

void markWatched(String id, String title, BuildContext context) async {
  final userDoc =
      FirebaseFirestore.instance.collection(currentUser.uid).doc('Movies');
  id = id.toString();
  await userDoc.update({
    'Seen': FieldValue.arrayUnion([id])
  });
  // store id in shared preferences or another way
  List w;
  await FirebaseFirestore.instance
      .collection(currentUser.uid)
      .get()
      .then((QuerySnapshot querySnapshot) {
    querySnapshot.docs.forEach((doc) async {
      if (doc.id == "Movies") {
        Map moviesResult = doc.data() as Map;
        w = moviesResult["Seen"];
        currentUser.seenMovies = [];
        for (var element in w) {
          currentUser.seenMovies += [
            ["Movies", element]
          ];
        }
      }
    });
  });

  final today = DateTime.now();

  final snapshot =
      await FirebaseFirestore.instance.collection(currentUser.uid).get();
  for (var doc in snapshot.docs) {
    if (doc.id == 'Calendar') {
      if (!currentUser.dontAskCalendar) {
        addtoCalendar(id, title, today, context);
      }
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

    final userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc('Calendar');
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
  }
}

void favorite(String id, context) async {
  final userDoc =
      FirebaseFirestore.instance.collection(currentUser.uid).doc("Favorites");
  await userDoc.update({
    'Movies': FieldValue.arrayUnion([id])
  });
  currentUser.favMovies = [];
  await FirebaseFirestore.instance
      .collection(currentUser.uid)
      .get()
      .then((QuerySnapshot querySnapshot) {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Favorites") {
        Map allFavs = doc.data() as Map;
        allFavs["Movies"].forEach((element) {
          currentUser.favMovies += [
            ["Movies", element]
          ];
        });
      }
    }
  });
}

void unfavorite(String id, context) async {
  await FirebaseFirestore.instance
      .collection(currentUser.uid)
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
        final userDoc = FirebaseFirestore.instance
            .collection(currentUser.uid)
            .doc("Favorites");
        await userDoc.update({'Movies': movieInFavs});
        currentUser.favMovies = [];
        allFavs["Movies"].forEach((element) {
          currentUser.favMovies += [
            ["Movies", element]
          ];
        });
      }
    }
  });
}

void bookmark(String id, context) async {
  final userDoc =
      FirebaseFirestore.instance.collection(currentUser.uid).doc("Watchlist");
  await userDoc.update({
    'Movies': FieldValue.arrayUnion([id])
  });
  currentUser.watchlist = [];
  await FirebaseFirestore.instance
      .collection(currentUser.uid)
      .get()
      .then((QuerySnapshot querySnapshot) {
    for (var doc in querySnapshot.docs) {
      if (doc.id == "Watchlist") {
        Map watchlistAll = doc.data() as Map;
        watchlistAll["Movies"].forEach((element) {
          currentUser.watchlist += [
            ["Movies", element]
          ];
        });
      }
    }
  });
}

void unbookmark(String id, context) async {
  await FirebaseFirestore.instance
      .collection(currentUser.uid)
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
        final userDoc = FirebaseFirestore.instance
            .collection(currentUser.uid)
            .doc("Watchlist");
        await userDoc.update({'Movies': movieInWatchlist});
        currentUser.watchlist = [];
        watchlistAll["Movies"].forEach((element) {
          currentUser.watchlist += [
            ["Movies", element]
          ];
        });
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

void deleteFromList(
    String id, String listId, List moviesinList, context) async {
  moviesinList.remove(id);
  final userDoc = FirebaseFirestore.instance
      .collection("Watchlists")
      .doc(listId.toString());
  await userDoc.update({'Movies': moviesinList});
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

bool containsList(List list, List map) {
  for (int i = 0; i < list.length; i++) {
    if ((list[i][1]).toString() == map[1].toString() &&
        (list[i][0]) as String == "Movies") {
      return true;
    }
  }
  return false;
}

void check(id) {
  if (containsList(currentUser.seenMovies, ['Movies', id])) {
    _isSeenTapped[id] = true;
    _imageSeenProviders[id] = 'assets/seen_after.png';
  } else {
    _isSeenTapped[id] = false;
    _imageSeenProviders[id] = 'assets/seen_before.png';
  }
  if (containsList(currentUser.watchlist, ['Movies', id])) {
    _isWatchlistTapped[id] = true;
    _imageWatchlistProviders[id] = 'assets/watchlist_after.png';
  } else {
    _isWatchlistTapped[id] = false;
    _imageWatchlistProviders[id] = 'assets/watchlist_before.png';
  }
  if (containsList(currentUser.favMovies, ['Movies', id])) {
    _isFavTapped[id] = true;
    _imageFavProviders[id] = 'assets/fav_after.png';
  } else {
    _isFavTapped[id] = false;
    _imageFavProviders[id] = 'assets/fav_before.png';
  }
  _imageListsProviders[id] = 'assets/playlists_before.png';
  _isListsTapped[id] = false;
}

class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  bool _carouselLoaded = false;
  List<String> filters = [];
  List<Map<String, dynamic>> movies = [];
  bool isGridMode = false;
  List genres = [];
  final ScrollController _scrollController = ScrollController();
  bool _inMyProviders = false;

  bool isFilterOpen = false;

  int scoreActor = 0;
  int scoreDirector = 0;
  int stats = 0;
  int stats_tv = 0;
  int allDirMovies = 0;
  int stats_dir = 0;
  List countedMoviesDirector = [];
  List countedMoviesActor = [];
  List countedTVShowsDirector = [];
  List countedTVShowsActor = [];

  bool containsIdInMap(List ids, List data) {
    for (String id in ids) {
      for (Map<String, dynamic> map in data) {
        if (map.containsKey('provider_id') &&
            map['provider_id'] == int.parse(id)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> toggleFilter() async {
    if (isFilterOpen) {
      for (Genre genreCheckBox in genres) {
        if (genreCheckBox.isSelected == true) {
          filters.add(genreCheckBox.name);
        }
      }
    } else {
      filters = [];
    }
    if (filters.isNotEmpty || _inMyProviders) {
      _items = [];
      await getData();
      page = 1;
      setState(() {});
    }
    setState(() {
      isFilterOpen = !isFilterOpen;
    });
  }

  Future<void> getAllMovies() async {
    List ids = [];
    if (docIds.isEmpty) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection("Admin")
          .doc("recommendations")
          .get();

      Map json = snapshot.data() as Map;
      // docIds = json["docIds"];
      for (var element in json.keys) {
        ids.add(element);
      }
    }
    idsExplorePage.addAll(ids);
  }

  Future<Map> getMovieData(String id) async {
    final response = await http.get(Uri.parse('$MOVIE_LINK$id$API_KEY'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json["backdrop_path"] == null) {
        json["backdrop_path"] = "";
      }
      var imdbId = json['imdb_id'];
      if (imdbId != null) {
        String link2 = 'https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9';
        final r = await http.get(Uri.parse(link2));
        if (r.statusCode == 200) {
          json['imdb_rating'] = jsonDecode(r.body)['imdbRating'];
          json['year'] = jsonDecode(r.body)['Year'];
        } else {
          json['imdb_rating'] = "None";
          json['year'] = "None";
        }
        final r2 =
            await http.get(Uri.parse('$MOVIE_LINK$id$WATCH_PROVIDERS_LINK'));
        if (r2.statusCode == 200) {
          json['providers'] = [];
          if (jsonDecode(r2.body)["results"]
              .keys
              .contains(currentUser.country)) {
            if (jsonDecode(r2.body)["results"][currentUser.country]
                    ['flatrate'] !=
                null) {
              jsonDecode(r2.body)["results"][currentUser.country]['flatrate']
                  .forEach(
                (provider) async {
                  String name = provider['provider_name'];
                  String photo = IMG_LINK + provider['logo_path'];
                  json['providers'].add([name, photo]);
                },
              );
            }
          }
        }
        return json;
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  Future<void> getData() async {
    if (idsExplorePage.isEmpty) {
      await getAllMovies();
    }
    _items = [];
    for (String id in idsExplorePage) {
      Map element = await getMovieData(id);
      _items.add(element);
      check(element["id"].toString());
    }
    setState(() {
      _carouselLoaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Don't forget to dispose the ScrollController
    super.dispose();
  }

  void _scrollListener() {}

  @override
  Widget build(BuildContext context) {
    void _onTap(String type, String id, String title) {
      setState(
        () {
          switch (type) {
            case 'seen':
              _isSeenTapped[id] = !_isSeenTapped[id];
              if (_isSeenTapped[id]) {
                _imageSeenProviders[id] = 'assets/seen_after.png';
                markWatched(id, title, context);
              } else {
                _imageSeenProviders[id] = 'assets/seen_before.png';
                deleteFromWatchedConfirmation(id, context);
              }
              break;
            case 'watchlist':
              _isWatchlistTapped[id] = !_isWatchlistTapped[id];
              if (_isWatchlistTapped[id]) {
                _imageWatchlistProviders[id] = 'assets/watchlist_after.png';
                bookmark(id, context);
              } else {
                _imageWatchlistProviders[id] = 'assets/watchlist_before.png';
                unbookmark(id, context);
              }
              break;
            case 'fav':
              _isFavTapped[id] = !_isFavTapped[id];
              if (_isFavTapped[id]) {
                _imageFavProviders[id] = 'assets/fav_after.png';
                favorite(id, context);
              } else {
                _imageFavProviders[id] = 'assets/fav_before.png';
                unfavorite(id, context);
              }
              break;
            case 'list':
              _isListsTapped[id] = !_isListsTapped[id];
              if (_isListsTapped[id]) {
                _imageListsProviders[id] = 'assets/playlists_after.png';
                showModalBottomSheet(
                  context: context,
                  builder: (_) {
                    return SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: (currentUser.playlists.length / 2).ceil(),
                        itemBuilder: (context, index) {
                          final leftMovieIndex = index * 2;
                          final rightMovieIndex = index * 2 + 1;
                          final keyLeft =
                              (leftMovieIndex < currentUser.playlists.length)
                                  ? currentUser.playlists.keys
                                      .elementAt(leftMovieIndex)
                                  : null;
                          final keyRight =
                              (rightMovieIndex < currentUser.playlists.length)
                                  ? currentUser.playlists.keys
                                      .elementAt(rightMovieIndex)
                                  : null;
                          dynamic valueLeft,
                              imageLeft,
                              moviesLeft,
                              valueRight,
                              imageRight,
                              moviesRight;
                          if (keyLeft != null) {
                            valueLeft = currentUser.playlists[keyLeft]['Name'];
                            imageLeft =
                                currentUser.playlists[keyLeft]['CoverPhoto'];
                            moviesLeft =
                                currentUser.playlists[keyLeft]['Movies'];
                          }
                          if (keyRight != null) {
                            valueRight =
                                currentUser.playlists[keyRight]['Name'];
                            imageRight =
                                currentUser.playlists[keyRight]['CoverPhoto'];
                            moviesRight =
                                currentUser.playlists[keyRight]['Movies'];
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
                        _imageListsProviders[id] =
                            'assets/playlists_before.png';
                        _isListsTapped[id] = !_isListsTapped[id];
                      })
                    });
              } else {
                _imageListsProviders[id] = 'assets/playlists_before.png';
              }
              break;
            default:
              break;
          }
        },
      );
    }

    Widget _buildGridView() {
      // Replace this with your grid content
      return ListView.builder(
        controller: _scrollController,
        itemCount:
            (_items.length / 3).ceil(), // Calculate number of rows needed
        itemBuilder: (BuildContext context, int rowIndex) {
          // Calculate starting index for the current row
          int startIndex = rowIndex * 3;
          int endIndex = startIndex + 3;
          endIndex = endIndex > _items.length ? _items.length : endIndex;

          // Create a sublist of movies for the current row
          List<dynamic> rowItems = _items.sublist(startIndex, endIndex);

          // Build a row of movies using GridView.builder
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.55,
            ),
            itemCount: rowItems.length,
            itemBuilder: (BuildContext context, int index) {
              var item = rowItems[index];
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Movie tempMovie = Movie(
                            id: item["id"].toString(),
                            title: item["title"],
                            coverPhoto: item["poster_path"] ?? "");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  MovieResult(movie: tempMovie)),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(27),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 114, 113, 113)
                                    .withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(
                                    2, 2), // changes position of shadow
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(27),
                            child: Image.network(
                              IMG_LINK + item["poster_path"],
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10.0,
                    ), // You can adjust this value as needed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _onTap(
                              'seen', item["id"].toString(), item["title"]),
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(0.0, 5.0, 5.0, 5.0),
                            child: Image.asset(
                              _imageSeenProviders[item["id"].toString()],
                              height: 20,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _onTap('watchlist',
                              item["id"].toString(), item["title"]),
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(0.0, 5.0, 5.0, 5.0),
                            child: Image.asset(
                              _imageWatchlistProviders[item["id"].toString()],
                              height: 20,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _onTap(
                              'fav', item["id"].toString(), item["title"]),
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(0.0, 5.0, 5.0, 5.0),
                            child: Image.asset(
                              _imageFavProviders[item["id"].toString()],
                              height: 20,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _onTap(
                              'list', item["id"].toString(), item["title"]),
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(0.0, 5.0, 5.0, 5.0),
                            child: Image.asset(
                              _imageListsProviders[item["id"].toString()],
                              height: 25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    Widget _buildContentView() {
      if (_carouselLoaded) {
        return _buildGridView();
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
    }

    Future<Map> getPersonData() async {
      DocumentSnapshot snapshot2 = await FirebaseFirestore.instance
          .collection("Admin")
          .doc("monthlyPerson")
          .get();
      Map actsWeek = snapshot2.data() as Map;
      List keys = [];
      for (var element in actsWeek.keys) {
        keys.add(element);
      }
      actor_of_the_week = keys[0];
      Map json = {};
      final response =
          await http.get(Uri.parse('$PERSON_LINK$actor_of_the_week$API_KEY'));
      json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final r2 = await http.get(
            Uri.parse('$PERSON_LINK$actor_of_the_week$MOVIE_CREDITS_LINK'));
        if (r2.statusCode == 200) {
          List movieCast = [];
          for (Map movie in jsonDecode(r2.body)['cast']) {
            if (movie["poster_path"] != null) {
              if (!movie["character"]
                      .toString()
                      .toLowerCase()
                      .contains("self") &&
                  !movie["character"]
                      .toString()
                      .toLowerCase()
                      .contains("archived") &&
                  !movie["character"]
                      .toString()
                      .toLowerCase()
                      .contains("uncredited") &&
                  movie["character"].toString() != "") {
                movieCast.add(movie);
              }
            }
          }
          json['movie_credits_cast'] = movieCast;
          for (var element in movieCast) {
            if (Utils.contains_non_type(
                currentUser.seenMovies, ["Movies", element["id"].toString()])) {
              if (!countedMoviesActor.contains(element["id"].toString())) {
                stats += 1;
                if (Utils.contains_non_type(currentUser.favMovies,
                    ['Movies', element["id"].toString()])) {
                  scoreActor += 3;
                }
                if (currentUser.rewatchedMovies.keys
                    .toList()
                    .contains(element["id"].toString())) {
                  scoreActor += currentUser
                      .rewatchedMovies[element["id"].toString()] as int;
                } else {
                  scoreActor += 2;
                }
                countedMoviesActor.add(element["id"].toString());
              }
            } else if (Utils.contains_non_type(currentUser.watchlist,
                    ['Movies', element["id"].toString()]) &&
                !countedMoviesActor.contains(element["id"].toString())) {
              scoreActor += 1;
              countedMoviesActor.add(element["id"].toString());
            }
          }
          final r3 = await http.get(
              Uri.parse('$PERSON_LINK$actor_of_the_week$TV_SHOW_CREDITS_LINK'));
          if (r3.statusCode == 200) {
            List tvCast = [];
            for (Map show in jsonDecode(r3.body)['cast']) {
              if (show["poster_path"] != null) {
                if (!show["character"]
                        .toString()
                        .toLowerCase()
                        .contains("self") &&
                    show["character"].toString() != "") {
                  tvCast.add(show);
                }
              }
            }
            json['tv_credits_cast'] = tvCast;
            for (var element in tvCast) {
              if (Utils.contains_non_type(currentUser.seenTVShows,
                  ["TVShows", element["id"].toString()])) {
                if (!countedTVShowsActor.contains(element["id"].toString())) {
                  stats_tv += 1;
                  if (Utils.contains_non_type(currentUser.favTVShows,
                      ['TVShows', element["id"].toString()])) {
                    scoreActor += 3;
                  } else {
                    scoreActor += 2;
                  }
                  countedTVShowsActor.add(element["id"].toString());
                }
              } else if (Utils.contains_non_type(currentUser.watchlistTVShows,
                      ['TVShows', element["id"].toString()]) &&
                  !countedTVShowsActor.contains(element["id"].toString())) {
                scoreActor += 1;
                countedTVShowsActor.add(element["id"].toString());
              }
            }
          } else {
            throw Exception('Failed to load movie details');
          }
          List movieCrew = [];
          for (Map movie in jsonDecode(r2.body)['crew']) {
            if (movie["poster_path"] != null && movie["job"] != "Thanks") {
              movieCrew.add(movie);
            }
          }
          json['movie_credits_crew'] = movieCrew;
          for (var element in movieCrew) {
            if (Utils.contains_non_type(
                currentUser.seenMovies, ["Movies", element["id"].toString()])) {
              if (element["job"] == "Director" &&
                  !countedMoviesDirector.contains(element["id"].toString())) {
                stats_dir += 1;
                if (Utils.contains_non_type(currentUser.favMovies,
                    ['Movies', element["id"].toString()])) {
                  scoreDirector += 3;
                }
                if (currentUser.rewatchedMovies.keys
                    .toList()
                    .contains(element["id"])) {
                  scoreDirector += int.parse(
                      currentUser.rewatchedMovies[element["id"].toString()]);
                } else {
                  scoreDirector += 2;
                }
                countedMoviesDirector.add(element["id"].toString());
              }
            } else if (Utils.contains_non_type(currentUser.watchlist,
                    ['Movies', element["id"].toString()]) &&
                element["job"] == "Director" &&
                !countedMoviesDirector.contains(element["id"].toString())) {
              scoreDirector += 1;
              countedMoviesDirector.add(element["id"].toString());
            }
            if (element["job"] == "Director") {
              allDirMovies += 1;
            }
          }
          final r4 = await http.get(
              Uri.parse('$PERSON_LINK$actor_of_the_week$TV_SHOW_CREDITS_LINK'));
          if (r4.statusCode == 200) {
            List tvCrew = [];
            for (Map show in jsonDecode(r4.body)['crew']) {
              if (show["poster_path"] != null) {
                tvCrew.add(show);
              }
            }
            json['tv_credits_crew'] = tvCrew;
            for (var element in tvCrew) {
              if (Utils.contains_non_type(currentUser.seenTVShows,
                  ["TVShows", element["id"].toString()])) {
                if (element["job"] == "Director" &&
                    !countedTVShowsDirector
                        .contains(element["id"].toString())) {
                  stats_dir += 1;
                  if (Utils.contains_non_type(currentUser.favTVShows,
                      ['TVShows', element["id"].toString()])) {
                    scoreDirector += 3;
                  } else {
                    scoreDirector += 1;
                  }
                  countedTVShowsDirector.add(element["id"].toString());
                }
              } else if (Utils.contains_non_type(currentUser.watchlistTVShows,
                      ['TVShows', element["id"].toString()]) &&
                  element["job"] == "Director" &&
                  !countedTVShowsDirector.contains(element["id"].toString())) {
                scoreDirector += 1;
                countedTVShowsDirector.add(element["id"].toString());
              }

              if (element["job"] == "Director") {
                allDirMovies += 1;
              }
            }
            var userDoc = FirebaseFirestore.instance
                .collection(currentUser.uid)
                .doc("FavDirectors");
            var ActorDoc = FirebaseFirestore.instance
                .collection(currentUser.uid)
                .doc("FavActors");
            Map<Object, Object?> directorStats = {};
            directorStats[json['id'].toString()] = scoreDirector;
            // await userDoc.update(directorStats);
            await ActorDoc.get().then((DocumentSnapshot doc) async {
              Map info = doc.data() as Map;
              List actrs = [];
              info.forEach((key, value) {
                List item = [value, key];
                actrs.add(item);
              });
              actrs.sort((a, b) => a[0].compareTo(b[0]));
              actrs = actrs.reversed.toList();
              int num = 0;
              for (var act in actrs) {
                num++;
                if (act[1].toString() ==
                    actor_of_the_week.split("-")[0].toString()) {
                  break;
                }
              }
              json["actor_ranking"] = num;
            });
            await userDoc.get().then((DocumentSnapshot doc) async {
              Map info = doc.data() as Map;
              List actrs = [];
              info.forEach((key, value) {
                List item = [value, key];
                actrs.add(item);
              });
              actrs.sort((a, b) => a[0].compareTo(b[0]));
              actrs = actrs.reversed.toList();
              int num = 0;
              for (var act in actrs) {
                num++;
                if (act[1].toString() ==
                    actor_of_the_week.split("-")[0].toString()) {
                  break;
                }
              }
              json["director_ranking"] = num;
              json["allDirMovies"] = allDirMovies;
            });
            return json;
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

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Text(
              "Pick of the Week",
              style: TextStyle(fontSize: 30),
            ),
          ),
          FutureBuilder<Map>(
            future: getPersonData(),
            builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
              if (snapshot.hasData) {
                return SingleChildScrollView(
                    child: Column(children: [
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: MediaQuery.of(context).size.width * 0.38,
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: 1,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              Person personResult = Person(
                                  id: snapshot.data!["id"].toString(),
                                  name: snapshot.data!["name"].toString(),
                                  data: snapshot.data!);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PersonResult(
                                          personResult: personResult,
                                        )),
                              );
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.1,
                              height: MediaQuery.of(context).size.height * 0.17,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                image: DecorationImage(
                                  image: NetworkImage(IMG_LINK +
                                      snapshot.data!['profile_path']),
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      snapshot.data!['name'],
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  ExpansionTile(
                      title: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Your Statistics"),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 25),
                          child: Column(
                            children: [
                              Text(
                                "Actor ranking: #${snapshot.data!['actor_ranking']} ($scoreActor)",
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (allDirMovies != 0)
                                Text(
                                  "Director ranking: #${snapshot.data!['director_ranking']} ($scoreDirector)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Text(
                                  "Actor Movie Progress: $stats / ${(snapshot.data!['movie_credits_cast'].length)} (${double.parse((stats / (snapshot.data!['movie_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats /
                                        (snapshot.data!['movie_credits_cast']
                                            .length),
                                  ),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Text(
                                  "Actor TV Show Progress: $stats_tv / ${(snapshot.data!['tv_credits_cast'].length)} (${double.parse((stats_tv / (snapshot.data!['tv_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats_tv /
                                        (snapshot
                                            .data!['tv_credits_cast'].length),
                                  ),
                                ),
                              if (allDirMovies != 0)
                                Text(
                                  "Director Progress: $stats_dir / ${(snapshot.data!['allDirMovies'])} (${double.parse((stats_dir / (snapshot.data!['allDirMovies']) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (allDirMovies != 0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats_dir /
                                        (snapshot.data!['allDirMovies']),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                ]));
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
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Text(
              "Staff picks",
              style: TextStyle(fontSize: 30),
            ),
          ),
          // _buildToggleViewAndFilters(),
          Expanded(child: _buildContentView()),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isFilterOpen ? MediaQuery.of(context).size.height * 0.7 : 0,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(40.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Switch(
                      value: _inMyProviders,
                      onChanged: (value) {
                        setState(() {
                          _inMyProviders = !_inMyProviders;
                        });
                      },
                    ),
                    const Text("In My Providers"),
                  ],
                ),
                // Centered text "Genres"
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, 0), // Add padding here as needed
                  child: Text(
                    'Genres',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      // color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(
                    height: 16.0), // Add spacing between text and GridView
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(
                        20.0), // Add padding here as needed
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: genres.length,
                      itemBuilder: (BuildContext context, int index) {
                        Genre genre = genres[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              genre.isSelected = !genre.isSelected;
                            });
                          },
                          child: Stack(
                            children: [
                              SvgPicture.asset(
                                genre.getAssetImagePath(),
                                width: double.infinity,
                                height: 150.0, // Adjust the height as needed
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 0.0,
                                left: 4.0,
                                child: Text(
                                  genre.name,
                                  // style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              if (genre.isSelected)
                                const Positioned(
                                  bottom: 4.0,
                                  right: 4.0,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24.0,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
