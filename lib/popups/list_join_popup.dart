// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/common/firebase/playlist_join.dart';
import 'package:uractor/common/firebase/playlist_service.dart';
import 'package:uractor/common/widgets/app_dialog.dart';
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
    return AppDialog(
      title: S.of(context)!.joinListTitle,
      actions: [
        AppDialogAction(
          label: S.of(context)!.cancel,
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: S.of(context)!.add,
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: _joining ? null : joinList,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
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
          const SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: S.of(context)!.accessCodeLabel,
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
