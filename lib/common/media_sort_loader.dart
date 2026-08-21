import 'dart:async';
import 'dart:convert';

import '../main.dart';
import 'api/apiutils.dart';
import 'constants.dart';
import 'media_sort.dart';
import 'api/http_client.dart';

/// Looks up the fields the media grids need in order to sort.
///
/// The grids only store `[type, id]` pairs, so sorting by anything other than
/// the order items were added in means fetching every item first. Results are
/// cached for the life of the session, because the same titles are sorted over
/// and over as the user moves between the Seen, Watchlist and Favorites tabs.
class MediaSortLoader {
  /// TMDB tolerates bursts, but firing several hundred requests at once is
  /// enough to get rate limited and to stall the UI, so they are windowed.
  static const int _maxConcurrent = 6;

  static final Map<String, _CacheEntry> _cache = {};

  /// Clears the cache. Used when the signed-in user changes, and by tests.
  static void clearCache() => _cache.clear();

  /// Loads the sortable fields for [items].
  ///
  /// [includeImdbRating] additionally resolves each item's IMDb rating, which
  /// costs a second request per item against OMDB and is only worth paying for
  /// when actually sorting by it.
  /// @param items The `[type, id]` pairs to describe.
  /// @param includeImdbRating Whether to resolve IMDb ratings too.
  /// @return Metadata keyed by [mediaMetadataKey].
  static Future<Map<String, MediaSortMetadata>> load(
    List<dynamic> items, {
    bool includeImdbRating = false,
  }) async {
    final List<dynamic> pending = items.where((item) {
      final entry = _cache[mediaMetadataKey(item)];
      if (entry == null) return true;
      return includeImdbRating && !entry.imdbResolved;
    }).toList();

    for (int i = 0; i < pending.length; i += _maxConcurrent) {
      final window = pending.skip(i).take(_maxConcurrent);
      await Future.wait(window.map(
        (item) => _loadOne(item, includeImdbRating: includeImdbRating),
      ));
    }

    return {
      for (final item in items)
        if (_cache[mediaMetadataKey(item)] != null)
          mediaMetadataKey(item): _cache[mediaMetadataKey(item)]!.metadata,
    };
  }

  static Future<void> _loadOne(
    dynamic item, {
    required bool includeImdbRating,
  }) async {
    if (item is! List || item.length < 2) return;
    final String type = item[0].toString();
    final String id = item[1].toString();
    final String cacheKey = mediaMetadataKey(item);
    final bool isShow = type == "TVShows";

    _CacheEntry? entry = _cache[cacheKey];

    try {
      if (entry == null) {
        final String link = isShow ? TV_SHOW_LINK : MOVIE_LINK;
        final response =
            await AppHttp.client.get(Uri.parse('$link$id$API_KEY'));
        if (response.statusCode != 200) return;
        final Map json = jsonDecode(response.body) as Map;

        entry = _CacheEntry(
          metadata: MediaSortMetadata(
            title: (isShow ? json['name'] : json['title'])?.toString() ?? '',
            releaseDate: _parseDate(
                isShow ? json['first_air_date'] : json['release_date']),
            myRating: _myRating(type, id),
          ),
          imdbId: json['imdb_id']?.toString(),
        );
        _cache[cacheKey] = entry;
      }

      if (includeImdbRating && !entry.imdbResolved) {
        // Marked resolved regardless of the outcome: a title with no IMDb
        // entry, or a failed lookup, must not be retried on every sort.
        entry.imdbResolved = true;
        final String? imdbId = entry.imdbId ?? await _fetchImdbId(type, id);
        if (imdbId != null && imdbId.isNotEmpty) {
          final double? rating = await _fetchImdbRating(imdbId);
          entry.metadata = MediaSortMetadata(
            title: entry.metadata.title,
            releaseDate: entry.metadata.releaseDate,
            myRating: entry.metadata.myRating,
            imdbRating: rating,
          );
        }
      }
    } catch (_) {
      // A single unreachable title must not fail the whole sort; it simply
      // has no metadata and sinks to the bottom of the list.
    }
  }

  /// TV details do not carry an IMDb id, unlike movies, so it has to be read
  /// from the external ids endpoint.
  static Future<String?> _fetchImdbId(String type, String id) async {
    if (type != "TVShows") return null;
    final response = await AppHttp.client
        .get(Uri.parse('$TV_SHOW_LINK$id$EXTERNAL_IDS_LINK'));
    if (response.statusCode != 200) return null;
    return (jsonDecode(response.body) as Map)['imdb_id']?.toString();
  }

  static Future<double?> _fetchImdbRating(String imdbId) async {
    final data = await ApiUtils.fetchOmdbData(imdbId);
    if (data is! Map) return null;
    final raw = data['imdbRating']?.toString();
    if (raw == null || raw == 'N/A') return null;
    return double.tryParse(raw);
  }

  static double? _myRating(String type, String id) {
    final Map reviews =
        type == "TVShows" ? currentUser.tvShowReviews : currentUser.reviews;
    final review = reviews[id];
    if (review is! Map) return null;
    return double.tryParse(review['Rating']?.toString() ?? '');
  }

  static DateTime? _parseDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class _CacheEntry {
  MediaSortMetadata metadata;
  final String? imdbId;
  bool imdbResolved;

  _CacheEntry({
    required this.metadata,
    this.imdbId,
  }) : imdbResolved = false;
}
