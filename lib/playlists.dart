// ignore_for_file: no_leading_underscores_for_local_identifiers, library_private_types_in_public_api

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'main.dart';
import 'list_result.dart';
import 'objects/Playlist.dart';
import 'popups/list_add_popup.dart';
import 'popups/list_join_popup.dart';

class Playlists extends StatefulWidget {
  const Playlists({super.key});

  @override
  _PlaylistsState createState() => _PlaylistsState();
}

class _PlaylistsState extends State<Playlists> {
  bool isJoinListPanelOpen = false;
  bool isAddListPanelOpen = false;

  Future<void> _refreshPlaylists() async {
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
        currentUser.playlists["recommendations"] = {
          "AccessCode": "",
          "CoverPhoto":
              "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/madmax5487_a_simple_2d_art_marker_backdrop_for_an_ai_generated__30ab5e32-f385-469f-8fb4-9f751eee34d3.png?alt=media&token=25dac07c-8e15-4beb-9f02-d04327ef8867",
          "Movies": currentUser.recommendations["Movies"],
          "TV Shows": currentUser.recommendations["TVShows"],
          "Name": "Handpicked for You",
          "Users": [
            currentUser.uid,
          ]
        };
      }
    });
    setState(() {});
  }

  void _toggleJoinListPanel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ListJoinDialogue();
      },
    ).then((_) {
      setState(() {});
    });
  }

  void _toggleAddListPanel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ListAddDialogue();
      },
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    _toggleJoinListPanel();
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
                        Icon(Icons.playlist_add_check, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          'Join Existing List',
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
                    _toggleAddListPanel();
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
                        Icon(Icons.add, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          'Add New List',
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
            if (currentUser.playlists["recommendations"]["Movies"].isEmpty &&
                currentUser.playlists["recommendations"]["TV Shows"].isEmpty)
              GestureDetector(
                onTap: () {
                  Playlist listResult = Playlist(
                      id: "recommendations",
                      name: currentUser.playlists["recommendations"]["Name"]
                          .toString(),
                      backdrop: currentUser.playlists["recommendations"]
                              ["CoverPhoto"]
                          .toString(),
                      movies: currentUser.playlists["recommendations"]
                          ["Movies"],
                      tvshows: currentUser.playlists["recommendations"]
                          ["TV Shows"],
                      accesscode: currentUser.playlists["recommendations"]
                              ["AccessCode"]
                          .toString(),
                      users: currentUser.playlists["recommendations"]
                          ["Users"]);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ListResult(
                        list_result: listResult,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 5.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.new_releases, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Generate Handpicked Recommendations',
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
              height: 10,
            ),
            if (currentUser.playlists.isEmpty)
              const Center(child: Text("You don't have any playlists yet!")),
            if (currentUser.playlists.isNotEmpty)
              RefreshIndicator(
                onRefresh: _refreshPlaylists,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.74,
                  child: Center(
                    child: ListView.builder(
                      itemCount: currentUser.playlists.length,
                      itemBuilder: (context, index) {
                        String key =
                            currentUser.playlists.keys.elementAt(index);
                        dynamic value = currentUser.playlists[key]['Name'];
                        dynamic image =
                            currentUser.playlists[key]['CoverPhoto'];
                        dynamic movies = currentUser.playlists[key]['Movies'];
                        dynamic tvshows =
                            currentUser.playlists[key]['TV Shows'];
                        dynamic accessCode =
                            currentUser.playlists[key]['AccessCode'];
                        if (currentUser.playlists["recommendations"]["Movies"]
                                .isNotEmpty ||
                            currentUser
                                .playlists["recommendations"]["TV Shows"]
                                .isNotEmpty) {
                          return GestureDetector(
                            onTap: () {
                              Playlist listResult = Playlist(
                                  id: key.toString(),
                                  name: value.toString(),
                                  backdrop: image.toString(),
                                  movies: movies,
                                  tvshows: tvshows,
                                  accesscode: accessCode.toString(),
                                  users: currentUser.playlists[key]["Users"]);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ListResult(
                                          list_result: listResult,
                                        )),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(
                                  10.0, 10.0, 10.0, 5.0),
                              height: 200,
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          image,
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                              wordSpacing: 2,
                                              height: 1.5,
                                            ),
                                          ),
                                          Text(
                                            'Movies: ${movies.length}, TV Shows: ${tvshows.length}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Align(
                                  //   alignment: Alignment.topRight,
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       borderRadius: BorderRadius.circular(100),
                                  //       color: Colors.black.withOpacity(0.5),
                                  //     ),
                                  //     child: Column(
                                  //       mainAxisSize: MainAxisSize.min,
                                  //       children: [
                                  //         IconButton(
                                  //           onPressed: () {
                                  //             showDialog(
                                  //               context: context,
                                  //               builder: (context) =>
                                  //                   ListInfoDialog(
                                  //                 list_result:
                                  //                     currentUser.playlists[key],
                                  //               ),
                                  //             ).then((_) {
                                  //               setState(() {});
                                  //             });
                                  //           },
                                  //           icon: const Icon(
                                  //             Icons.more_vert,
                                  //             color: Colors.white,
                                  //           ),
                                  //         ),
                                  //       ],
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return Container();
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CommonBottomAppBar(1),
    );
  }
}
