// ignore_for_file: use_build_context_synchronously, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names, no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'playlists.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'list_edit_popup.dart';
import 'movie_add_popup.dart';
import 'tv_add_popup.dart';

String cover = "";
String listName = "";
String accessCode = "";
String originalListName = "";
String originalAccessCode = "";

class InfoButtonDialog extends StatefulWidget {
  @override
  _InfoButtonDialogState createState() => _InfoButtonDialogState();
}

class _InfoButtonDialogState extends State<InfoButtonDialog> {
  Future<Map<String, dynamic>> getUserData(String uid) async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection(uid).doc("Settings").get();
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data["uid"] = uid;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    Map userCurrent = list_result['Users'].firstWhere(
        (item) => item.containsKey(uid) as bool,
        orElse: () => null);
    String role = userCurrent[uid];
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
            Text(
              "AccessCode: ${list_result['AccessCode']}",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Users with access:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder(
              future: Future.wait((list_result['Users'] as List<dynamic>)
                  .map((user) => getUserData(user.keys.toList()[0]))),
              builder: (context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No users have access.');
                } else {
                  return Column(
                    children: snapshot.data!.map((userData) {
                      return Row(
                        children: [
                          ClipOval(
                            child: userData["profile_photo"] != ""
                                ? Image.network(
                                    userData["profile_photo"],
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/main_profile.png',
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            userData['username'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (role == "Owner")
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () async {
                                Map itemToRemove = list_result['Users']
                                    .firstWhere(
                                        (item) =>
                                            item.containsKey(userData["uid"])
                                                as bool,
                                        orElse: () => null);
                                FirebaseFirestore.instance
                                    .collection('Watchlists')
                                    .doc(list_result["id"])
                                    .update({
                                  'Users':
                                      FieldValue.arrayRemove([itemToRemove])
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
                                        Map docData = doc.data() as Map;
                                        docData["id"] = doc.id;
                                        playlists[doc.id] = docData;
                                      }
                                    }
                                  }
                                });
                                setState(() {
                                  list_result["Users"] =
                                      playlists[list_result["id"]]["Users"];
                                });
                              },
                            ),
                        ],
                      );
                    }).toList(),
                  );
                }
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    cover = list_result["Backdrop"];
                    originalListName = list_result["Name"];
                    originalAccessCode = list_result["AccessCode"];
                    listName = list_result["Name"];
                    accessCode = list_result["AccessCode"];

                    showDialog(
                      context: context,
                      builder: (context) => ListEditDialogue(),
                    );
                    print("EDIT");
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
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          'Edit',
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
                  onTap: () async {
                    if (role == "Owner") {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertButtonDialogue(),
                      );
                    } else {
                      Map itemToRemove = list_result['Users'].firstWhere(
                          (item) => item.containsKey(uid) as bool,
                          orElse: () => null);
                      FirebaseFirestore.instance
                          .collection('Watchlists')
                          .doc(list_result["id"])
                          .update({
                        'Users': FieldValue.arrayRemove([itemToRemove])
                      });
                      playlists = {};
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
                              Map docData = doc.data() as Map;
                              docData["id"] = doc.id;
                              playlists[doc.id] = docData;
                            }
                          }
                        }
                      });
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => Playlists()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(role == "Owner" ? Icons.delete : Icons.exit_to_app,
                            color: Colors.red),
                        const SizedBox(width: 10),
                        Text(
                          role == "Owner" ? 'Delete' : 'Leave',
                          style: const TextStyle(
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
          ],
        ),
      ),
    );
  }
}

class AlertButtonDialogue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete List'),
      content: const Text(
        'Are you sure you want to delete this list?',
        style: TextStyle(color: Colors.red),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            // Perform the delete operation here
            playlists = {};
            await FirebaseFirestore.instance
                .collection("Watchlists")
                .doc(list_result["id"])
                .delete();
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
            Navigator.pop(context);
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => Playlists()));
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.red),
          ),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class ListResult extends StatefulWidget {
  @override
  _ListResultState createState() => _ListResultState();
}

