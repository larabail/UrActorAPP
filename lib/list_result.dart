import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/main.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/search.dart';
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

class ListResult extends StatelessWidget {
  Map list = list_result;
  List moviesList = [];
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";

  Future<List<Map<String, dynamic>>> movieData() async {
    for (var element in list['Movies']) {
      moviesList += [
        ["Movies", element]
      ];
    }
    for (var element in list['TVShows']) {
      moviesList += [
        ["TVShows", element]
      ];
    }
    List<Map<String, dynamic>> movies = [];
    for (var element in moviesList) {
      String type = element[0];
      String id = element[1];
      Map<String, dynamic> data = {};
      if (type == "TVShows") {
        link = "https://api.themoviedb.org/3/tv/";
      } else {
        link = "https://api.themoviedb.org/3/movie/";
      }
      final response =
          await http.get(Uri.parse('${link}${id}${api_key_actor}'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (type == "TVShows") {
          data['title'] = data['name'];
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

    return movies;
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Color(0xFF121212),
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
                    padding: EdgeInsets.all(16.0),
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
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 425,
                child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          final leftMovie = (leftMovieIndex < movies.length)
                              ? movies[leftMovieIndex]
                              : null;
                          final middleMovie = (middleMovieIndex < movies.length)
                              ? movies[middleMovieIndex]
                              : null;
                          final rightMovie = (rightMovieIndex < movies.length)
                              ? movies[rightMovieIndex]
                              : null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (leftMovie != null)
                                GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    movieResult = [
                                      leftMovie['id'],
                                      leftMovie['title'],
                                      leftMovie['type'],
                                    ];
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MovieResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        10.0, 10.0, 5.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image:
                                            NetworkImage(leftMovie['poster']),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              if (middleMovie != null)
                                GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    movieResult = [
                                      middleMovie['id'],
                                      middleMovie['title'],
                                      middleMovie['type'],
                                    ];
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MovieResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 10.0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image:
                                            NetworkImage(middleMovie['poster']),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              if (rightMovie != null)
                                GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
                                    movieResult = [
                                      rightMovie['id'],
                                      rightMovie['title'],
                                      rightMovie['type'],
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
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
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
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Colors.grey,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Color(0xFF121212),
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
