// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/media_pair_membership.dart';
import '../common/firebase/firestore_core.dart';
import '../common/api/apiutils.dart';
import '../common/firebase/playlist_service.dart';
import '../common/widgets/app_dialog.dart';
import '../l10n/l10n.dart';
import '../main.dart';
import '../objects/playlist.dart';

class MovieAddDialogue extends StatefulWidget {
  final Playlist list_result;
  const MovieAddDialogue({super.key, required this.list_result});

  @override
  State<MovieAddDialogue> createState() => _MovieAddDialogueState();
}

class _MovieAddDialogueState extends State<MovieAddDialogue> {
  final myController = TextEditingController(text: "");

  String _searchTermMovie = '';
  String _movie = "";
  FirebaseFirestore db = FirestoreCore.db;

  Future<void> addMovieSubmit() async {
    String docIDString = widget.list_result.id.toString();

    var userDoc = db.collection("Watchlists").doc(docIDString);
    await FirestoreCore.mergeInto(userDoc, {
      "Movies": FieldValue.arrayUnion([_movie])
    });

    await PlaylistService.refreshCurrentUserPlaylists();

    widget.list_result.movies =
        currentUser.playlists[widget.list_result.id.toString()]["Movies"];

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add a movie to "${widget.list_result.name}"',
      actions: [
        AppDialogAction(
          label: 'Cancel',
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
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
                borderSide:
                    BorderSide(color: Color.fromARGB(250, 224, 190, 78)),
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
          const SizedBox(height: 10),
          Container(
            // A strip of posters has to be told how tall it is, but it used to
            // be told in terms of the screen *width*, which in landscape made
            // it taller than the window. The width alongside it asked for 70%
            // of the screen inside a dialogue already narrower than that, so it
            // was silently clamped and meant nothing.
            height: 190,
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
                      return GridTile(
                        child: GestureDetector(
                            onTap: () async {
                              _movie = item["id"].toString();
                              await runVisibleAsyncAction(
                                context,
                                addMovieSubmit,
                                S.of(context)!.genericAuthError,
                              );
                            },
                            child: getItemContainer(context, item, "media",
                                mediaPair: mediaPairForData(item,
                                    containerType: "Movies"))),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
