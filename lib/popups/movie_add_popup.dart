// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/utils.dart';
import '../common/constants.dart';
import '../main.dart';
import '../objects/Playlist.dart';

class MovieAddDialogue extends StatefulWidget {
  final Playlist list_result;
  const MovieAddDialogue({Key? key, required this.list_result})
      : super(key: key);

  @override
  _MovieAddDialogueState createState() => _MovieAddDialogueState();
}

class _MovieAddDialogueState extends State<MovieAddDialogue> {
  final myController = TextEditingController(text: "");

  String _searchTermMovie = '';
  String _movie = "";
  FirebaseFirestore db = FirebaseFirestore.instance;

  void addMovieSubmit() async {
    String docIDString = widget.list_result.id.toString();

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
          if (el.keys.contains(currentUser.uid)) {
            currentUser.playlists[doc.id] = doc.data();
          }
        }
      }
    });

    widget.list_result.movies =
        currentUser.playlists[widget.list_result.id.toString()]["Movies"];

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Text(
                'Add a movie to "${widget.list_result.name}"',
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
                decoration: const InputDecoration(
                  labelText: 'Name of The Movie You\'d Like to Add',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchTermMovie = value;
                    ApiUtils.searchMovies(_searchTermMovie);
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FutureBuilder<List>(
                  future: ApiUtils.searchMovies(_searchTermMovie),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    } else {
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data?.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> item = snapshot.data?[index];
                          if (item['poster_path'] != null) {
                            return Container(
                              width: 100,
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
                                            IMG_LINK + item['poster_path']),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
