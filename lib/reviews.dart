// ignore_for_file: no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/common/constants.dart';
import '/objects/Media.dart';
import '/objects/Movie.dart';
import '/objects/TVShow.dart';
import 'popups/rating_popup.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/utils.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';

class Reviews extends StatefulWidget {
  const Reviews();

  @override
  _ReviewsState createState() => _ReviewsState();
}

class _ReviewsState extends State<Reviews> {
  List<Map<String, dynamic>> movies = [];
  void editReview(id, context) {
    reviewId = id.toString();
    reviewInfo = currentUser.reviews[id.toString()];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    );
  }

  Future<void> deleteReview(id, context) async {
    currentUser.reviews.remove(id.toString());
    reviewInfo = {};
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
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
          final userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Reviews");
          await userDoc.update({'Seen': tempReviewsInList});
          currentUser.reviews = {};
          for (var element in tempReviewsInList) {
            element = element as Map;
            currentUser.reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          }
          setState(() {
            currentUser.reviews = currentUser.reviews;
          });
        }
      }
    });
  }

  Future<Map<String, dynamic>> getData(id, type) async {
    Map<String, dynamic> data = {};
    String link;
    if (type == "TVShows") {
      link = TV_SHOW_LINK;
    } else {
      link = MOVIE_LINK;
    }
    final response = await http.get(Uri.parse('$link$id$API_KEY'));
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
        data['poster'] = IMG_LINK + json['poster_path'];
      }
      data['id'] = json['id'];
      data['type'] = type;
      if (!Utils.containsMap(movies, data)) {
        movies.add(data);
      }
    } else {
      link = 'https://api.themoviedb.org/3/tv/';
      type = "TVShows";
      final response = await http.get(Uri.parse('$link$id$API_KEY'));
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
          data['poster'] = IMG_LINK + json['poster_path'];
        }
        data['id'] = json['id'];
        data['type'] = type;
        if (!Utils.containsMap(movies, data)) {
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
                        MediaItem tempItem;
                        if (snapshot.data!['type'] == "Movies") {
                          tempItem = Movie(
                              id: snapshot.data!['id'].toString(),
                              title: snapshot.data!['title'],
                              coverPhoto: snapshot.data!['poster_path'] ?? "");
                        } else {
                          tempItem = TVShow(
                              id: snapshot.data!['id'].toString(),
                              title: snapshot.data!['title'],
                              coverPhoto: snapshot.data!['poster_path'] ?? "");
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  snapshot.data!['type'] == "Movies"
                                      ? MovieResult(
                                          movie: tempItem as Movie,
                                        )
                                      : TVShowResult(
                                          tvshow: tempItem as TVShow,
                                        )),
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
    return Scaffold(
      appBar: const CustomAppBar(),
      body: ListView.builder(
        itemCount: (currentUser.reviews.keys.toList().length / 2).ceil(),
        itemBuilder: (BuildContext context, int index) {
          final leftReviewIndex = index * 2;
          final rightReviewIndex = index * 2 + 1;
          final leftReviewId =
              (leftReviewIndex < currentUser.reviews.keys.toList().length)
                  ? currentUser.reviews.keys
                      .toList()
                      .reversed
                      .toList()[leftReviewIndex]
                  : null;
          final rightReviewId =
              (rightReviewIndex < currentUser.reviews.keys.toList().length)
                  ? currentUser.reviews.keys
                      .toList()
                      .reversed
                      .toList()[rightReviewIndex]
                  : null;
          final leftReview = (leftReviewId != null)
              ? (currentUser.reviews[leftReviewId])
              : null;
          final rightReview = (rightReviewId != null)
              ? (currentUser.reviews[rightReviewId])
              : null;
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
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
