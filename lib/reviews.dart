import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uractor/main.dart';

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Recommendations extends StatelessWidget {
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
      link = 'https://api.themoviedb.org/3/tv/';
      type = "TVShows";
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
    }
    return data;
  }

  Widget buildReviewTile(context, Map review, String id) {
    return FutureBuilder<Map<String, dynamic>>(
        future: getData(id, "Movies"),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return ExpansionTile(
              title: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                      width: MediaQuery.of(context).size.width * 0.28,
                      height: MediaQuery.of(context).size.height * 0.18,
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
                    Text(
                      snapshot.data!["title"],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 15,
                        wordSpacing: 2,
                        height: 1.5,
                      ),
                    ),
                  ]),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.45,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                          255, 26, 25, 25), // dark grey background
                      borderRadius: BorderRadius.circular(27), // border radius
                    ),
                    padding: const EdgeInsets.all(15), // optional padding
                    child: Column(
                      children: [
                        Text(
                          'Opinion: ${review["Opinion"]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Rating: ${review["Rating"]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                                onPressed: () {
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
                                child: const Text('Info')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
        });
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
        backgroundColor: Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: ListView.builder(
        itemCount: (reviews.keys.toList().length / 2).ceil(),
        itemBuilder: (BuildContext context, int index) {
          final leftReviewIndex = index * 2;
          final rightReviewIndex = index * 2 + 1;
          final leftReviewId =
              reviews.keys.toList().reversed.toList()[leftReviewIndex];
          final rightReviewId =
              reviews.keys.toList().reversed.toList()[rightReviewIndex];
          Map leftReview = (reviews[leftReviewId]);
          Map rightReview = (reviews[rightReviewId]);
          return Row(
            children: [
              Expanded(
                child: buildReviewTile(context, leftReview, leftReviewId),
              ),
              Expanded(
                child: buildReviewTile(context, rightReview, rightReviewId),
              ),
            ],
          );
        },
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
    );
  }
}
