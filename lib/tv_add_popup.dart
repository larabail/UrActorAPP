// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/list_result.dart';
import 'package:uractor/playlists.dart';
import 'dart:convert';
import 'main.dart';

String search_by_nameTv =
    'https://api.themoviedb.org/3/search/tv?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
String linkTv = "https://api.themoviedb.org/3/tv/";
String img = 'https://image.tmdb.org/t/p/original/';

final myController = TextEditingController(text: "");

String _searchTermTv = '';
String _movie = "";
FirebaseFirestore db = FirebaseFirestore.instance;

class TvAddDialogue extends StatefulWidget {
  @override
  _TvAddDialogueState createState() => _TvAddDialogueState();
}

class _TvAddDialogueState extends State<TvAddDialogue> {
  Future<List> searchData(String searchTerm) async {
    // print(searchTerm);
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$search_by_nameTv$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<Map<String, dynamic>> results = [];
        for (final result in json['results']) {
          String resultSearchLink = '';
          resultSearchLink =
              '$linkTv${result["id"]}-${result["name"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$api_key_actor';
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

  void addTvSubmit() async {
    String docIDString = list_result["id"].toString();
    print(_movie);

    var userDoc = db.collection("Watchlists").doc(docIDString);
    await userDoc.update({
      "TV Shows": FieldValue.arrayUnion([_movie])
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

    list_result["TVShows"] =
        playlists[list_result["id"].toString()]["TV Shows"];

    Navigator.pop(context);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => ListResult()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contents of the Add List panel
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
              child: Text(
                'Add a movie to ${list_result["Name"]}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'Name of The Tv You\'d Like to Add',
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTermTv = value;
                    searchData(_searchTermTv);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.5,
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: FutureBuilder<List>(
                  future: searchData(
                      _searchTermTv), // Replace 'Your Search Term' with your actual search term
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
                                  addTvSubmit();
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
