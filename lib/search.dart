// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'playlists.dart';
import 'person_result.dart';
import 'profile.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String _searchTermActor = '';
String _searchTermMovie = '';
String _searchTermTVShow = '';
String _selectedItem = 'actor';

class Search extends StatefulWidget {
  Search();

  @override
  _SearchResultState createState() => _SearchResultState();
}

class _SearchResultState extends State<Search> {
  // Define a TabController to manage the TabBar and TabBarView

// Initialize the TabController in the State's initState method

  Future<List<String>> _search() async {
    // Replace this with your actual async search logic
    await Future.delayed(const Duration(seconds: 2));
    return ['result 1', 'result 2', 'result 3'];
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;
    String searchByName =
        'https://api.themoviedb.org/3/search/person?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
    String linkMovie = "https://api.themoviedb.org/3/movie/";
    String searchByNamemovie =
        'https://api.themoviedb.org/3/search/movie?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
    String linkTVSHOW = "https://api.themoviedb.org/3/tv/";
    String searchByNametvshow =
        'https://api.themoviedb.org/3/search/tv?api_key=700cd4fab994df56eb41b34d38c4762a&query=';

    String apiKeyActor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
    String link = "https://api.themoviedb.org/3/person/";
    String img = 'https://image.tmdb.org/t/p/w500/';

    Future<List> searchData() async {
      List<Map<String, dynamic>> results = [];
      String searchLink = "";
      if (_searchTermActor != "" ||
          _searchTermMovie != "" ||
          _searchTermTVShow != "") {
        if (_selectedItem == "actor") {
          searchLink =
              '$searchByName${_searchTermActor.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
        } else if (_selectedItem == "movie") {
          searchLink =
              '$searchByNamemovie${_searchTermMovie.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
        } else if (_selectedItem == "tvshow") {
          searchLink =
              '$searchByNametvshow${_searchTermTVShow.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
        }
        final response = await http.get(Uri.parse(searchLink));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          for (final result in json['results']) {
            String resultSearchLink = '';
            if (_selectedItem == "actor" && _searchTermActor != "") {
              resultSearchLink =
                  '$link${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            } else if (_selectedItem == "movie" && _searchTermMovie != "") {
              resultSearchLink =
                  '$linkMovie${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            } else if (_selectedItem == "tvshow" && _searchTermTVShow != "") {
              resultSearchLink =
                  '$linkTVSHOW${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            }
            if (resultSearchLink != "") {
              final response2 = await http.get(Uri.parse(resultSearchLink));
              if (response2.statusCode == 200) {
                final json2 = jsonDecode(response2.body);
                results.add(json2);
              } else {
                throw Exception('Failed to load movie details');
              }
            }
          }
        }
      }
      return results;
    }

    final List<Widget> pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
          child: Image.asset(
          'assets/logo_character.png',
            height: 54,
          ),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: null,
              unselectedLabelColor: null,
              tabs: [
                Tab(text: 'Person'),
                Tab(text: 'Movie'),
                Tab(text: 'TV Show'),
              ],
            ),
            SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: TabBarView(
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height,
                      margin: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Enter name of actor...',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchTermActor = value;
                                _searchTermMovie = "";
                                _searchTermTVShow = "";
                              });
                            },
                            onSubmitted: (value) {
                              setState(() {
                                _searchTermActor = value;
                                _searchTermMovie = "";
                                _searchTermTVShow = "";
                              });
                            },
                          ),
                          Expanded(
                            child: FutureBuilder<List>(
                              future: searchData(),
                              builder: (context, snapshot) {
                                int selectedTabIndex =
                                    DefaultTabController.of(context).index;
                                switch (selectedTabIndex) {
                                  case 0:
                                    // 'Actor' tab is selected
                                    _selectedItem = 'actor';
                                    break;
                                  case 1:
                                    // 'Director' tab is selected
                                    _selectedItem = 'movie';
                                    break;
                                  case 2:
                                    // 'Movie' tab is selected
                                    _selectedItem = 'tvshow';
                                    break;
                                }
                                if (snapshot.hasData) {
                                  final people = snapshot.data!;
                                  return SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: (people.length / 3).ceil(),
                                      itemBuilder: (context, index) {
                                        final leftPersonIndex = index * 3;
                                        final middlePersonIndex = index * 3 + 1;
                                        final rightPersonIndex = index * 3 + 2;
                                        final leftPerson =
                                            (leftPersonIndex < people.length)
                                                ? people[leftPersonIndex]
                                                : null;
                                        final middlePerson =
                                            (middlePersonIndex < people.length)
                                                ? people[middlePersonIndex]
                                                : null;
                                        final rightPerson =
                                            (rightPersonIndex < people.length)
                                                ? people[rightPersonIndex]
                                                : null;
                                        if (leftPerson != null) {
                                          if (leftPerson['profile_path'] ==
                                              null) {
                                            leftPerson['profile_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (leftPerson[
                                                  'profile_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            leftPerson['profile_path'] = img +
                                                leftPerson['profile_path'];
                                          }
                                        }
                                        if (middlePerson != null) {
                                          if (middlePerson['profile_path'] ==
                                              null) {
                                            middlePerson['profile_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (middlePerson[
                                                  'profile_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            middlePerson['profile_path'] = img +
                                                middlePerson['profile_path'];
                                          }
                                        }
                                        if (rightPerson != null) {
                                          if (rightPerson['profile_path'] ==
                                              null) {
                                            rightPerson['profile_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (rightPerson[
                                                  'profile_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            rightPerson['profile_path'] = img +
                                                rightPerson['profile_path'];
                                          }
                                        }
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            if (leftPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  personResult = leftPerson;
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            PersonResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          10.0, 10.0, 5.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          leftPerson[
                                                              'profile_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (middlePerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  personResult = middlePerson;
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            PersonResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 5.0,
                                                      vertical: 10.0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          middlePerson[
                                                              'profile_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (rightPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  personResult = rightPerson;
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            PersonResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          5.0, 10.0, 10.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                        rightPerson[
                                                            'profile_path'],
                                                      ),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Failed to load movie details",
                                    ),
                                  );
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Enter name of movie...',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchTermMovie = value;
                                _searchTermActor = "";
                                _searchTermTVShow = "";
                              });
                            },
                            onSubmitted: (value) {
                              setState(() {
                                _searchTermMovie = value;
                                _searchTermActor = "";
                                _searchTermTVShow = "";
                              });
                            },
                          ),
                          Expanded(
                            child: FutureBuilder<List>(
                              future: searchData(),
                              builder: (context, snapshot) {
                                int selectedTabIndex =
                                    DefaultTabController.of(context).index;
                                switch (selectedTabIndex) {
                                  case 0:
                                    // 'Actor' tab is selected
                                    _selectedItem = 'actor';
                                    break;
                                  case 1:
                                    // 'Director' tab is selected
                                    _selectedItem = 'movie';
                                    break;
                                  case 2:
                                    // 'Movie' tab is selected
                                    _selectedItem = 'tvshow';
                                    break;
                                }
                                if (snapshot.hasData) {
                                  final people = snapshot.data!;
                                  return SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: (people.length / 3).ceil(),
                                      itemBuilder: (context, index) {
                                        final leftPersonIndex = index * 3;
                                        final middlePersonIndex = index * 3 + 1;
                                        final rightPersonIndex = index * 3 + 2;
                                        final leftPerson =
                                            (leftPersonIndex < people.length)
                                                ? people[leftPersonIndex]
                                                : null;
                                        final middlePerson =
                                            (middlePersonIndex < people.length)
                                                ? people[middlePersonIndex]
                                                : null;
                                        final rightPerson =
                                            (rightPersonIndex < people.length)
                                                ? people[rightPersonIndex]
                                                : null;
                                        if (leftPerson != null) {
                                          if (leftPerson['poster_path'] ==
                                              null) {
                                            leftPerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (leftPerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            leftPerson['poster_path'] =
                                                img + leftPerson['poster_path'];
                                          }
                                        }
                                        if (middlePerson != null) {
                                          if (middlePerson['poster_path'] ==
                                              null) {
                                            middlePerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (middlePerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            middlePerson['poster_path'] = img +
                                                middlePerson['poster_path'];
                                          }
                                        }
                                        if (rightPerson != null) {
                                          if (rightPerson['poster_path'] ==
                                              null) {
                                            rightPerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (rightPerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            rightPerson['poster_path'] = img +
                                                rightPerson['poster_path'];
                                          }
                                        }
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            if (leftPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  movieResult = [
                                                    leftPerson['id'],
                                                    leftPerson['title'],
                                                    "Movies",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            MovieResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          10.0, 10.0, 5.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          leftPerson[
                                                              'poster_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (middlePerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  movieResult = [
                                                    middlePerson['id'],
                                                    middlePerson['title'],
                                                    "Movies",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            MovieResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 5.0,
                                                      vertical: 10.0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          middlePerson[
                                                              'poster_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (rightPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  movieResult = [
                                                    rightPerson['id'],
                                                    rightPerson['title'],
                                                    "Movies",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            MovieResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          5.0, 10.0, 10.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                        rightPerson[
                                                            'poster_path'],
                                                      ),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Failed to load movie details",
                                    ),
                                  );
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Enter name of show...',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchTermTVShow = value;
                                _searchTermMovie = "";
                                _searchTermActor = "";
                              });
                            },
                            onSubmitted: (value) {
                              setState(() {
                                _searchTermTVShow = value;
                                _searchTermMovie = "";
                                _searchTermActor = "";
                              });
                            },
                          ),
                          Expanded(
                            child: FutureBuilder<List>(
                              future: searchData(),
                              builder: (context, snapshot) {
                                int selectedTabIndex =
                                    DefaultTabController.of(context).index;
                                switch (selectedTabIndex) {
                                  case 0:
                                    // 'Actor' tab is selected
                                    _selectedItem = 'actor';
                                    break;
                                  case 1:
                                    // 'Director' tab is selected
                                    _selectedItem = 'movie';
                                    break;
                                  case 2:
                                    // 'Movie' tab is selected
                                    _selectedItem = 'tvshow';
                                    break;
                                }
                                if (snapshot.hasData) {
                                  final people = snapshot.data!;
                                  return SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: (people.length / 3).ceil(),
                                      itemBuilder: (context, index) {
                                        final leftPersonIndex = index * 3;
                                        final middlePersonIndex = index * 3 + 1;
                                        final rightPersonIndex = index * 3 + 2;
                                        final leftPerson =
                                            (leftPersonIndex < people.length)
                                                ? people[leftPersonIndex]
                                                : null;
                                        final middlePerson =
                                            (middlePersonIndex < people.length)
                                                ? people[middlePersonIndex]
                                                : null;
                                        final rightPerson =
                                            (rightPersonIndex < people.length)
                                                ? people[rightPersonIndex]
                                                : null;
                                        if (leftPerson != null) {
                                          if (leftPerson['poster_path'] ==
                                              null) {
                                            leftPerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (leftPerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            leftPerson['poster_path'] =
                                                img + leftPerson['poster_path'];
                                          }
                                        }
                                        if (middlePerson != null) {
                                          if (middlePerson['poster_path'] ==
                                              null) {
                                            middlePerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (middlePerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            middlePerson['poster_path'] = img +
                                                middlePerson['poster_path'];
                                          }
                                        }
                                        if (rightPerson != null) {
                                          if (rightPerson['poster_path'] ==
                                              null) {
                                            rightPerson['poster_path'] =
                                                'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                          } else if (rightPerson[
                                                  'poster_path'] !=
                                              'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                            rightPerson['poster_path'] = img +
                                                rightPerson['poster_path'];
                                          }
                                        }
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            if (leftPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  tvShowResult = [
                                                    leftPerson['id'],
                                                    leftPerson['name'],
                                                    "TVShows",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            TVShowResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          10.0, 10.0, 5.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          leftPerson[
                                                              'poster_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (middlePerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  tvShowResult = [
                                                    middlePerson['id'],
                                                    middlePerson['name'],
                                                    "TVShows",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            TVShowResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 5.0,
                                                      vertical: 10.0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                          middlePerson[
                                                              'poster_path']),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (rightPerson != null)
                                              GestureDetector(
                                                onTap: () {
                                                  tvShowResult = [
                                                    rightPerson['id'],
                                                    rightPerson['name'],
                                                    "TVShows",
                                                  ];
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            TVShowResult()),
                                                  );
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.fromLTRB(
                                                          5.0, 10.0, 10.0, 0),
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.25,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.18,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            27),
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                        rightPerson[
                                                            'poster_path'],
                                                      ),
                                                      fit: BoxFit.fitWidth,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      "Failed to load movie details",
                                    ),
                                  );
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
        currentIndex: 1,
        onTap: _onItemTapped,
      ),
    );
  }
}
