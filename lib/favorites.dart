import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Favorites extends StatelessWidget {
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";

  Future<List<Map<String, dynamic>>> movieData() async {
    if (favsPage.length == 0) {
      List<Map<String, dynamic>> movies = [];
      for (var element in favMovies.reversed.toList()) {
        Map<String, dynamic> data = {};
        dynamic type = element[0];
        dynamic id = element[1];
        if (type == "TVShows") {
          link = 'https://api.themoviedb.org/3/tv/';
        } else {
          link = 'https://api.themoviedb.org/3/movie/';
        }
        final response =
            await http.get(Uri.parse('${link}${id}${api_key_actor}'));
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
      }
      favsPage = movies;
      return movies;
    } else {
      return favsPage;
    }
  }

  Future<List<Map<String, dynamic>>> tvshowData() async {
    if (favsPageTVShows.length == 0) {
      List<Map<String, dynamic>> movies = [];
      for (var element in favTVShows.reversed.toList()) {
        Map<String, dynamic> data = {};
        dynamic type = element[0];
        dynamic id = element[1];
        if (type == "TVShows") {
          link = 'https://api.themoviedb.org/3/tv/';
        } else {
          link = 'https://api.themoviedb.org/3/movie/';
        }
        final response =
            await http.get(Uri.parse('${link}${id}${api_key_actor}'));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (type == "TVShows") {
            data['title'] = json['name'];
          } else {
            data['title'] = json['title'];
          }
          data['poster'] = imgLink + json['poster_path'];
          data['id'] = json['id'];
          if (!containsMap(movies, data)) {
            movies.add(data);
          }
        } else {
          throw Exception('Failed to load movie details');
        }
      }
      favsPageTVShows = movies;
      return movies;
    } else {
      return favsPageTVShows;
    }
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
              "Your Favorites",
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
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: movieData(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final movies = snapshot.data!;
                            return ListView.builder(
                              itemCount: (movies.length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftMovieIndex = index * 3;
                                final middleMovieIndex = index * 3 + 1;
                                final rightMovieIndex = index * 3 + 2;
                                final leftMovie =
                                    (leftMovieIndex < movies.length)
                                        ? movies[leftMovieIndex]
                                        : null;
                                final middleMovie =
                                    (middleMovieIndex < movies.length)
                                        ? movies[middleMovieIndex]
                                        : null;
                                final rightMovie =
                                    (rightMovieIndex < movies.length)
                                        ? movies[rightMovieIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          // Handle the click event here
                                          if (leftMovie['type'] == "Movies") {
                                            movieResult = [
                                              leftMovie['id'],
                                              leftMovie['title'],
                                              leftMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              leftMovie['id'],
                                              leftMovie['title'],
                                              leftMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    leftMovie['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                              10.0, 10.0, 5.0, 0),
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
                                                  leftMovie['poster']),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (middleMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          if (middleMovie['type'] == "Movies") {
                                            movieResult = [
                                              middleMovie['id'],
                                              middleMovie['title'],
                                              middleMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              middleMovie['id'],
                                              middleMovie['title'],
                                              middleMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    middleMovie['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 5.0, vertical: 10.0),
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
                                                  middleMovie['poster']),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (rightMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          // Handle the click event here
                                          if (rightMovie['type'] == "Movies") {
                                            movieResult = [
                                              rightMovie['id'],
                                              rightMovie['title'],
                                              rightMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              rightMovie['id'],
                                              rightMovie['title'],
                                              rightMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    rightMovie['type'] ==
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
                                                rightMovie['poster'],
                                              ),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
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
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: tvshowData(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final movies = snapshot.data!;
                            return ListView.builder(
                              itemCount: (movies.length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftMovieIndex = index * 3;
                                final middleMovieIndex = index * 3 + 1;
                                final rightMovieIndex = index * 3 + 2;
                                final leftMovie =
                                    (leftMovieIndex < movies.length)
                                        ? movies[leftMovieIndex]
                                        : null;
                                final middleMovie =
                                    (middleMovieIndex < movies.length)
                                        ? movies[middleMovieIndex]
                                        : null;
                                final rightMovie =
                                    (rightMovieIndex < movies.length)
                                        ? movies[rightMovieIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          // Handle the click event here
                                          if (leftMovie['type'] == "Movies") {
                                            movieResult = [
                                              leftMovie['id'],
                                              leftMovie['title'],
                                              leftMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              leftMovie['id'],
                                              leftMovie['title'],
                                              leftMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    leftMovie['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                              10.0, 10.0, 5.0, 0),
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
                                                  leftMovie['poster']),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (middleMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          if (middleMovie['type'] == "Movies") {
                                            movieResult = [
                                              middleMovie['id'],
                                              middleMovie['title'],
                                              middleMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              middleMovie['id'],
                                              middleMovie['title'],
                                              middleMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    middleMovie['type'] ==
                                                            "Movies"
                                                        ? MovieResult()
                                                        : TVShowResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 5.0, vertical: 10.0),
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
                                                  middleMovie['poster']),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (rightMovie != null)
                                      GestureDetector(
                                        onTap: () {
                                          // Handle the click event here
                                          if (rightMovie['type'] == "Movies") {
                                            movieResult = [
                                              rightMovie['id'],
                                              rightMovie['title'],
                                              rightMovie['type'],
                                            ];
                                          } else {
                                            tvShowResult = [
                                              rightMovie['id'],
                                              rightMovie['title'],
                                              rightMovie['type'],
                                            ];
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    rightMovie['type'] ==
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
                                                rightMovie['poster'],
                                              ),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
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
