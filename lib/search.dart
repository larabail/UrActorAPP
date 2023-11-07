// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String _searchTermActor = '';

class Search extends StatefulWidget {
  Search();

  @override
  _SearchResultState createState() => _SearchResultState();
}

class _SearchResultState extends State<Search> {
  @override
  Widget build(BuildContext context) {
    String searchByName =
        'https://api.themoviedb.org/3/search/multi?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
    String linkMovie = "https://api.themoviedb.org/3/movie/";
    String linkTVSHOW = "https://api.themoviedb.org/3/tv/";

    String apiKeyActor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
    String link = "https://api.themoviedb.org/3/person/";
    String img = 'https://image.tmdb.org/t/p/w500/';

    Future<List> searchData() async {
      List<Map<String, dynamic>> results = [];
      String searchLink = "";
      if (_searchTermActor != "") {
        searchLink =
            '$searchByName${_searchTermActor.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
        final response = await http.get(Uri.parse(searchLink));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          for (final result in json['results']) {
            String resultSearchLink = '';
            Map jsonResult = result as Map;
            if (jsonResult.keys.contains("profile_path")) {
              resultSearchLink =
                  '$link${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            } else if (jsonResult.keys.contains("title") &&
                jsonResult.keys.contains("poster_path")) {
              resultSearchLink =
                  '$linkMovie${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            } else if (jsonResult.keys.contains("name") &&
                jsonResult.keys.contains("poster_path")) {
              resultSearchLink =
                  '$linkTVSHOW${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$apiKeyActor';
            }
            if (resultSearchLink != "") {
              final response2 = await http.get(Uri.parse(resultSearchLink));
              if (response2.statusCode == 200) {
                final json2 = jsonDecode(response2.body);
                if (json2.keys.contains("poster_path")) {
                  json2["profile_path"] = json2["poster_path"];
                }
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

    return Scaffold(
      appBar: CustomAppBar(),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            SingleChildScrollView(
              child: Container(
                child: Container(
                  height: MediaQuery.of(context).size.height - 176,
                  margin: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Enter name of person/movie/show...',
                          hintStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchTermActor = value;
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            _searchTermActor = value;
                          });
                        },
                      ),
                      Expanded(
                        child: FutureBuilder<List>(
                          future: searchData(),
                          builder: (context, snapshot) {
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
                                      if (leftPerson['profile_path'] == null) {
                                        leftPerson['profile_path'] =
                                            'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                      } else if (leftPerson['profile_path'] !=
                                          'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                        leftPerson['profile_path'] =
                                            img + leftPerson['profile_path'];
                                      }
                                    }
                                    if (middlePerson != null) {
                                      if (middlePerson['profile_path'] ==
                                          null) {
                                        middlePerson['profile_path'] =
                                            'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                      } else if (middlePerson['profile_path'] !=
                                          'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                        middlePerson['profile_path'] =
                                            img + middlePerson['profile_path'];
                                      }
                                    }
                                    if (rightPerson != null) {
                                      if (rightPerson['profile_path'] == null) {
                                        rightPerson['profile_path'] =
                                            'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
                                      } else if (rightPerson['profile_path'] !=
                                          'https://cdn-icons-png.flaticon.com/512/3088/3088765.png') {
                                        rightPerson['profile_path'] =
                                            img + rightPerson['profile_path'];
                                      }
                                    }
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        if (leftPerson != null)
                                          GestureDetector(
                                            onTap: () {
                                              if (leftPerson.keys.contains(
                                                      "poster_path") &&
                                                  leftPerson.keys
                                                      .contains("title")) {
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
                                              } else if (leftPerson.keys
                                                      .contains(
                                                          "poster_path") &&
                                                  leftPerson.keys
                                                      .contains("name")) {
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
                                              } else {
                                                personResult = leftPerson;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          PersonResult()),
                                                );
                                              }
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.fromLTRB(
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
                                                    BorderRadius.circular(27),
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
                                              if (middlePerson.keys.contains(
                                                      "poster_path") &&
                                                  middlePerson.keys
                                                      .contains("title")) {
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
                                              } else if (middlePerson.keys
                                                      .contains(
                                                          "poster_path") &&
                                                  middlePerson.keys
                                                      .contains("name")) {
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
                                              } else {
                                                personResult = middlePerson;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          PersonResult()),
                                                );
                                              }
                                            },
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
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
                                                    BorderRadius.circular(27),
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
                                              if (rightPerson.keys.contains(
                                                      "poster_path") &&
                                                  rightPerson.keys
                                                      .contains("title")) {
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
                                              } else if (rightPerson.keys
                                                      .contains(
                                                          "poster_path") &&
                                                  rightPerson.keys
                                                      .contains("name")) {
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
                                              } else {
                                                personResult = rightPerson;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          PersonResult()),
                                                );
                                              }
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.fromLTRB(
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
                                                    BorderRadius.circular(27),
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                    rightPerson['profile_path'],
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
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
