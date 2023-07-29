import 'package:flutter/material.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Watchlist extends StatelessWidget {
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";
  List<Map<String, dynamic>> movies = [];

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
      if (!containsMap(movies, data)) {
        movies.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    final List<Widget> _pages = [
      MyApp(),
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

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Center(
          child: Image.asset(
            'assets/logo.png',
            height: 54,
          ),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "Your Watchlist",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: TabBarView(
                    children: [
                      ListView.builder(
                        itemCount: (watchlist.length / 3).ceil(),
                        itemBuilder: (context, index) {
                          final leftMovieIndex = index * 3;
                          final middleMovieIndex = index * 3 + 1;
                          final rightMovieIndex = index * 3 + 2;
                          final leftMovie = (leftMovieIndex < watchlist.length)
                              ? watchlist[leftMovieIndex]
                              : null;
                          final middleMovie =
                              (middleMovieIndex < watchlist.length)
                                  ? watchlist[middleMovieIndex]
                                  : null;
                          final rightMovie =
                              (rightMovieIndex < watchlist.length)
                                  ? watchlist[rightMovieIndex]
                                  : null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (leftMovie != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future: getData(leftMovie![1], leftMovie[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              if (middleMovie != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      getData(middleMovie![1], middleMovie[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              if (rightMovie != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      getData(rightMovie![1], rightMovie[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                )
                            ],
                          );
                        },
                      ),
                      ListView.builder(
                        itemCount: (watchlistTVShows.length / 3).ceil(),
                        itemBuilder: (context, index) {
                          final leftTVShowIndex = index * 3;
                          final middleTVShowIndex = index * 3 + 1;
                          final rightTVShowIndex = index * 3 + 2;
                          final leftTVShow =
                              (leftTVShowIndex < watchlistTVShows.length)
                                  ? watchlistTVShows[leftTVShowIndex]
                                  : null;
                          final middleTVShow =
                              (middleTVShowIndex < watchlistTVShows.length)
                                  ? watchlistTVShows[middleTVShowIndex]
                                  : null;
                          final rightTVShow =
                              (rightTVShowIndex < watchlistTVShows.length)
                                  ? watchlistTVShows[rightTVShowIndex]
                                  : null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (leftTVShow != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      getData(leftTVShow![1], leftTVShow[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              if (middleTVShow != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future: getData(
                                      middleTVShow![1], middleTVShow[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              if (rightTVShow != null)
                                FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      getData(rightTVShow![1], rightTVShow[0]),
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
                                                    snapshot.data!['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
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
                                        child: CircularProgressIndicator(),
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
    );
  }
}
