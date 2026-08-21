bool mediaPairMatches(dynamic first, dynamic second) {
  if (first is! List ||
      second is! List ||
      first.length < 2 ||
      second.length < 2) {
    return false;
  }

  return first[0] == second[0] && first[1].toString() == second[1].toString();
}

bool containsMediaPair(Iterable<dynamic> pairs, dynamic target) {
  return pairs.any((pair) => mediaPairMatches(pair, target));
}

bool shouldShowFavoriteBadge({
  required bool showFavoriteBadge,
  required Iterable<dynamic> favoriteItems,
  required dynamic item,
}) {
  return showFavoriteBadge && containsMediaPair(favoriteItems, item);
}

bool shouldShowWatchlistBadge({
  required bool showWatchlistBadge,
  required Iterable<dynamic> watchlistItems,
  required dynamic item,
}) {
  return showWatchlistBadge && containsMediaPair(watchlistItems, item);
}

/// Derives the `[type, id]` pair that identifies [data] to the membership
/// lists, or null when [data] is not a movie or TV show the app tracks.
///
/// Tiles are built from several differently shaped maps: entries from
/// `Utils.fetchMediaData` carry an explicit `type`, TMDB search results carry
/// `media_type`, and raw TMDB detail responses carry neither and are told
/// apart by `title` (movie) against `name` (TV show).
///
/// [containerType] is the string the tile itself was built with. "person" is
/// rejected outright, because a person map that has been given a `poster_path`
/// would otherwise look like a TV show and could collide with a real show id.
/// "Movies" and "TVShows" are trusted; "media" and null fall through to
/// inspecting [data].
List<dynamic>? mediaPairForData(dynamic data, {String? containerType}) {
  if (containerType == 'person') return null;
  if (data is! Map) return null;

  final dynamic id = data['id'];
  if (id == null) return null;

  final String? type = _mediaType(containerType) ??
      _mediaType(data['type']) ??
      _mediaType(data['media_type']) ??
      (data.containsKey('title')
          ? 'Movies'
          : data.containsKey('name')
              ? 'TVShows'
              : null);
  if (type == null) return null;

  return [type, id.toString()];
}

String? _mediaType(dynamic raw) {
  switch (raw) {
    case 'Movies':
    case 'movie':
      return 'Movies';
    case 'TVShows':
    case 'tv':
      return 'TVShows';
    default:
      return null;
  }
}
