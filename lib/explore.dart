// ignore_for_file: no_leading_underscores_for_local_identifiers, constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/rating_popup.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uractor/main.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'login.dart';

const String api_key_actor =
    "?api_key=700cd4fab994df56eb41b34d38c4762a&include_adult=false&include_video=false&language=en-US&page=1&sort_by=popularity.desc&adult=false&region=US";
const String imgLink = 'https://image.tmdb.org/t/p/w500/';
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
Map _isListsTapped = {};

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
Future<List> getData() async {
  List data = [];
  List moviesData = [];
  await FirebaseFirestore.instance
            .collection("ExplorePage")
            .get().then((QuerySnapshot querySnapshot) {
          for (var doc in querySnapshot.docs) {
            Map movieData = doc.data() as Map;
            moviesData.add(movieData);
          }});
  // final response =
  //     await http.get(Uri.parse('$popularMoviesLink$api_key_actor&page=$page'));
  // if (response.statusCode == 200) {
  //   final json = jsonDecode(response.body);
  //   data = json["results"];
  // } else {
  //   throw Exception('Failed to load movie details');
  // }
  newItems = moviesData.length;
  for (var element in moviesData) {
    if (!containsMap(_items, element) &&
        !containsList(seenMovies, ['Movies', element["id"].toString()]) &&
        !element["adult"] &&
        element["original_language"] == "en") {
      _items.add(element);
      check(element["id"].toString());
    }
  }
  return _items;
}

class Explore extends StatefulWidget {
  Explore();

  @override
  _ExploreState createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  int _currentSlide = 0;
  List<Map<String, dynamic>> movies = [];

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      const MyApp(),
      Search(),
      Playlists(),
      Profile(),
    ];
    void _loadMoreItems() {
      // Usually this should be an asynchronous function where you communicate with your backend
      // and fetch new items. Once you have the new items, you add them to your _items list.
      // Here we just add 3 more dummy items to the list for simplicity.
      page += 1;
      getData();
    }

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
      body: ListView.builder(
        itemCount: 5, // The number of items in the list
        itemBuilder: (BuildContext context, int index) {
          // Let's say the first item is our carousel
          if (index == 0) {
            return FutureBuilder<List>(
              future: getData(),
              builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
                if (snapshot.hasData) {
                  return Center(
                      child: CarouselSlider(
                    options: CarouselOptions(
                      enableInfiniteScroll: false,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentSlide =
                              index; // Updating the current slide index
                          if (_currentSlide == _items.length - 1) {
                            // We are at the last slide, so load more items
                            _loadMoreItems();
                          }
                        });
                      },
                      height: MediaQuery.of(context).size.height * 0.8,
                    ),
                    items: _items.asMap().entries.map((entry) {
                      int index = entry.key;
                      var item = entry.value;
                      return Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center, // Centers the column
                          children: [
                            Opacity(
                              opacity: _currentSlide == index
                                  ? 1.0
                                  : 0.3, // Change opacity based on focused slide
                              child: GestureDetector(
                                onTap: () {
                                  // Handle the click event here
                                  movieResult = [
                                    item!['id'],
                                    item!['title'],
                                    "Movies",
                                  ];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => MovieResult()),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      5.0, 10.0, 10.0, 0),
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
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
                                          offset: const Offset(2,
                                              2), // changes position of shadow
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
                                height:
                                    10.0), // You can adjust this value as needed
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => _onTap('seen',
                                      item["id"].toString(), item["title"]),
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        0.0, 10.0, 10.0, 10.0),
                                    child: Image.asset(
                                      _imageSeenProviders[
                                          item["id"].toString()],
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
                                  onTap: () => _onTap('fav',
                                      item["id"].toString(), item["title"]),
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
                                  onTap: () => _onTap('list',
                                      item["id"].toString(), item["title"]),
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        0.0, 10.0, 10.0, 10.0),
                                    child: Image.asset(
                                      _imageListsProviders[
                                          item["id"].toString()],
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
                  ));
                } else if (snapshot.hasError) {
                  return Text('Something went wrong...');
                }
                // While fetching, show a loading spinner.
                return CircularProgressIndicator();
              },
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
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
