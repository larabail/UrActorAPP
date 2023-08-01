import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/main.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'package:uractor/search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'movie_add_popup.dart';
import 'tv_add_popup.dart';

class InfoButtonDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete List'),
      content: const Text(
        'Are you sure you want to delete this list?',
        style: TextStyle(color: Colors.red),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            print(list_result);
            // Perform the delete operation here
            playlists = {};
            await FirebaseFirestore.instance
                .collection("Watchlists")
                .doc(list_result["id"])
                .delete();
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
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => Playlists()));
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.red),
          ),
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class ListResult extends StatelessWidget {
  Map list = list_result;
  List<Map<String, dynamic>> moviesList = [];
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";

  Future<Map<String, dynamic>> getData(id, type) async {
    Map<String, dynamic> data = {};
    if (type == "TVShows") {
      link = 'https://api.themoviedb.org/3/tv/';
    } else {
      link = 'https://api.themoviedb.org/3/movie/';
    }
    final response = await http.get(Uri.parse('$link$id$api_key_actor'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (type == "TVShows") {
        data['title'] = json['name'];
      } else {
        data['title'] = json['title'];
      }
      if (json['poster_path'] == null) {
        data['poster'] = 'assets/question_mark.png';
      } else {
        data['poster'] = imgLink + json['poster_path'];
      }
      data['id'] = json['id'];
      data['type'] = type;
      if (!containsMap(moviesList, data)) {
        moviesList.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    final List<Widget> _tabPages = [
      const Center(
          child: Text(
        'Content for Tab 1',
        style: TextStyle(
            fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
      )),
      const Center(
          child: Text(
        'Content for Tab 2',
        style: TextStyle(
            fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
      )),
    ];

    final List<Widget> _pages = [
      const MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _pages[_selectedIndex]),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          title: Center(
              child: Image.asset(
            'assets/logo.png',
            height: 54,
          )),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
              height: MediaQuery.of(context).size.height * 0.25,
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
                          list['Backdrop'],
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
                        list['Name'],
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
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                        padding: const EdgeInsets.all(0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.black.withOpacity(
                              0.5), // Add black background with opacity
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            onPressed: () {
                              // Show the dialog when the info button is tapped
                              showDialog(
                                context: context,
                                builder: (context) => InfoButtonDialog(),
                              );
                            },
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                          ),
                        ])),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return MovieAddDialogue();
                      },
                    );
                  },
                  icon: const Icon(Icons.movie),
                  color: Colors.green,
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return TvAddDialogue();
                      },
                    );
                  },
                  icon: const Icon(Icons.tv),
                  color: Colors.green,
                ),
              ],
            ),
            if (list["Movies"].length > 0 && list["TVShows"].length > 0)
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Movies'),
                        Tab(text: 'TV Shows'),
                      ],
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.425,
                      child: TabBarView(
                        children: [
                          if (list["Movies"].length != 0)
                            ListView.builder(
                              itemCount: (list["Movies"].length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftMovieIndex = index * 3;
                                final middleMovieIndex = index * 3 + 1;
                                final rightMovieIndex = index * 3 + 2;
                                final leftMovie =
                                    (leftMovieIndex < list["Movies"].length)
                                        ? list["Movies"][leftMovieIndex]
                                        : null;
                                final middleMovie =
                                    (middleMovieIndex < list["Movies"].length)
                                        ? list["Movies"][middleMovieIndex]
                                        : null;
                                final rightMovie =
                                    (rightMovieIndex < list["Movies"].length)
                                        ? list["Movies"][rightMovieIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(leftMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (middleMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(middleMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (rightMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(rightMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      )
                                  ],
                                );
                              },
                            ),
                          if (list["TVShows"].length != 0)
                            ListView.builder(
                              itemCount: (list["TVShows"].length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftTVShowIndex = index * 3;
                                final middleTVShowIndex = index * 3 + 1;
                                final rightTVShowIndex = index * 3 + 2;
                                final leftTVShow =
                                    (leftTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][leftTVShowIndex]
                                        : null;
                                final middleTVShow =
                                    (middleTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][middleTVShowIndex]
                                        : null;
                                final rightTVShow =
                                    (rightTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][rightTVShowIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(leftTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (middleTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future:
                                            getData(middleTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (rightTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(rightTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
                                                  movieResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                } else {
                                                  tvShowResult = [
                                                    snapshot.data!['id'],
                                                    snapshot.data!['title'],
                                                    snapshot.data!['type'],
                                                  ];
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      )
                                  ],
                                );
                              },
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (list["Movies"].length > 0 && list["TVShows"].length == 0)
              Container(
                height: MediaQuery.of(context).size.height * 0.475,
                child: ListView.builder(
                  itemCount: (list["Movies"].length / 3).ceil(),
                  itemBuilder: (context, index) {
                    final leftMovieIndex = index * 3;
                    final middleMovieIndex = index * 3 + 1;
                    final rightMovieIndex = index * 3 + 2;
                    final leftMovie = (leftMovieIndex < list["Movies"].length)
                        ? list["Movies"][leftMovieIndex]
                        : null;
                    final middleMovie =
                        (middleMovieIndex < list["Movies"].length)
                            ? list["Movies"][middleMovieIndex]
                            : null;
                    final rightMovie = (rightMovieIndex < list["Movies"].length)
                        ? list["Movies"][rightMovieIndex]
                        : null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (leftMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(leftMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    if (snapshot.data!['type'] == "Movies") {
                                      movieResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    } else {
                                      tvShowResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              snapshot.data!['type'] == "Movies"
                                                  ? MovieResult()
                                                  : TVShowResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          snapshot.data!['poster'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
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
                        if (middleMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(middleMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    if (snapshot.data!['type'] == "Movies") {
                                      movieResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    } else {
                                      tvShowResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              snapshot.data!['type'] == "Movies"
                                                  ? MovieResult()
                                                  : TVShowResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          snapshot.data!['poster'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
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
                        if (rightMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(rightMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    if (snapshot.data!['type'] == "Movies") {
                                      movieResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    } else {
                                      tvShowResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
                                      ];
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              snapshot.data!['type'] == "Movies"
                                                  ? MovieResult()
                                                  : TVShowResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          snapshot.data!['poster'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
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
                          )
                      ],
                    );
                  },
                ),
              ),
            if (list["TVShows"].length > 0 && list["Movies"].length == 0)
              Container(
                  height: MediaQuery.of(context).size.height * 0.475,
                  child: ListView.builder(
                    itemCount: (list["TVShows"].length / 3).ceil(),
                    itemBuilder: (context, index) {
                      final leftTVShowIndex = index * 3;
                      final middleTVShowIndex = index * 3 + 1;
                      final rightTVShowIndex = index * 3 + 2;
                      final leftTVShow =
                          (leftTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][leftTVShowIndex]
                              : null;
                      final middleTVShow =
                          (middleTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][middleTVShowIndex]
                              : null;
                      final rightTVShow =
                          (rightTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][rightTVShowIndex]
                              : null;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (leftTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(leftTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
                                      if (snapshot.data!['type'] == "Movies") {
                                        movieResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      } else {
                                        tvShowResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            snapshot.data!['poster'],
                                          ),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
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
                          if (middleTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(middleTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
                                      if (snapshot.data!['type'] == "Movies") {
                                        movieResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      } else {
                                        tvShowResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            snapshot.data!['poster'],
                                          ),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
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
                          if (rightTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(rightTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
                                      if (snapshot.data!['type'] == "Movies") {
                                        movieResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      } else {
                                        tvShowResult = [
                                          snapshot.data!['id'],
                                          snapshot.data!['title'],
                                          snapshot.data!['type'],
                                        ];
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            snapshot.data!['poster'],
                                          ),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
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
                            )
                        ],
                      );
                    },
                  )),
          ],
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
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
