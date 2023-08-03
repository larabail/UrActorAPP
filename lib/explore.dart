// ignore_for_file: no_leading_underscores_for_local_identifiers, constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'playlists.dart';
import 'profile.dart';
import 'search.dart';
import 'movie_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'package:carousel_slider/carousel_slider.dart';

const String api_key_actor =
    "?api_key=700cd4fab994df56eb41b34d38c4762a&include_adult=false&include_video=false&language=en-US&page=1&sort_by=popularity.desc&adult=false&region=US";
const String imgLink = 'https://image.tmdb.org/t/p/w500/';
String watch_providers =
    "/watch/providers?api_key=700cd4fab994df56eb41b34d38c4762a";
const String GENRES_LINK =
    "https://api.themoviedb.org/3/genre/movie/list?api_key=700cd4fab994df56eb41b34d38c4762a";
String link = "https://api.themoviedb.org/3/movie/";
const String popularMoviesLink = "https://api.themoviedb.org/3/discover/movie";
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

bool areAllFiltersPresent(List<String> genreFilters, List genreMaps) {
  // Check if all genre filters are present in the list of maps
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

bool containsMap(List list, Map map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

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
        }
      });
    });
  } else {
    _imageSeenProviders[id] = 'assets/seen_after.png';
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
      if (!dontAskCalendar) {
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
  if (containsList(seenMovies, ['Movies', id])) {
    _isSeenTapped[id] = true;
    _imageSeenProviders[id] = 'assets/seen_after.png';
  } else {
    _isSeenTapped[id] = false;
    _imageSeenProviders[id] = 'assets/seen_before.png';
  }
  if (containsList(watchlist, ['Movies', id])) {
    _isWatchlistTapped[id] = true;
    _imageWatchlistProviders[id] = 'assets/watchlist_after.png';
  } else {
    _isWatchlistTapped[id] = false;
    _imageWatchlistProviders[id] = 'assets/watchlist_before.png';
  }
  if (containsList(favMovies, ['Movies', id])) {
    _isFavTapped[id] = true;
    _imageFavProviders[id] = 'assets/fav_after.png';
  } else {
    _isFavTapped[id] = false;
    _imageFavProviders[id] = 'assets/fav_before.png';
  }
  _imageListsProviders[id] = 'assets/playlists_before.png';
  _isListsTapped[id] = false;
}

final GlobalKey<CarouselSliderState> _sliderKey = GlobalKey();

class Explore extends StatefulWidget {
  Explore();

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  bool _carouselLoaded = false;
  List<String> filters = [];
  int _currentSlide = 0;
  List<Map<String, dynamic>> movies = [];
  bool isGridMode = false;
  List genres = [];
  ScrollController _scrollController = ScrollController();
  bool _inMyProviders = false;

  bool isFilterOpen = false;

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
      _currentSlide = 0;
      await getData();
      page = 1;
      setState(() {});
    }
    setState(() {
      isFilterOpen = !isFilterOpen;
    });
  }

  Future<void> getData() async {
    int i = itemsPerPage * (page - 1);
    idsExplorePage.shuffle();
    List moviesData = [];
    for (String id in idsExplorePage) {
      if (i < itemsPerPage * page) {
        await FirebaseFirestore.instance
            .collection("AllMovies")
            .doc(id)
            .get()
            .then((DocumentSnapshot snapshot) async {
          Map data = snapshot.data() as Map;
          // print(data);
          // print(filters);
          Map allData = snapshot.data() as Map;
          String name = allData["title"]
              .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
              .replaceAll(" ", "-");
          if (_inMyProviders) {
            final response = await http
                .get(Uri.parse('$link${allData["id"]}-$name$watch_providers'));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data["results"].keys.toList().contains(country)) {
                print(data["results"][country]);
                if (data["results"][country]
                    .keys
                    .toList()
                    .contains("flatrate")) {
                  List providersForMovie = data["results"][country]['flatrate'];
                  bool inMyProviders =
                      containsIdInMap(settings["providers"], providersForMovie);
                  if (inMyProviders) {
                    if (filters.isNotEmpty) {
                      // print(data["genres"]);
                      if (data.keys.toList().contains("genres")) {
                        bool allFiltersPresent =
                            areAllFiltersPresent(filters, data["genres"]);
                        if (allFiltersPresent &&
                            allData["poster_path"] != null &&
                            !containsList(seenMovies, ["Movies", data["id"]])) {
                          moviesData.add(snapshot.data());
                        }
                      }
                    } else if (allData["poster_path"] != null &&
                        !containsList(seenMovies, ["Movies", data["id"]])) {
                      moviesData.add(snapshot.data());
                    }
                  }
                }
              }
            } else {
              print('Failed to fetch countries');
            }
          } else {
            if (filters.isNotEmpty) {
              // print(data["genres"]);
              if (data.keys.toList().contains("genres")) {
                bool allFiltersPresent =
                    areAllFiltersPresent(filters, data["genres"]);
                if (allFiltersPresent &&
                    allData["poster_path"] != null &&
                    !containsList(seenMovies, ["Movies", data["id"]])) {
                  moviesData.add(snapshot.data());
                }
              }
            } else if (allData["poster_path"] != null &&
                !containsList(seenMovies, ["Movies", data["id"]])) {
              moviesData.add(snapshot.data());
            }
          }
        });
        i++;
      } else {
        break;
      }
    }
    for (var element in moviesData) {
      if (!containsMap(_items, element)) {
        _items.add(element);
        check(element["id"].toString());
      }
    }
    if (moviesData.length < 10) {
      _loadMoreItems();
    }

    genres = await _fetchGenres();
    setState(() {
      _carouselLoaded = true;
    });
  }

  void _loadMoreItems() {
    page += 1;
    getData();
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

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent ||
        _items.length < 10) {
      setState(() {
        _loadMoreItems();
      });
    }
  }

  Future<List<dynamic>> _fetchGenres() async {
    final response = await http.get(Uri.parse(GENRES_LINK));
    List<Genre> genresResult = [];
    if (response.statusCode == 200) {
      for (Map genre in jsonDecode(response.body)["genres"]) {
        if (genre["name"] != "TV Movie")
          genresResult.add(Genre(genre["name"], false));
      }
      return genresResult;
    } else {
      throw Exception('Failed to load genres');
    }
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

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
                                              fit: BoxFit.fitHeight,
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

    Widget _buildToggleViewButton() {
      return IconButton(
        icon: Icon(isGridMode ? Icons.view_carousel : Icons.grid_on),
        onPressed: () {
          setState(() {
            isGridMode = !isGridMode;
          });
        },
      );
    }

    Widget _buildFiltersSection() {
      // Replace this with your actual filters UI
      return IconButton(
        icon: Icon(isFilterOpen ? Icons.check : Icons.filter_list),
        onPressed: toggleFilter,
      );
    }

// Combine the button and the filters using Stack
    Widget _buildToggleViewAndFilters() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Call your function to build the filters section
          _buildFiltersSection(),
          // Call your function to build the button
          _buildToggleViewButton(),
        ],
      );
    }

    Widget _buildCarouselView() {
      return ListView.builder(
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          // Let's say the first item is our carousel
          if (index == 0) {
            return Center(
              child: CarouselSlider(
                options: CarouselOptions(
                  initialPage: _currentSlide,
                  enableInfiniteScroll: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentSlide = index; // Updating the current slide index
                      if (_currentSlide == _items.length - 10 ||
                          _items.length < 10) {
                        // We are at the last slide, so load more items
                        _loadMoreItems();
                      }
                    });
                  },
                  height: MediaQuery.of(context).size.height * 0.725,
                ),
                items: _items.map((item) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity:
                              _currentSlide == _items.indexOf(item) ? 1.0 : 0.3,
                          child: GestureDetector(
                            onTap: () {
                              // Handle the click event here
                              movieResult = [
                                item['id'],
                                item['title'],
                                "Movies",
                              ];
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MovieResult()),
                              );
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(27),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromARGB(
                                              255, 114, 113, 113)
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
                                    imgLink + item["poster_path"],
                                    fit: BoxFit.fitWidth,
                                  ),
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
                                margin: const EdgeInsets.fromLTRB(
                                    0.0, 10.0, 10.0, 10.0),
                                child: Image.asset(
                                  _imageSeenProviders[item["id"].toString()],
                                  height: 40,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _onTap('watchlist',
                                  item["id"].toString(), item["title"]),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                    0.0, 10.0, 10.0, 10.0),
                                child: Image.asset(
                                  _imageWatchlistProviders[
                                      item["id"].toString()],
                                  height: 40,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _onTap(
                                  'fav', item["id"].toString(), item["title"]),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                    0.0, 10.0, 10.0, 10.0),
                                child: Image.asset(
                                  _imageFavProviders[item["id"].toString()],
                                  height: 40,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _onTap(
                                  'list', item["id"].toString(), item["title"]),
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                    0.0, 10.0, 10.0, 10.0),
                                child: Image.asset(
                                  _imageListsProviders[item["id"].toString()],
                                  height: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return null;
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

              // Create your movie widget here using the data from `item`
              // For example, you can create a GestureDetector or InkWell
              // to handle movie selection or tap events.
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Handle the click event here
                        movieResult = [
                          item['id'],
                          item['title'],
                          "Movies",
                        ];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MovieResult()),
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
                              imgLink + item["poster_path"],
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
        if (isGridMode) {
          return _buildGridView();
        } else {
          return _buildCarouselView();
        }
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
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
      body: Column(
        children: [
          _buildToggleViewAndFilters(),
          Expanded(child: _buildContentView()),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isFilterOpen ? MediaQuery.of(context).size.height * 0.7 : 0,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              // color: Color.fromARGB(255, 7, 7, 7),
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
                    Text("In My Providers"),
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
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
