// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/item_container.dart';
import '../common/api/apiutils.dart';
import '../common/firebase/playlist_service.dart';
import '../common/constants.dart';
import '../main.dart';

class ListAddDialogue extends StatefulWidget {
  const ListAddDialogue({super.key});

  @override
  State<ListAddDialogue> createState() => _ListAddDialogueState();
}

class _ListAddDialogueState extends State<ListAddDialogue> {
  final myController = TextEditingController(text: "");

  String _searchTermMovie = '';
  String cover = "";
  String _listName = "";
  String _accessCode = "";
  FirebaseFirestore db = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  void addListSubmit() async {
    // The id used to be a random 7-digit number checked for collisions by
    // downloading every document in the collection. A Firestore-generated id
    // is unique by construction, and reads nothing. Playlist.id has always
    // been a String, so nothing downstream cares that it is no longer numeric.
    final listDoc = db.collection("Watchlists").doc();

    // One write instead of six. The previous version called set() and then
    // update() five times, which left a half-built playlist behind if any of
    // them failed.
    await listDoc.set({
      "AccessCode": _accessCode,
      "CoverPhoto": cover,
      "Movies": [],
      "TV Shows": [],
      "Name": _listName,
      "Users": [
        {currentUser.uid: "Owner"}
      ],
      "memberUids": [currentUser.uid],
    });

    await PlaylistService.refreshCurrentUserPlaylists();

    if (!mounted) return;
    Navigator.pop(context);
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

  Widget contentBox(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding:
              const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(5, 10, 20, 5),
                  child: Text(
                    'Create a New List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextFormField(
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
                      _listName = value;
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
                        ApiUtils.searchMovies(_searchTermMovie);
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
                      future: ApiUtils.searchMovies(_searchTermMovie),
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
                              if (item["backdrop_path"] != null) {
                                bool isSelected = index == _selectedIndex;
                                if (isSelected) {
                                  cover = IMG_LINK + item["backdrop_path"];
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
                                            cover = IMG_LINK +
                                                item["backdrop_path"];
                                          });
                                        },
                                        child: getItemSelectableContainer(
                                            context,
                                            item,
                                            "media",
                                            isSelected)),
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
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Access Code For Other People',
                    ),
                    onChanged: (value) {
                      _accessCode = value;
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          addListSubmit();
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
                                  fontSize: 13,
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
