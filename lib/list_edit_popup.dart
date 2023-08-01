// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/playlists.dart';
import 'dart:convert';
import 'list_result.dart';

String search_by_nameMovie =
    'https://api.themoviedb.org/3/search/movie?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
String linkMovie = "https://api.themoviedb.org/3/movie/";
String img = 'https://image.tmdb.org/t/p/original/';

final list_name_controller = listName != "" ? TextEditingController(text: listName) : TextEditingController(text: "");
final access_code_controller = accessCode != "" ? TextEditingController(text: accessCode) : TextEditingController(text: "");

String _searchTermMovie = '';
FirebaseFirestore db = FirebaseFirestore.instance;

class ListEditDialogue extends StatefulWidget {
  @override
  _ListEditDialogueState createState() => _ListEditDialogueState();
}

class _ListEditDialogueState extends State<ListEditDialogue> {
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

  void editListSubmit() async {
    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        Map docData = doc.data() as Map;
        if (originalListName == (docData["Name"])) {
          if (docData["AccessCode"] == originalAccessCode) {
            var userDoc =
                FirebaseFirestore.instance.collection("Watchlists").doc(doc.id);
            await userDoc.update({"Name": listName});
            await userDoc.update({"CoverPhoto": cover});
            await userDoc.update({"AccessCode": accessCode});
            list_result["AccessCode"] = accessCode;
            list_result["Name"] = listName;
            list_result["Backdrop"] = cover;
            Navigator.pop(context);
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => ListResult()));
          }
        }
      }
    });
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
                'Modify ${list_result['Name']}',
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
                controller: list_name_controller,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'List Name',
                ),
                onChanged: (value) {
                  listName = value;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextFormField(
                validator: (String? value) {
                  if (value == null || value.isEmpty || cover == "") {
                    return 'Please select a movie';
                  }
                  return null;
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'Name of The Movie You\'d Like as Cover',
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
                height: 150,
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
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
                                onTap: () =>
                                    cover = img + item["backdrop_path"],
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
              child: TextFormField(
                controller: access_code_controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'Access Code For Other People',
                ),
                onChanged: (value) {
                  accessCode = value;
                },
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        editListSubmit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .green, // Change the background color of the button
                      ),
                      child: const Text('Save'),
                    ),
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
