import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uractor/playlists.dart';
import 'package:flutter/services.dart' show rootBundle;

final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
final String imgLink = 'https://image.tmdb.org/t/p/w500/';
String api_key_movie =
    '/movie_credits?api_key=700cd4fab994df56eb41b34d38c4762a';
String api_key_tv = '/tv_credits?api_key=700cd4fab994df56eb41b34d38c4762a';
String link = "https://api.themoviedb.org/3/person/";

Future<String> _loadJSONFile() async {
  return await rootBundle.loadString('assets/oscars_api.json');
}

// Future<Map> parseJSONFile() async {
//   if (oscars.length == 0) {
//     Map people = {};
//     String jsonString = await _loadJSONFile();
//     Map items = jsonDecode(jsonString);
//     for (String person_id in items.keys) {
//       Map<String, dynamic> person = {};
//       Map person_to_add = {};
//       link = 'https://api.themoviedb.org/3/person/';
//       final response = await http.get(
//           Uri.parse('${link}${items[person_id]['tmdb_id']}${api_key_actor}'));
//       if (response.statusCode == 200) {
//         final json = jsonDecode(response.body);
//         if (json['profile_path'] != null) {
//           items[person_id]['profile_path'] = imgLink + json['profile_path'];
//         } else {
//           items[person_id]['profile_path'] =
//               "https://cdn-icons-png.flaticon.com/512/3088/3088765.png";
//         }
//         people[items[person_id]['tmdb_id']] = items[person_id];
//       } else {
//         throw Exception('Failed to load movie details');
//       }
//     }
//     oscars = people;
//     return people;
//   } else {
//     return oscars;
//   }
// }

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class PersonResult extends StatefulWidget {
  PersonResult();

  @override
  _PersonResultState createState() => _PersonResultState();
}

class _PersonResultState extends State<PersonResult> {
  Map presult = personResult;

