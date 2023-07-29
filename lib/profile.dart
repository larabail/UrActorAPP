import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/person_result.dart';
import 'package:uractor/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
final String imgLink = 'https://image.tmdb.org/t/p/w500/';

class Profile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    Future<List<Map<String, dynamic>>> actorData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favActors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load actor details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

    Future<List<Map<String, dynamic>>> dirData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favDirectors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load director details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

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
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/main_profile.png',
                      height: 200,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              "($country)",
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        )),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Favorite Actors'),
                              Tab(text: 'Favorite Directors'),
                            ],
                          ),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.46,
                            child: TabBarView(
                              children: [
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: actorData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
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
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
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
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
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
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: dirData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
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
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
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
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.logout_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                Future<void> _signOut() async {
                  await FirebaseAuth.instance.signOut();
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
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
        currentIndex: 3,
        onTap: _onItemTapped,
      ),
    );
  }
}
