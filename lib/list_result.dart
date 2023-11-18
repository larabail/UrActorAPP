// ignore_for_file: use_build_context_synchronously, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names, no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/objects/TVShow.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'objects/Media.dart';
import 'objects/Movie.dart';
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
        (item) => item.containsKey(currentUser.uid) as bool,
        orElse: () => null);
    String role = userCurrent[currentUser.uid];
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
                                      if (el.keys.contains(currentUser.uid)) {
                                        Map docData = doc.data() as Map;
                                        docData["id"] = doc.id;
                                        currentUser.playlists[doc.id] = docData;
                                      }
                                    }
                                  }
                                });
                                setState(() {
                                  list_result["Users"] = currentUser
                                      .playlists[list_result["id"]]["Users"];
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
                if (role == "Owner")
                  GestureDetector(
                    onTap: () {
                      cover = list_result["Backdrop"];
                      originalListName = list_result["Name"];
                      originalAccessCode = list_result["AccessCode"];
                      listName = list_result["Name"];
                      accessCode = list_result["AccessCode"];
                      showDialog(
                        context: context,
                        builder: (context) => const ListEditDialogue(),
                      ).then((_) {
                        Navigator.pop(context);
                      });
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
                          (item) => item.containsKey(currentUser.uid) as bool,
                          orElse: () => null);
                      FirebaseFirestore.instance
                          .collection('Watchlists')
                          .doc(list_result["id"])
                          .update({
                        'Users': FieldValue.arrayRemove([itemToRemove])
                      });
                      currentUser.playlists = {};
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
                              Map docData = doc.data() as Map;
                              docData["id"] = doc.id;
                              currentUser.playlists[doc.id] = docData;
                            }
                          }
                        }
                      });
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Playlists()));
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
            currentUser.playlists = {};
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
                  if (el.keys.contains(currentUser.uid)) {
                    currentUser.playlists[doc.id] = doc.data();
                  }
                }
              }
            });
            Navigator.pop(context);
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const Playlists()));
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
      if (!containsMap(moviesList, data)) {
        moviesList.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  Widget buildMediaItem(
      String mediaId, String mediaType, BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getData(mediaId, mediaType),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () {
              MediaItem tempItem = mediaType == "Movies"
                  ? Movie(
                      id: snapshot.data!['id'].toString(),
                      title: snapshot.data!['title'].toString(),
                      coverPhoto: snapshot.data!['poster_path'].toString(),
                    )
                  : TVShow(
                      id: snapshot.data!['id'].toString(),
                      title: snapshot.data!['title'].toString(),
                      coverPhoto: snapshot.data!['poster_path'].toString(),
                    );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => mediaType == "Movies"
                      ? MovieResult(movie: tempItem as Movie)
                      : TVShowResult(tvshow: tempItem as TVShow),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                image: DecorationImage(
                  image: NetworkImage(snapshot.data!['poster']),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return const Center(child: Text("Failed to load movie details"));
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget buildMediaList(
      List mediaList, String mediaType, BuildContext context) {
    return ListView.builder(
      itemCount: (mediaList.length / 3).ceil(),
      itemBuilder: (context, index) {
        final leftIndex = index * 3;
        final middleIndex = index * 3 + 1;
        final rightIndex = index * 3 + 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (leftIndex < mediaList.length)
              buildMediaItem(mediaList[leftIndex], mediaType, context),
            if (middleIndex < mediaList.length)
              buildMediaItem(mediaList[middleIndex], mediaType, context),
            if (rightIndex < mediaList.length)
              buildMediaItem(mediaList[rightIndex], mediaType, context),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const CustomAppBar(),
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
                              ).then((_) {
                                setState(() {});
                              });
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
                        return const MovieAddDialogue();
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
                        return const TvAddDialogue();
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
                child: Expanded(
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Movies'),
                          Tab(text: 'TV Shows'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            buildMediaList(list["Movies"], "Movies", context),
                            buildMediaList(list["TVShows"], "TVShows", context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (list["Movies"].length > 0 && list["TVShows"].length == 0)
              buildMediaList(list["Movies"], "Movies", context),
            if (list["TVShows"].length > 0 && list["Movies"].length == 0)
              buildMediaList(list["TVShows"], "TVShows", context),
          ],
        ),
        bottomNavigationBar: CommonBottomAppBar(-1),
      ),
    );
  }
}