  Future<Map> getPersonData() async {
    Map json = {};
    String name = presult['name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response = await http
        .get(Uri.parse('${link}${presult["id"]}-${name}${api_key_actor}'));
    json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final r2 = await http
          .get(Uri.parse('${link}${presult["id"]}-${name}${api_key_movie}'));
      if (r2.statusCode == 200) {
        json['movie_credits_cast'] = jsonDecode(r2.body)['cast'];
        final r3 = await http
            .get(Uri.parse('${link}${presult["id"]}-${name}${api_key_tv}'));
        if (r3.statusCode == 200) {
          json['tv_credits_cast'] = jsonDecode(r3.body)['cast'];
        } else {
          throw Exception('Failed to load movie details');
        }
        json['movie_credits_crew'] = jsonDecode(r2.body)['crew'];
        final r4 = await http
            .get(Uri.parse('${link}${presult["id"]}-${name}${api_key_tv}'));
        if (r4.statusCode == 200) {
          json['tv_credits_crew'] = jsonDecode(r4.body)['crew'];
          // Map oscars = await parseJSONFile();
          if (oscars.keys.contains(presult["id"])) {
            json['num_oscars'] = oscars[presult["id"]]['num_oscars'];
            print(json['num_oscars']);
          } else {
            json['num_oscars'] = 0;
          }
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
      body: FutureBuilder<Map>(
        future: getPersonData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.data!['num_oscars'] != 0)
                    Center(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.075,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              snapshot.data!['num_oscars'],
                              (index) => Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.075,
                                child: Image.asset("assets/oscar2.png"),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: MediaQuery.of(context).size.width * 0.55,
                      margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: 1,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              //
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.18,
                              height: MediaQuery.of(context).size.height * 0.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                image: DecorationImage(
                                  image: NetworkImage(
                                      imgLink + snapshot.data!['profile_path']),
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      child: Text(
                        snapshot.data!['name'],
                        style: TextStyle(color: Colors.white, fontSize: 30),
                      ),
                    ),
                  ),
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'As Part of the Cast'),
                            Tab(text: 'As Part of the Crew'),
                          ],
                        ),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.46,
                          child: TabBarView(
                            children: [
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
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'movie_credits_cast']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie = (middleMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [middleMovieIndex]
                                                  : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [rightMovieIndex]
                                                  : null;
                                              if (leftMovie != null) {
                                                if (leftMovie['poster_path'] ==
                                                    null) {
                                                  leftMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              if (middleMovie != null) {
                                                if (middleMovie[
                                                        'poster_path'] ==
                                                    null) {
                                                  middleMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }

                                              if (rightMovie != null) {
                                                if (rightMovie['poster_path'] ==
                                                    null) {
                                                  rightMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          leftMovie['id'],
                                                          leftMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          leftMovie, "Movies"),
                                                    ),
                                                  if (middleMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          middleMovie['id'],
                                                          middleMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          middleMovie,
                                                          "Movies"),
                                                    ),
                                                  if (rightMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          rightMovie['id'],
                                                          rightMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          rightMovie, "Movies"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'tv_credits_cast']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_cast']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie =
                                                  (middleMovieIndex <
                                                          snapshot
                                                              .data![
                                                                  'tv_credits_cast']
                                                              .length)
                                                      ? snapshot.data![
                                                              'tv_credits_cast']
                                                          [middleMovieIndex]
                                                      : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_cast']
                                                      [rightMovieIndex]
                                                  : null;
                                              if (leftMovie != null) {
                                                if (leftMovie['poster_path'] ==
                                                    null) {
                                                  leftMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              if (middleMovie != null) {
                                                if (middleMovie[
                                                        'poster_path'] ==
                                                    null) {
                                                  middleMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }

                                              if (rightMovie != null) {
                                                if (rightMovie['poster_path'] ==
                                                    null) {
                                                  rightMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          leftMovie['id'],
                                                          leftMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          leftMovie, "TVShows"),
                                                    ),
                                                  if (middleMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          middleMovie['id'],
                                                          middleMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          middleMovie,
                                                          "TVShows"),
                                                    ),
                                                  if (rightMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          rightMovie['id'],
                                                          rightMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          rightMovie,
                                                          "TVShows"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'movie_credits_crew']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie = (middleMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [middleMovieIndex]
                                                  : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [rightMovieIndex]
                                                  : null;
                                              if (leftMovie != null) {
                                                if (leftMovie['poster_path'] ==
                                                    null) {
                                                  leftMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              if (middleMovie != null) {
                                                if (middleMovie[
                                                        'poster_path'] ==
                                                    null) {
                                                  middleMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }

                                              if (rightMovie != null) {
                                                if (rightMovie['poster_path'] ==
                                                    null) {
                                                  rightMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          leftMovie['id'],
                                                          leftMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          leftMovie, "Movies"),
                                                    ),
                                                  if (middleMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          middleMovie['id'],
                                                          middleMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          middleMovie,
                                                          "Movies"),
                                                    ),
                                                  if (rightMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          rightMovie['id'],
                                                          rightMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          rightMovie, "Movies"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'tv_credits_crew']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_crew']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie =
                                                  (middleMovieIndex <
                                                          snapshot
                                                              .data![
                                                                  'tv_credits_crew']
                                                              .length)
                                                      ? snapshot.data![
                                                              'tv_credits_crew']
                                                          [middleMovieIndex]
                                                      : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_crew']
                                                      [rightMovieIndex]
                                                  : null;
                                              if (leftMovie != null) {
                                                if (leftMovie['poster_path'] ==
                                                    null) {
                                                  leftMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              if (middleMovie != null) {
                                                if (middleMovie[
                                                        'poster_path'] ==
                                                    null) {
                                                  middleMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              if (rightMovie != null) {
                                                if (rightMovie['poster_path'] ==
                                                    null) {
                                                  rightMovie['poster_path'] =
                                                      snapshot.data![
                                                          'profile_path'];
                                                }
                                              }
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          leftMovie['id'],
                                                          leftMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          leftMovie, "TVShows"),
                                                    ),
                                                  if (middleMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          middleMovie['id'],
                                                          middleMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          middleMovie,
                                                          "TVShows"),
                                                    ),
                                                  if (rightMovie != null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          rightMovie['id'],
                                                          rightMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          rightMovie,
                                                          "TVShows"),
                                                    ),
                                                ],
                                              );
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
                        ),
                      ],
                    ),
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
            MaterialPageRoute(builder: (context) => _pages[index]),
          );
        },
      ),
    );
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

  seen(BuildContext context, movie, type) {
    if (!containsMap(seenMovies, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Container(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
                  Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Container(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  seenCrew(BuildContext context, movie, type) {
    if (!containsMap(seenMovies, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Container(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 0, 0).withOpacity(0.75),
                  Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Container(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}
