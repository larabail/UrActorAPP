// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/common/item_container.dart';
import '../common/firebase/firestore_core.dart';
import '../common/constants.dart';
import '../common/api/apiutils.dart';
import '../common/widgets/app_dialog.dart';
import '../l10n/l10n.dart';
import '../list_result.dart';
import '../objects/playlist.dart';

class ListEditDialogue extends StatefulWidget {
  final Playlist list_result;
  const ListEditDialogue({super.key, required this.list_result});

  @override
  State<ListEditDialogue> createState() => _ListEditDialogueState();
}

class _ListEditDialogueState extends State<ListEditDialogue> {
  final list_name_controller = listName != ""
      ? TextEditingController(text: listName)
      : TextEditingController(text: "");
  final access_code_controller = accessCode != ""
      ? TextEditingController(text: accessCode)
      : TextEditingController(text: "");

  String _searchTermMovie = '';
  FirebaseFirestore db = FirestoreCore.db;

  int _selectedIndex = 0;

  /// Saves the edited name, cover and access code against the list.
  ///
  /// This used to find the document by downloading every playlist in the
  /// collection and matching on name and access code, which needed a read of
  /// other people's lists to edit your own and picked the wrong document when
  /// two lists shared both fields. The dialogue is opened with the playlist,
  /// so its id is already known.
  Future<void> editListSubmit() async {
    final listDoc =
        FirestoreCore.db.collection("Watchlists").doc(widget.list_result.id);
    await FirestoreCore.mergeInto(listDoc, {
      "Name": listName,
      "CoverPhoto": cover,
      "AccessCode": accessCode,
    });
    widget.list_result.accesscode = accessCode;
    widget.list_result.name = listName;
    widget.list_result.backdrop = cover;
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Modify "${widget.list_result.name}"',
      actions: [
        AppDialogAction(
          label: 'Cancel',
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Accept',
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: () async {
            await runVisibleAsyncAction(
              context,
              editListSubmit,
              S.of(context)!.genericAuthError,
            );
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
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
            controller: access_code_controller,
            decoration: const InputDecoration(
              labelText: 'Access Code For Other People',
            ),
            onChanged: (value) {
              accessCode = value;
            },
          ),
        ],
      ),
    );
  }
}
