// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String _searchTermActor = '';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  _SearchResultState createState() => _SearchResultState();
}

class _SearchResultState extends State<Search> {
  @override
  Widget build(BuildContext context) {
    Future<List> searchData() async {
      List<Map<String, dynamic>> results = [];
      String searchLink = "";
      if (_searchTermActor != "") {
        searchLink =
            '$SEARCH_BY_NAME_MULTI_LINK${_searchTermActor.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
        final response = await http.get(Uri.parse(searchLink));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          for (final result in json['results']) {
            String resultSearchLink = '';
            Map jsonResult = result as Map;
            if (jsonResult.keys.contains("profile_path")) {
              resultSearchLink =
                  '$PERSON_LINK${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$API_KEY';
            } else if (jsonResult.keys.contains("title") &&
                jsonResult.keys.contains("poster_path")) {
              resultSearchLink =
                  '$MOVIE_LINK${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$API_KEY';
            } else if (jsonResult.keys.contains("name") &&
                jsonResult.keys.contains("poster_path")) {
              resultSearchLink =
                  '$TV_SHOW_LINK${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$API_KEY';
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

    String getDefaultImagePath(String? imagePath) {
      const defaultPath =
          'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
      return imagePath == null ? defaultPath : IMG_LINK + imagePath;
    }

    void handleTap(BuildContext context, Map<String, dynamic> item) {
      if (item.containsKey("poster_path") && item.containsKey("title")) {
        // movieResult = [item['id'], item['title'], "Movies"];
        Movie tempMovie = Movie(
            id: item['id'],
            title: item['title'],
            coverPhoto: item['poster_path']);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MovieResult(
                      movie: tempMovie,
                    )));
      } else if (item.containsKey("poster_path") && item.containsKey("name")) {
        TVShow tempTvShow = TVShow(
            id: item['id'],
            title: item['name'],
            coverPhoto: item['poster_path']);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TVShowResult(
                      tvshow: tempTvShow,
                    )));
      } else {
        personResult = item;
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const PersonResult()));
      }
    }

    Widget buildItem(BuildContext context, Map<String, dynamic>? item) {
      if (item == null) return SizedBox();
      item['profile_path'] = getDefaultImagePath(item['profile_path']);

      return GestureDetector(
        onTap: () => handleTap(context, item),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
          width: MediaQuery.of(context).size.width * 0.25,
          height: MediaQuery.of(context).size.height * 0.18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: NetworkImage(item['profile_path']),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            SingleChildScrollView(
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

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      buildItem(context, leftPerson),
                                      buildItem(context, middlePerson),
                                      buildItem(context, rightPerson),
                                    ],
                                  );
                                },
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return const Center(
                                child: Text("Failed to load movie details"));
                          } else {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                        },
                      ),
                    ),
                  ],
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
