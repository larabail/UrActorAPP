
import '../../main.dart';
import 'firestore_core.dart';

/// A friend's display details, as shown in the friends list and the pickers.
class FriendProfileSummary {
  final String uid;
  final String userName;
  final String profilePhoto;

  const FriendProfileSummary({
    required this.uid,
    this.userName = '',
    this.profilePhoto = '',
  });
}

/// Reads and writes the signed-in user's friends.
///
/// The order of the `friends` array is the order friends are shown in, both on
/// the Friends tab and in the "seen with" pickers, so reordering is simply a
/// matter of storing the array in the order the user arranged it.
class FriendsService {
  static final Map<String, FriendProfileSummary> _profileCache = {};

  /// Clears cached profiles. Used when the signed-in user changes.
  static void clearCache() => _profileCache.clear();

  /// Persists [uids] as the user's friend order.
  ///
  /// The list is replaced wholesale rather than patched, so a reorder cannot
  /// silently drop or duplicate a friend.
  /// @param uids The friend uids, in the order they should appear.
  static Future<void> saveOrder(List<String> uids) async {
    currentUser.friends = List<String>.from(uids);
    await FirestoreCore.updateDocument(
      currentUser.uid,
      "Friends",
      {"friends": currentUser.friends},
    );
  }

  /// Moves the friend at [oldIndex] to [newIndex] and saves the result.
  ///
  /// Returns the reordered list so callers can update their state without
  /// waiting for the write to land.
  /// @param uids The current order.
  /// @param oldIndex The index being dragged.
  /// @param newIndex The index it was dropped at.
  /// @return The reordered list.
  static List<String> reorder(
    List<dynamic> uids,
    int oldIndex,
    int newIndex,
  ) {
    final List<String> next = uids.map((uid) => uid.toString()).toList();
    if (oldIndex < 0 || oldIndex >= next.length) return next;
    // A drag downwards reports the index the item would occupy while it is
    // still in the list, which is one further along than where it lands.
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target < 0 || target >= next.length) return next;
    final String moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    return next;
  }

  /// Loads the display details for [uids], caching them for the session so
  /// that dragging the list does not refetch every row on every frame.
  /// @param uids The friend uids to describe.
  /// @return The summaries, in the order requested.
  static Future<List<FriendProfileSummary>> loadProfiles(
      List<dynamic> uids) async {
    final missing = uids
        .map((uid) => uid.toString())
        .where((uid) => !_profileCache.containsKey(uid))
        .toList();

    await Future.wait(missing.map((uid) async {
      try {
        final doc = await FirestoreCore.db
            .collection(uid)
            .doc('Settings')
            .get();
        final data = doc.data();
        _profileCache[uid] = FriendProfileSummary(
          uid: uid,
          userName: data?['username']?.toString() ?? '',
          profilePhoto: data?['profile_photo']?.toString() ?? '',
        );
      } catch (_) {
        // An unreadable friend still needs a row, so that reordering does not
        // silently drop them from the list.
        _profileCache[uid] = FriendProfileSummary(uid: uid);
      }
    }));

    return uids
        .map((uid) =>
            _profileCache[uid.toString()] ??
            FriendProfileSummary(uid: uid.toString()))
        .toList();
  }
}
