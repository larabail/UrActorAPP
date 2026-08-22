// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/common/item_container.dart';
import '../common/api/apiutils.dart';
import '../common/firebase/playlist_service.dart';
import '../common/widgets/app_dialog.dart';
import '../l10n/l10n.dart';
import '../common/constants.dart';
import '../main.dart';
import '../common/firebase/firestore_core.dart';

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
  FirebaseFirestore db = FirestoreCore.db;
  int _selectedIndex = 0;

  Future<void> addListSubmit() async {
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
    return AppDialog(
      title: 'Create a New List',
      actions: [
        AppDialogAction(
          label: 'Cancel',
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Add',
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: () async {
            await runVisibleAsyncAction(
              context,
              addListSubmit,
              S.of(context)!.genericAuthError,
            );
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
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
          const SizedBox(height: 16),
          TextFormField(
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
          const SizedBox(height: 16),
          Container(
            // A strip of posters has to be told its height, but not its width:
            // asking for 70% of the screen inside a dialogue already narrower
            // than that was clamped away and meant nothing.
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
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
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          child: GridTile(
                            child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = index;
                                    cover = IMG_LINK + item["backdrop_path"];
                                  });
                                },
                                child: getItemSelectableContainer(
                                    context, item, "media", isSelected)),
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
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Access Code For Other People',
            ),
            onChanged: (value) {
              _accessCode = value;
            },
          ),
        ],
      ),
    );
  }
}
