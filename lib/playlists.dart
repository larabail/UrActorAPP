// ignore_for_file: no_leading_underscores_for_local_identifiers, library_private_types_in_public_api

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'common/firebase/settings_service.dart';
import 'common/playlist_order.dart';
import 'common/reorder_toggle.dart';
import 'main.dart';
import 'list_result.dart';
import 'objects/playlist.dart';
import 'popups/list_add_popup.dart';
import 'popups/list_join_popup.dart';
import 'common/firebase/firestore_core.dart';

class Playlists extends StatefulWidget {
  const Playlists({super.key});

  @override
  _PlaylistsState createState() => _PlaylistsState();
}

class _PlaylistsState extends State<Playlists> {
  bool isJoinListPanelOpen = false;
  bool isAddListPanelOpen = false;

  /// Reordering is a mode rather than always-on, so that dragging a playlist
  /// does not compete with tapping one to open it.
  bool _isReordering = false;

  List<String> get _orderedIds => orderPlaylistIds(
        currentUser.playlists.keys.map((key) => key.toString()),
        SettingsService.read<dynamic>(kPlaylistOrderSettingsKey, null),
      );

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final List<String> next =
        reorderPlaylistIds(_orderedIds, oldIndex, newIndex);
    // Applied in memory first so the list settles under the finger straight
    // away, rather than waiting for the write to Firestore to come back.
    setState(() {
      currentUser.settings[kPlaylistOrderSettingsKey] = next;
    });
    await SettingsService.update(kPlaylistOrderSettingsKey, next);
  }

  Future<void> _refreshPlaylists() async {
    currentUser.playlists = {};
    await FirestoreCore.db
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
      appBar: CustomAppBar(
        actions: [
          if (_orderedIds.length > 1) ...[
            ReorderToggle(
              isReordering: _isReordering,
              onPressed: () => setState(() => _isReordering = !_isReordering),
              enterTooltip: S.of(context)!.reorderPlaylists,
              exitTooltip: S.of(context)!.finishReordering,
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
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
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_check, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.joinList,
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
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.red),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.newList,
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
            if (currentUser.recommendations["Movies"].isEmpty &&
                currentUser.recommendations["TVShows"].isEmpty)
              GestureDetector(
                onTap: () {
                  Playlist listResult = Playlist(
                      id: "recommendations",
                      name: "Handpicked for You",
                      backdrop:
                          "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/madmax5487_a_simple_2d_art_marker_backdrop_for_an_ai_generated__30ab5e32-f385-469f-8fb4-9f751eee34d3.png?alt=media&token=25dac07c-8e15-4beb-9f02-d04327ef8867",
                      movies: currentUser.recommendations["Movies"],
                      tvshows: currentUser.recommendations["TVShows"],
                      accesscode: "".toString(),
                      users: [
                        currentUser.uid,
                      ]);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ListResult(
                        listResult: listResult,
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
                  child: Row(
                    children: [
                      Icon(Icons.new_releases, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        S.of(context)!.generateRecommendation,
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
            if (currentUser.playlists.isEmpty)
              Center(child: Text(S.of(context)!.noPlaylists)),
            if (currentUser.playlists.isNotEmpty)
              RefreshIndicator(
                onRefresh: _refreshPlaylists,
                child: Column(
                  children: [
                    if (currentUser.recommendations["Movies"].isNotEmpty ||
                        currentUser.recommendations["TVShows"].isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Playlist listResult = Playlist(
                              id: "recommendations",
                              name: S.of(context)!.handpicked,
                              backdrop:
                                  "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/madmax5487_a_simple_2d_art_marker_backdrop_for_an_ai_generated__30ab5e32-f385-469f-8fb4-9f751eee34d3.png?alt=media&token=25dac07c-8e15-4beb-9f02-d04327ef8867",
                              movies: currentUser.recommendations["Movies"],
                              tvshows: currentUser.recommendations["TVShows"],
                              accesscode: "".toString(),
                              users: [
                                currentUser.uid,
                              ]);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListResult(
                                listResult: listResult,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          margin:
                              const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 5.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      image: const DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/madmax5487_a_simple_2d_art_marker_backdrop_for_an_ai_generated__30ab5e32-f385-469f-8fb4-9f751eee34d3.png?alt=media&token=25dac07c-8e15-4beb-9f02-d04327ef8867"),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(S.of(context)!.handpicked,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${S.of(context)!.movies}: ${currentUser.recommendations["Movies"].length}, ${S.of(context)!.tvShows}: ${currentUser.recommendations["TVShows"].length}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Handles only appear in reorder mode, so an ordinary
                      // drag still scrolls the page rather than picking a
                      // playlist up.
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,
                      itemCount: _orderedIds.length,
                      itemBuilder: (context, index) {
                        String key = _orderedIds[index];
                        dynamic value = currentUser.playlists[key]['Name'];
                        dynamic image =
                            currentUser.playlists[key]['CoverPhoto'];
                        dynamic movies = currentUser.playlists[key]['Movies'];
                        dynamic tvshows =
                            currentUser.playlists[key]['TV Shows'];
                        dynamic accessCode =
                            currentUser.playlists[key]['AccessCode'];
                        return GestureDetector(
                          key: ValueKey(key),
                          onTap: () {
                            if (_isReordering) return;
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
                                  listResult: listResult,
                                ),
                              ),
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
                                        Colors.black.withValues(alpha: 1),
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
                                          '${S.of(context)!.movies}: ${movies.length}, ${S.of(context)!.tvShows}: ${tvshows.length}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isReordering)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: ReorderableDragStartListener(
                                      index: index,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.drag_handle,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CommonBottomAppBar(1),
    );
  }
}
