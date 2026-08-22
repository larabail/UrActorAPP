import 'package:flutter/material.dart';

import '../main.dart';
import '../objects/media.dart';
import '../common/api/http_client.dart';
import '../common/firebase/callable_context.dart';
import '../common/firebase/recommend_title.dart';
import '../common/widgets/app_dialog.dart';
import '../common/widgets/friend_picker.dart';
import '../l10n/l10n.dart';

class Share extends StatefulWidget {
  final MediaItem item;
  final String type;

  const Share({super.key, required this.item, required this.type});

  @override
  State<Share> createState() => _ShareState();
}

class _ShareState extends State<Share> {
  Map<String, bool> selectedFriends = {};
  bool _sending = false;

  /// Asks the server to file this title in each ticked friend's inbox.
  ///
  /// This used to happen here: read the friend's whole `Notifications`
  /// document, add a key, write the whole thing back. Three things were wrong
  /// with that. `sender` was assembled on this device and believed by
  /// everything downstream, so a recommendation could be filed under a third
  /// party's name. The write was unmerged, so two people recommending at the
  /// same moment silently lost one of the two. And every failure went into a
  /// debugPrint, so a recommendation that never arrived looked exactly like
  /// one that did.
  ///
  /// The `recommendTitle` Cloud Function derives the sender from the caller's
  /// token, checks each recipient's own friends list, and appends inside a
  /// transaction.
  ///
  /// The key that append lands on is LOAD-BEARING, and still worth knowing
  /// here even though this code no longer picks it. Builds already on people's
  /// phones append at `String(number of keys already present)`, and
  /// `appendsOneNotificationOnly` in `firestore.rules` can only reach the
  /// entry it validates by rebuilding exactly that key. Anything that writes a
  /// notification under a different scheme leaves the document sparse, and
  /// from then on every append from an old client reads as a change rather
  /// than an add and is refused — silently, because the old client swallows
  /// the error. See `appendNotification` in `functions/index.js`.
  Future<void> _send() async {
    if (_sending) return;

    final recipients = selectedFriends.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (recipients.isEmpty) {
      Navigator.pop(context, true);
      return;
    }

    // Read before the first await, so nothing below depends on the dialogue
    // still being mounted when the call comes back.
    final strings = S.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sending = true);
    RecommendTitleResult result;
    try {
      // Fetching the token and reading the project both reach into Firebase
      // and can throw. Letting that escape would leave the user with a closed
      // sheet and no idea whether anything was sent.
      final idToken = await CallableContext.idToken();
      result = idToken == null
          ? const RecommendTitleResult(RecommendTitleOutcome.notSignedIn)
          : await const TitleRecommender().recommend(
              client: AppHttp.client,
              projectId: CallableContext.projectId(),
              idToken: idToken,
              id: widget.item.id,
              type: widget.type,
              title: widget.item.title,
              coverPhoto: widget.item.coverPhoto,
              friends: recipients,
            );
    } catch (_) {
      result = const RecommendTitleResult(RecommendTitleOutcome.failed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    if (!result.isSuccess) {
      // The messenger belongs to the page underneath, not to this dialogue, so
      // it is still the right place to say this even if the sheet has gone.
      messenger.showSnackBar(
        SnackBar(content: Text(_messageFor(strings, result.outcome))),
      );
    }

    // Only if the sheet is still up. Someone who backed out while the call was
    // in flight has already popped this route, and popping again would take
    // the page underneath with it.
    if (!mounted) return;

    // Otherwise the sheet closes either way: the snackbar carries the failure,
    // and leaving the picker open invites a second attempt at the friends who
    // did receive it.
    navigator.pop(true);
  }

  String _messageFor(S strings, RecommendTitleOutcome outcome) {
    switch (outcome) {
      case RecommendTitleOutcome.partiallySent:
        return strings.recommendationSendPartial;
      default:
        return strings.recommendationSendFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendIds = List<String>.from(currentUser.friends);
    return AppDialog(
      actions: [
        AppDialogAction(
          label: S.of(context)!.cancel,
          icon: Icons.cancel,
          tone: AppDialogTone.cancel,
          onPressed: _sending ? null : () => Navigator.pop(context, true),
        ),
        AppDialogAction(
          label: S.of(context)!.accept,
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: _sending ? null : _send,
        ),
      ],
      child: FriendPicker(
        friendIds: friendIds,
        selected: selectedFriends,
        onChanged: (friendId, value) {
          setState(() => selectedFriends[friendId] = value);
        },
      ),
    );
  }
}
