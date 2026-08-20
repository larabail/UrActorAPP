/// Sorting for the media grids on the Seen, Watchlist and Favorites screens.
///
/// Those screens store nothing but `[type, id]` pairs, so everything except
/// the order items were added in has to be looked up before it can be sorted
/// on. The pure ordering logic lives here, separately from the fetching, so it
/// can be tested without a network or Firebase.
library;

/// The field a media grid is ordered by.
enum MediaSortKey { added, title, releaseDate, myRating, imdbRating }

/// The fields a media item can be sorted on, once they have been looked up.
class MediaSortMetadata {
  final String title;
  final DateTime? releaseDate;
  final double? myRating;
  final double? imdbRating;

  const MediaSortMetadata({
    this.title = '',
    this.releaseDate,
    this.myRating,
    this.imdbRating,
  });
}

/// A chosen sort: a field, and a direction.
class MediaSort {
  final MediaSortKey key;
  final bool descending;

  const MediaSort(this.key, {this.descending = true});

  /// Newest first, matching how the grids behaved before sorting existed.
  static const MediaSort defaultSort =
      MediaSort(MediaSortKey.added, descending: true);

  /// Everything except [MediaSortKey.added] needs data the grids do not hold,
  /// so choosing one of those has to fetch before it can render.
  bool get needsMetadata => key != MediaSortKey.added;

  /// Only the IMDb rating requires the extra per-item OMDB lookup.
  bool get needsImdbRating => key == MediaSortKey.imdbRating;

  String get storageValue => '${key.name}:${descending ? 'desc' : 'asc'}';

  /// Restores a sort from the value stored in the user's settings, falling
  /// back to the default for anything unrecognised so that a bad or outdated
  /// stored value cannot break the screen.
  static MediaSort fromStorage(dynamic raw) {
    if (raw is! String) return defaultSort;
    final parts = raw.split(':');
    if (parts.length != 2) return defaultSort;
    final key = MediaSortKey.values
        .where((candidate) => candidate.name == parts[0])
        .firstOrNull;
    if (key == null) return defaultSort;
    return MediaSort(key, descending: parts[1] == 'desc');
  }

  @override
  bool operator ==(Object other) =>
      other is MediaSort && other.key == key && other.descending == descending;

  @override
  int get hashCode => Object.hash(key, descending);
}

/// The key used to look an item up in a metadata map.
String mediaMetadataKey(dynamic item) {
  if (item is List && item.length >= 2) {
    return '${item[0]}:${item[1]}';
  }
  return item.toString();
}

/// Orders [items] (each a `[type, id]` pair) by [sort].
///
/// [metadata] supplies the looked-up fields, keyed by [mediaMetadataKey]. Items
/// with no metadata for the chosen field always sort last, whichever direction
/// is chosen, so that a title with a missing release date does not displace
/// items that do have one. Ties keep their existing relative order.
/// @param items The `[type, id]` pairs to order.
/// @param sort The chosen field and direction.
/// @param metadata Looked-up fields per item.
/// @return A new, ordered list.
List<dynamic> sortMediaItems(
  List<dynamic> items,
  MediaSort sort,
  Map<String, MediaSortMetadata> metadata,
) {
  // The grids are populated in the order things were added, and have always
  // been shown newest first, so "added" needs no comparison at all.
  if (sort.key == MediaSortKey.added) {
    final ordered = List<dynamic>.from(items);
    return sort.descending ? ordered.reversed.toList() : ordered;
  }

  final indexed = <MapEntry<int, dynamic>>[
    for (int i = 0; i < items.length; i++) MapEntry(i, items[i]),
  ];

  int compare(MapEntry<int, dynamic> a, MapEntry<int, dynamic> b) {
    final metaA = metadata[mediaMetadataKey(a.value)];
    final metaB = metadata[mediaMetadataKey(b.value)];

    final Comparable<Object>? valueA = _sortValue(metaA, sort.key);
    final Comparable<Object>? valueB = _sortValue(metaB, sort.key);

    // Missing values sink, regardless of direction.
    if (valueA == null && valueB == null) return a.key.compareTo(b.key);
    if (valueA == null) return 1;
    if (valueB == null) return -1;

    final int result = valueA.compareTo(valueB);
    if (result != 0) return sort.descending ? -result : result;
    // Stable: equal values keep their original order.
    return a.key.compareTo(b.key);
  }

  indexed.sort(compare);
  return indexed.map((entry) => entry.value).toList();
}

Comparable<Object>? _sortValue(MediaSortMetadata? meta, MediaSortKey key) {
  if (meta == null) return null;
  switch (key) {
    case MediaSortKey.title:
      final title = meta.title.trim();
      return title.isEmpty ? null : title.toLowerCase();
    case MediaSortKey.releaseDate:
      return meta.releaseDate;
    case MediaSortKey.myRating:
      return meta.myRating;
    case MediaSortKey.imdbRating:
      return meta.imdbRating;
    case MediaSortKey.added:
      return null;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
