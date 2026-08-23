import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_core.dart';
import 'playlist_service.dart';

/// Erases the data an account leaves behind outside its own collection.
///
/// Deleting an account used to mean deleting the documents in the collection
/// named after the uid, and nothing else. That reads as complete and is not:
/// the data model puts three things somewhere else entirely.
///
///   * A playlist lives in the top-level `Watchlists` collection, not under
///     its owner, so every list a deleted account had built survived it in
///     full -- name, contents and all.
///   * The `usernames` document mapping a name to a uid survived too, which
///     left the name permanently claimed by an account that no longer existed
///     and the uid readable by any signed-in user.
///   * Friend requests are a SUBCOLLECTION under the `Friends` document, and
///     Firestore does not delete subcollections with their parent. Draining
///     it has to be explicit or it is simply orphaned.
///
/// On top of that, the uid stayed in the `friends` array of everyone who had
/// added the account, so the friends list of a real user kept an entry that
/// could never load.
///
/// [uid] is asked for rather than read from the signed-in user so this can be
/// tested without one.
class AccountDeletionService {
  /// Removes every trace of [uid] that the client is able to reach.
  ///
  /// Ordering is not cosmetic. The friends list and the playlist membership
  /// have to be READ before the account's own collection is deleted, because
  /// the friends array is the only record of who has to be told, and after
  /// the wipe there is nothing left to read it from. Every write here must
  /// also happen while the caller is still signed in: the security rules
  /// authorise all of it against `request.auth`, so a caller that deletes the
  /// Firebase Auth user first is left holding data it can no longer touch.
  static Future<void> purge(String uid) async {
    final friendUids = await _friendsOf(uid);

    // Other people's documents come first, and failures here are swallowed
    // deliberately. They are the writes most likely to be refused -- a friend
    // may have removed this user already, a shared list may be gone -- and a
    // refusal must not abort the deletion. Stopping here would leave the
    // account both half-erased and still signed-in-able, which is a worse
    // outcome for the user than an edge nobody can see.
    for (final friendUid in friendUids) {
      await _bestEffort(() => _detachFromFriend(uid, friendUid));
    }
    await _bestEffort(() => _purgePlaylists(uid));
    await _bestEffort(() => _purgeUsernames(uid));

    // The account's own data is last, and is NOT best-effort: if this fails
    // the caller must hear about it rather than go on to delete the login and
    // strand the diary behind it.
    await _purgeIncomingFriendRequests(uid);
    await _purgeOwnCollection(uid);
  }

  /// The uids in [uid]'s own friends list, read before anything is deleted.
  static Future<List<String>> _friendsOf(String uid) async {
    final doc = await FirestoreCore.db.collection(uid).doc('Friends').get();
    final data = doc.data();
    if (data == null) return const [];

    final friends = data['friends'];
    if (friends is! List) return const [];
    return friends.whereType<String>().toList();
  }

  /// Takes [uid] out of [friendUid]'s friends list and clears the request that
  /// paired them.
  ///
  /// The rules allow this: `onlyTogglesSelfInFriends` exists so that either
  /// side can end a friendship, and a friend request may be deleted by either
  /// its sender or its recipient. Both directions of the request are removed
  /// because whichever of the two people sent it, the document sits under the
  /// recipient and is keyed by the sender.
  static Future<void> _detachFromFriend(String uid, String friendUid) async {
    final friends = FirestoreCore.db.collection(friendUid).doc('Friends');
    await friends.update({
      'friends': FieldValue.arrayRemove([uid]),
    });
    await friends.collection('FriendRequests').doc(uid).delete();
  }

  /// Deletes the playlists [uid] owned and steps them out of the rest.
  ///
  /// A shared list is not the departing user's to destroy, so they are removed
  /// from it instead and it goes on existing for the people still in it. An
  /// owned list is deleted outright, which is what the account deletion page
  /// promises.
  static Future<void> _purgePlaylists(String uid) async {
    final lists = await FirestoreCore.db
        .collection('Watchlists')
        .where('memberUids', arrayContains: uid)
        .get();

    for (final list in lists.docs) {
      final data = list.data();
      final users = data['Users'];
      if (_isOwner(users, uid)) {
        await _bestEffort(() => list.reference.delete());
        continue;
      }

      final remaining = usersWithout(users is List ? users : null, uid);
      await _bestEffort(() => list.reference.update({
            'Users': remaining,
            'memberUids': PlaylistService.memberUidsFrom(remaining),
          }));
    }
  }

  /// Releases the username [uid] had claimed, so it can be taken again.
  ///
  /// Queried by uid rather than by name because the account's own `Settings`
  /// document may already be unreadable, and because a name changed by a build
  /// that failed partway can leave more than one row pointing at the same uid.
  static Future<void> _purgeUsernames(String uid) async {
    final claimed = await FirestoreCore.db
        .collection('usernames')
        .where('uid', isEqualTo: uid)
        .get();

    for (final doc in claimed.docs) {
      await _bestEffort(() => doc.reference.delete());
    }
  }

  /// Drains the friend requests sent TO [uid].
  ///
  /// These sit in `<uid>/Friends/FriendRequests`, and deleting the `Friends`
  /// document does not touch them: Firestore subcollections are independent of
  /// the document they hang from, and a deleted parent simply becomes a path
  /// segment with orphaned children underneath it.
  static Future<void> _purgeIncomingFriendRequests(String uid) async {
    final requests = await FirestoreCore.db
        .collection(uid)
        .doc('Friends')
        .collection('FriendRequests')
        .get();

    for (final doc in requests.docs) {
      await doc.reference.delete();
    }
  }

  /// Deletes every document in the collection named after [uid].
  static Future<void> _purgeOwnCollection(String uid) async {
    final own = await FirestoreCore.db.collection(uid).get();
    for (final doc in own.docs) {
      await doc.reference.delete();
    }
  }

  /// True when [users] records [uid] as the owner of the playlist.
  static bool _isOwner(Object? users, String uid) {
    if (users is! List) return false;
    for (final entry in users) {
      if (entry is Map && entry[uid] == 'Owner') return true;
    }
    return false;
  }

  /// [users] without any entry naming [uid].
  ///
  /// `Users` is a list of single-key maps, `{ "<uid>": "Owner" | "Approved" }`,
  /// so removing someone means dropping whole elements rather than editing
  /// them. Pure, and separated out because it is the part of the playlist
  /// cleanup worth testing on its own.
  static List<Map<String, dynamic>> usersWithout(List? users, String uid) {
    if (users == null) return [];

    final kept = <Map<String, dynamic>>[];
    for (final entry in users) {
      if (entry is! Map) continue;
      if (entry.containsKey(uid)) continue;
      kept.add(Map<String, dynamic>.from(entry));
    }
    return kept;
  }

  /// Runs [write], discarding any failure.
  ///
  /// Used only for documents belonging to other people or shared with them.
  /// See the reasoning in [purge].
  static Future<void> _bestEffort(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // Deliberately ignored.
    }
  }
}
