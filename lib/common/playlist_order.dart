/// Per-user ordering for playlists.
///
/// Playlists are shared documents in the `Watchlists` collection, so the order
/// cannot be stored on the playlist itself without one member's arrangement
/// changing it for everyone. It is kept in the user's own settings instead, as
/// a list of playlist ids.
library;

/// The settings key holding the user's playlist order.
const String kPlaylistOrderSettingsKey = 'playlistOrder';

/// The id of the generated recommendations list, which is presented separately
/// rather than as one of the user's own playlists.
const String kRecommendationsPlaylistId = 'recommendations';

/// Orders [availableIds] according to [storedOrder].
///
/// Ids in [storedOrder] come first, in that order. Anything not mentioned,
/// which is any playlist created or joined since the order was last saved,
/// follows in its existing order, so a new playlist appears predictably at the
/// end rather than at an arbitrary position. Ids in [storedOrder] that no
/// longer exist are dropped, so leaving a playlist cannot leave a hole.
/// @param availableIds The playlist ids the user currently has.
/// @param storedOrder The previously saved order, if any.
/// @return The ids in display order.
List<String> orderPlaylistIds(
  Iterable<String> availableIds,
  dynamic storedOrder,
) {
  final List<String> available =
      availableIds.where((id) => id != kRecommendationsPlaylistId).toList();
  final Set<String> remaining = available.toSet();

  final List<String> ordered = [];
  if (storedOrder is List) {
    for (final entry in storedOrder) {
      final String id = entry.toString();
      if (remaining.remove(id)) {
        ordered.add(id);
      }
    }
  }

  // Preserve the incoming order for anything the stored order did not mention.
  for (final id in available) {
    if (remaining.contains(id)) {
      ordered.add(id);
    }
  }

  return ordered;
}

/// Moves the playlist at [oldIndex] to [newIndex].
///
/// Mirrors the index adjustment ReorderableListView requires: a downward drag
/// reports the index the item would occupy while it is still in the list.
/// @param ids The current order.
/// @param oldIndex The index being dragged.
/// @param newIndex The index it was dropped at.
/// @return The reordered ids.
List<String> reorderPlaylistIds(List<String> ids, int oldIndex, int newIndex) {
  final List<String> next = List<String>.from(ids);
  if (oldIndex < 0 || oldIndex >= next.length) return next;
  final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  if (target < 0 || target >= next.length) return next;
  final String moved = next.removeAt(oldIndex);
  next.insert(target, moved);
  return next;
}
