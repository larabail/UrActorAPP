// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'list_result.dart';
import 'playlists.dart';
import 'dart:convert';
import 'main.dart';

String search_by_nameMovie =
    'https://api.themoviedb.org/3/search/movie?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
String linkMovie = "https://api.themoviedb.org/3/movie/";
String img = 'https://image.tmdb.org/t/p/original/';

final myController = TextEditingController(text: "");

String _searchTermMovie = '';
String _movie = "";
FirebaseFirestore db = FirebaseFirestore.instance;

class MovieAddDialogue extends StatefulWidget {
  @override
  _MovieAddDialogueState createState() => _MovieAddDialogueState();
}

class _MovieAddDialogueState extends State<MovieAddDialogue> {
  Future<List> searchData(String searchTerm) async {
    // print(searchTerm);
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$search_by_nameMovie$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<Map<String, dynamic>> results = [];
        for (final result in json['results']) {
          String resultSearchLink = '';
          resultSearchLink =
              '$linkMovie${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$api_key_actor';
          final response2 = await http.get(Uri.parse(resultSearchLink));
          if (response2.statusCode == 200) {
            final json2 = jsonDecode(response2.body);
            if (json2["poster_path"] != "" && json2["poster_path"] != null) {
              results.add(json2);
            }
          } else {
            throw Exception('Failed to load movie details');
          }
        }
        return results;
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      return [];
    }
  }

  void addMovieSubmit() async {
    String docIDString = list_result["id"].toString();
    print(_movie);

    var userDoc = db.collection("Watchlists").doc(docIDString);
    await userDoc.update({
      "Movies": FieldValue.arrayUnion([_movie])
    });

    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map keysOfDoc = doc.data() as Map;
        List users = keysOfDoc['Users'] as List;
        for (var element in users) {
          Map el = element as Map;
          if (el.keys.contains(uid)) {
            playlists[doc.id] = doc.data();
          }
        }
      }
    });

    list_result["Movies"] = playlists[list_result["id"].toString()]["Movies"];

    Navigator.pop(context);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => ListResult()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contents of the Add List panel
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
              child: Text(
                'Add a movie to "${list_result["Name"]}"',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextFormField(
                validator: (String? value) {
                  if (value == null || value.isEmpty || _movie == "") {
                    return 'Please select a movie';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Name of The Movie You\'d Like to Add',
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTermMovie = value;
                    searchData(_searchTermMovie);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.5,
                width: MediaQuery.of(context).size.width * 0.7,
                child: FutureBuilder<List>(
                  future: searchData(
                      _searchTermMovie), // Replace 'Your Search Term' with your actual search term
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    } else {
                      // Data is ready, build the GridView
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data?.length,
                        itemBuilder: (context, index) {
                          // You can customize the item here
                          Map<String, dynamic> item = snapshot.data?[index];
                          return Container(
                            width: 100, // Adjust the width as needed
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: GridTile(
                              child: GestureDetector(
                                onTap: () {
                                  _movie = item["id"].toString();
                                  addMovieSubmit();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          img + item['poster_path']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .red, // Change the background color of the button
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
