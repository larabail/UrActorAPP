// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'playlists.dart';
import 'dart:convert';
import 'list_result.dart';

String search_by_nameMovie =
    'https://api.themoviedb.org/3/search/movie?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
String linkMovie = "https://api.themoviedb.org/3/movie/";
String img = 'https://image.tmdb.org/t/p/original/';

final list_name_controller = listName != ""
    ? TextEditingController(text: listName)
    : TextEditingController(text: "");
final access_code_controller = accessCode != ""
    ? TextEditingController(text: accessCode)
    : TextEditingController(text: "");

String _searchTermMovie = '';
FirebaseFirestore db = FirebaseFirestore.instance;

class ListEditDialogue extends StatefulWidget {
  @override
  _ListEditDialogueState createState() => _ListEditDialogueState();
}

class _ListEditDialogueState extends State<ListEditDialogue> {
  int _selectedIndex = 0;
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
            if (json2["poster_path"] != "" &&
                json2["poster_path"] != null &&
                json2["backdrop_path"] != null &&
                json2["backdrop_path"] != "") {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Add rounded corners
      ),
      elevation: 0,
      child: contentBox(context),
    );
  }

  contentBox(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          padding:
              const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 40, 20, 5),
                  child: Text(
                    'Modify "${list_result['Name']}"',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                    decoration: const InputDecoration(
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
                    decoration: const InputDecoration(
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
                      future: searchData(_searchTermMovie),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        } else {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: snapshot.data?.length,
                            itemBuilder: (context, index) {
                              Map<String, dynamic> item = snapshot.data?[index];
                              bool isSelected = index == _selectedIndex;
                              if (isSelected) {
                                cover = img + item["backdrop_path"];
                              }
                              return Container(
                                width: 100,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: GridTile(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = index;
                                        cover = img + item["backdrop_path"];
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              img + item['poster_path']),
                                          fit: BoxFit.cover,
                                        ),
                                        border: isSelected
                                            ? Border.all(
                                                color: Colors.blue, width: 3)
                                            : null,
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
                    decoration: const InputDecoration(
                      labelText: 'Access Code For Other People',
                    ),
                    onChanged: (value) {
                      accessCode = value;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          editListSubmit();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, color: Colors.green),
                              SizedBox(width: 10),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
