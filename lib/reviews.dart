// ignore_for_file: no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/rating_popup.dart';
import 'playlists.dart';
import 'profile.dart';
import 'search.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Recommendations extends StatefulWidget {
  Recommendations();

  @override
  _RecommendationsState createState() => _RecommendationsState();
}

class _RecommendationsState extends State<Recommendations> {
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";
  List<Map<String, dynamic>> movies = [];
  void editReview(id, context) {
    reviewId = id.toString();
    reviewInfo = reviews[id.toString()];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RatingDialog();
      },
    );
  }

  Future<void> deleteReview(id, context) async {
    reviews.remove(id.toString());
    reviewInfo = {};
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews") {
          Map allreviews = doc.data() as Map;
          List reviewsInList = allreviews["Seen"] as List;
          List tempReviewsInList = [];
          for (var element in reviewsInList) {
            element = element as Map;
            if (element.keys.toList()[0].toString() != id.toString()) {
              tempReviewsInList.add(element);
            }
          }
          final userDoc =
              FirebaseFirestore.instance.collection(uid).doc("Reviews");
          await userDoc.update({'Seen': tempReviewsInList});
          reviews = {};
          for (var element in tempReviewsInList) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          }
          setState(() {
            reviews = reviews;
          });
        }
      }
    });
  }

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
                    GestureDetector(
                      child: Container(
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
                      onTap: () {
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
                    ),
                    Text(
                      snapshot.data!["title"],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        wordSpacing: 1,
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
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Rating: ${review["Rating"]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        ButtonBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: () {
                                  editReview(snapshot.data!["id"], context);
                                },
                                icon: const Icon(Icons.edit)),
                            IconButton(
                                onPressed: () {
                                  deleteReview(snapshot.data!["id"], context);
                                },
                                icon: const Icon(Icons.delete)),
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
    int selectedIndex = 0;

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
        )),
      ),
      body: ListView.builder(
        itemCount: (reviews.keys.toList().length / 2).ceil(),
        itemBuilder: (BuildContext context, int index) {
          final leftReviewIndex = index * 2;
          final rightReviewIndex = index * 2 + 1;
          final leftReviewId = (leftReviewIndex < reviews.keys.toList().length)
              ? reviews.keys.toList().reversed.toList()[leftReviewIndex]
              : null;
          final rightReviewId =
              (rightReviewIndex < reviews.keys.toList().length)
                  ? reviews.keys.toList().reversed.toList()[rightReviewIndex]
                  : null;
          final leftReview =
              (leftReviewId != null) ? (reviews[leftReviewId]) : null;
          final rightReview =
              (rightReviewId != null) ? (reviews[rightReviewId]) : null;
          return Row(
            children: [
              if (leftReview != null)
                Expanded(
                  child: buildReviewTile(context, leftReview, leftReviewId),
                ),
              if (rightReview != null)
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
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
