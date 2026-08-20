// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/common/firebase/playlist_join.dart';
import 'package:uractor/common/firebase/playlist_service.dart';
import 'package:uractor/l10n/l10n.dart';
import '../playlists.dart';

String cover = "";
String _listName = "";
String _accessCode = "";

final myController = TextEditingController(text: "");

class ListJoinDialogue extends StatefulWidget {
  const ListJoinDialogue({super.key});

  @override
  State<ListJoinDialogue> createState() => _ListJoinDialogueState();
}

class _ListJoinDialogueState extends State<ListJoinDialogue> {
  bool _joining = false;

  /// Asks the server whether this name and code match a list.
  ///
  /// The previous version downloaded every document in Watchlists and compared
  /// the access code on the device, which meant the app held every list's
  /// code in memory to check one of them. The check now happens in the
  /// joinPlaylist Cloud Function and only the answer comes back.
  Future<void> joinList() async {
    if (_joining) return;
    setState(() => _joining = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = user == null ? null : await user.getIdToken();
      if (idToken == null) {
        if (mounted) _report(S.of(context)!.joinListFailed);
        return;
      }

      final client = http.Client();
      JoinPlaylistResult result;
      try {
        result = await const PlaylistJoiner().join(
          client: client,
          projectId: Firebase.app().options.projectId,
          idToken: idToken,
          name: _listName,
          accessCode: _accessCode,
        );
      } finally {
        client.close();
      }

      if (!mounted) return;

      if (result.isSuccess) {
        await PlaylistService.refreshCurrentUserPlaylists();
        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const Playlists()));
        return;
      }

      _report(_messageFor(result.outcome));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _messageFor(JoinPlaylistOutcome outcome) {
    final strings = S.of(context)!;
    switch (outcome) {
      case JoinPlaylistOutcome.tooManyAttempts:
        return strings.joinListTooManyAttempts;
      case JoinPlaylistOutcome.invalidInput:
        return strings.joinListMissingDetails;
      case JoinPlaylistOutcome.notFound:
        return strings.joinListFailed;
      default:
        return strings.joinListUnavailable;
    }
  }

  void _report(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                // Contents of the Add List panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
                  child: Text(
                    S.of(context)!.joinListTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextFormField(
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return S.of(context)!.enterListName;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: S.of(context)!.listName,
                    ),
                    onChanged: (value) {
                      _listName = value;
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: S.of(context)!.accessCodeLabel,
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
                          child: Row(
                            children: [
                              const Icon(Icons.cancel, color: Colors.red),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context)!.cancel,
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
                      GestureDetector(
                        onTap: _joining
                            ? null
                            : () {
                                joinList();
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
                              const Icon(Icons.check, color: Colors.green),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context)!.add,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
