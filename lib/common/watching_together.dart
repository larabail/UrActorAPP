/// The derivations behind the Watching together sections.
///
/// "Seen with" already records who a title was watched alongside, and
/// `ProgressService` already knows which titles are started but unfinished.
/// Neither of them, on its own, answers the question the friends pages ask:
/// which shows are we part way through *together*. Crossing the two is what
/// lives here.
///
/// It is a separate file from the widget for the same reason
/// `continue_watching.dart` is: the section needs a `MediaQuery`, an HTTP stub
/// and a fake Firestore before it will render at all, whereas everything below
/// is a plain function over plain data and can be pinned down cheaply.
library;

import 'firebase/progress_service.dart';

/// How many shared shows a section draws.
///
/// Each tile costs one TMDB request, and the friends page draws its row across
/// every friend at once, so the cap bounds the request count no matter how
/// many friends a heavy user has watched things with.
const int kWatchingTogetherLimit = 10;

/// How many shared shows the friends list resolves titles for.
///
/// Higher than [kWatchingTogetherLimit] because the friends list spreads its
/// titles across every friend rather than concentrating them in one row: a cap
/// of ten would leave the friends further down the list looking as though
/// nothing is running with them. It is still a cap, because each distinct show
/// costs one TMDB request.
const int kWatchingTogetherLineLimit = 20;

/// One show being watched together, and who with.
///
/// [friendUids] is a list rather than a single uid because the same show can
/// be shared with more than one friend, and drawing the poster once per friend
/// would turn a household watching the same series into three identical tiles.
class WatchingTogetherShow {
  const WatchingTogetherShow({
    required this.id,
    required this.friendUids,
    required this.updated,
  });

  /// The TMDB show id, as stored in progress.
  final String id;

  /// The friends this show is shared with, in the order the friends were
  /// given — which is the order the user arranged their friends list in.
  final List<String> friendUids;

  /// The `yyyy-MM-dd` the progress entry was last touched, carried through so
  /// a caller can order or caption by it without re-reading progress.
  final String updated;
}

/// The shows both in progress and marked as seen with one of [friends].
///
/// Movies are deliberately excluded. A movie is watched in one sitting, so
/// "part way through a film with someone" is a state that lasts an evening and
/// is not worth a permanent row; a series watched together is the thing people
/// lose track of and come back to.
///
/// [inProgress] arrives from `ProgressService.inProgressItems()`, already
/// sorted by last activity, newest first, and that order is preserved rather
/// than recomputed here — re-sorting would quietly become the real ordering
/// and the service's would stop being the thing anyone maintains.
///
/// A show shared with a uid that is not in [friends] is dropped, so a removed
/// friend stops appearing without anything having to rewrite the stored
/// "seen with" data.
///
/// @param inProgress The started-but-unfinished titles, in display order.
/// @param seenWith The `currentUser.seenWith` map: friend uid to
///        `{"Movies": [...], "TVShows": [...]}`.
/// @param friends The friend uids to consider, in display order.
/// @param limit How many shows to keep.
/// @return One entry per shared show, newest activity first.
List<WatchingTogetherShow> watchingTogetherShows(
  List<WatchProgressListItem> inProgress,
  Map<dynamic, dynamic> seenWith, {
  required List<dynamic> friends,
  int limit = kWatchingTogetherLimit,
}) {
  if (limit <= 0) return const <WatchingTogetherShow>[];

  final ordered = friends.map((uid) => uid.toString()).toList();
  final sharedByShow = <String, List<String>>{};
  for (final uid in ordered) {
    for (final id in _showIdsSharedWith(seenWith, uid)) {
      // Guards against a friend appearing twice in the stored order, which
      // would otherwise caption a tile with the same name twice.
      final holders = sharedByShow.putIfAbsent(id, () => <String>[]);
      if (!holders.contains(uid)) holders.add(uid);
    }
  }

  final shows = <WatchingTogetherShow>[];
  for (final item in inProgress) {
    if (item.type != progressTVShowsKey) continue;
    final holders = sharedByShow[item.id];
    if (holders == null || holders.isEmpty) continue;
    shows.add(
      WatchingTogetherShow(
        id: item.id,
        friendUids: List<String>.unmodifiable(holders),
        updated: item.updated,
      ),
    );
    if (shows.length == limit) break;
  }
  return List<WatchingTogetherShow>.unmodifiable(shows);
}

/// The show ids [uid] is recorded as having watched with the signed-in user.
///
/// Reads defensively because the map is assembled from a Firestore document
/// that predates this feature: an entry with no `TVShows` key, or a key
/// holding something other than a list, is a friend with nothing shared rather
/// than a crash on the friends page.
List<String> _showIdsSharedWith(Map<dynamic, dynamic> seenWith, String uid) {
  final entry = seenWith[uid];
  if (entry is! Map) return const <String>[];
  final shows = entry[progressTVShowsKey];
  if (shows is! Iterable) return const <String>[];
  return shows.map((id) => id.toString()).toList();
}

/// The shared shows grouped by friend, for a surface that lists friends
/// rather than shows.
///
/// The poster row asks "what are we watching together" and answers it one tile
/// per show. A friend list asks the same question the other way round — under
/// each name, what is running with that person — and needs the same data
/// inverted. Deriving it here rather than re-deriving from `seenWith` means
/// both surfaces agree on what counts as shared and in progress.
///
/// A show shared with two friends appears under both, which is correct: it is
/// running with each of them.
///
/// @param shows The shared shows, in display order.
/// @return Friend uid to that friend's share of the shows, order preserved.
///         A friend with nothing shared is absent rather than mapped to an
///         empty list, so a caller can test presence.
Map<String, List<String>> watchingTogetherByFriend(
  List<WatchingTogetherShow> shows,
) {
  final byFriend = <String, List<String>>{};
  for (final show in shows) {
    for (final uid in show.friendUids) {
      byFriend.putIfAbsent(uid, () => <String>[]).add(show.id);
    }
  }
  return <String, List<String>>{
    for (final entry in byFriend.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  };
}

/// The titles to put on one friend's line, in the order the shows were given.
///
/// Ids TMDB would not resolve are dropped rather than written as "Unknown". On
/// a poster row an unresolved title still has a tile worth showing and a
/// placeholder to put in it; on a line of names it would just be a word that
/// says nothing, scrolling past between two real ones.
///
/// @param showIds The shared shows for this friend, in display order.
/// @param titles Show id to title, for the ids that resolved.
/// @return The titles to show, deduplicated, in order.
List<String> watchingTogetherTitles(
  List<String> showIds,
  Map<String, String> titles,
) {
  final line = <String>[];
  for (final id in showIds) {
    final title = titles[id]?.trim();
    if (title == null || title.isEmpty) continue;
    // Two ids can carry the same name after a TMDB merge, and the same name
    // twice on one line reads as a mistake.
    if (line.contains(title)) continue;
    line.add(title);
  }
  return List<String>.unmodifiable(line);
}