class _ListResultState extends State<ListResult> {
  Map list = list_result;
  List<Map<String, dynamic>> moviesList = [];
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";

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
      if (!containsMap(moviesList, data)) {
        moviesList.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBar(),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(
                          list['Backdrop'],
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(1),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        list['Name'],
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          wordSpacing: 2,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => InfoButtonDialog(),
                              );
                            },
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                          ),
                        ])),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return MovieAddDialogue();
                      },
                    );
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
                        Icon(Icons.movie, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          'Add Movie',
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
                const SizedBox(
                    width:
                        20), // Optional: To add some space between the buttons
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return TvAddDialogue();
                      },
                    );
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
                        Icon(Icons.tv, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          'Add TV Show',
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
            if (list["Movies"].length > 0 && list["TVShows"].length > 0)
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Movies'),
                        Tab(text: 'TV Shows'),
                      ],
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height -
                          MediaQuery.of(context)
                              .padding
                              .top - // Top padding or SafeArea height
                          MediaQuery.of(context)
                              .padding
                              .bottom - // Bottom padding or SafeArea height
                          155 -
                          60 -
                          MediaQuery.of(context).size.height * 0.25,
                      child: TabBarView(
                        children: [
                          if (list["Movies"].length != 0)
                            ListView.builder(
                              itemCount: (list["Movies"].length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftMovieIndex = index * 3;
                                final middleMovieIndex = index * 3 + 1;
                                final rightMovieIndex = index * 3 + 2;
                                final leftMovie =
                                    (leftMovieIndex < list["Movies"].length)
                                        ? list["Movies"][leftMovieIndex]
                                        : null;
                                final middleMovie =
                                    (middleMovieIndex < list["Movies"].length)
                                        ? list["Movies"][middleMovieIndex]
                                        : null;
                                final rightMovie =
                                    (rightMovieIndex < list["Movies"].length)
                                        ? list["Movies"][rightMovieIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(leftMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (middleMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(middleMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (rightMovie != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(rightMovie, "Movies"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      )
                                  ],
                                );
                              },
                            ),
                          if (list["TVShows"].length != 0)
                            ListView.builder(
                              itemCount: (list["TVShows"].length / 3).ceil(),
                              itemBuilder: (context, index) {
                                final leftTVShowIndex = index * 3;
                                final middleTVShowIndex = index * 3 + 1;
                                final rightTVShowIndex = index * 3 + 2;
                                final leftTVShow =
                                    (leftTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][leftTVShowIndex]
                                        : null;
                                final middleTVShow =
                                    (middleTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][middleTVShowIndex]
                                        : null;
                                final rightTVShow =
                                    (rightTVShowIndex < list["TVShows"].length)
                                        ? list["TVShows"][rightTVShowIndex]
                                        : null;
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    if (leftTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(leftTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (middleTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future:
                                            getData(middleTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    if (rightTVShow != null)
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: getData(rightTVShow, "TVShows"),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<Map> snapshot) {
                                          if (snapshot.hasData) {
                                            return GestureDetector(
                                              onTap: () {
                                                // Handle the click event here
                                                if (snapshot.data!['type'] ==
                                                    "Movies") {
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
                                                          snapshot.data![
                                                                      'type'] ==
                                                                  "Movies"
                                                              ? MovieResult()
                                                              : TVShowResult()),
                                                );
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.28,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.18,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(27),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      snapshot.data!['poster'],
                                                    ),
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return const Center(
                                              child: Text(
                                                  "Failed to load movie details"),
                                            );
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      )
                                  ],
                                );
                              },
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (list["Movies"].length > 0 && list["TVShows"].length == 0)
              Container(
                height: MediaQuery.of(context).size.height * 0.475,
                child: ListView.builder(
                  itemCount: (list["Movies"].length / 3).ceil(),
                  itemBuilder: (context, index) {
                    final leftMovieIndex = index * 3;
                    final middleMovieIndex = index * 3 + 1;
                    final rightMovieIndex = index * 3 + 2;
                    final leftMovie = (leftMovieIndex < list["Movies"].length)
                        ? list["Movies"][leftMovieIndex]
                        : null;
                    final middleMovie =
                        (middleMovieIndex < list["Movies"].length)
                            ? list["Movies"][middleMovieIndex]
                            : null;
                    final rightMovie = (rightMovieIndex < list["Movies"].length)
                        ? list["Movies"][rightMovieIndex]
                        : null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (leftMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(leftMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
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
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
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
                            },
                          ),
                        if (middleMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(middleMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
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
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
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
                            },
                          ),
                        if (rightMovie != null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: getData(rightMovie, "Movies"),
                            builder: (BuildContext context,
                                AsyncSnapshot<Map> snapshot) {
                              if (snapshot.hasData) {
                                return GestureDetector(
                                  onTap: () {
                                    // Handle the click event here
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
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
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
                            },
                          )
                      ],
                    );
                  },
                ),
              ),
            if (list["TVShows"].length > 0 && list["Movies"].length == 0)
              Container(
                  height: MediaQuery.of(context).size.height * 0.475,
                  child: ListView.builder(
                    itemCount: (list["TVShows"].length / 3).ceil(),
                    itemBuilder: (context, index) {
                      final leftTVShowIndex = index * 3;
                      final middleTVShowIndex = index * 3 + 1;
                      final rightTVShowIndex = index * 3 + 2;
                      final leftTVShow =
                          (leftTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][leftTVShowIndex]
                              : null;
                      final middleTVShow =
                          (middleTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][middleTVShowIndex]
                              : null;
                      final rightTVShow =
                          (rightTVShowIndex < list["TVShows"].length)
                              ? list["TVShows"][rightTVShowIndex]
                              : null;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (leftTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(leftTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
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
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
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
                              },
                            ),
                          if (middleTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(middleTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
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
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
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
                              },
                            ),
                          if (rightTVShow != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: getData(rightTVShow, "TVShows"),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle the click event here
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
                                                snapshot.data!['type'] ==
                                                        "Movies"
                                                    ? MovieResult()
                                                    : TVShowResult()),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
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
                              },
                            )
                        ],
                      );
                    },
                  )),
          ],
        ),
        bottomNavigationBar: CommonBottomAppBar(-1),
      ),
    );
  }
}
