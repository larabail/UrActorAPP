import 'dart:async';
import 'dart:convert';

import '../main.dart';
import 'api/apiutils.dart';
import 'constants.dart';
import 'media_metadata_cache.dart';
import 'media_metadata_store.dart';
import 'media_sort.dart';
import 'api/http_client.dart';

/// Looks up the fields the media grids need in order to sort.
///
/// The grids only store `[type, id]` pairs, so sorting by anything other than
/// the order items were added in means fetching every item first. Results are
/// cached in memory for the life of the session, and written to disk so that
/// the next session starts with them: a library of a few hundred titles used
/// to cost a request each on every cold start, fifty round trips deep before
/// the grid could render, and three requests each when sorting by IMDb rating.
///
/// Only the parts of an entry that belong to the title are stored -- its name,
/// release date, IMDb id and IMDb rating. The user's own rating is read out of
/// [currentUser] on every load instead, so no cache file ever holds one
/// account's data for another to find.
class MediaSortLoader {
  /// TMDB tolerates bursts, but firing several hundred requests at once is
  /// enough to get rate limited and to stall the UI, so they are windowed.
  static const int _maxConcurrent = 6;

  /// The language titles are fetched in here.
  ///
  /// This class asks TMDB without a `language` parameter, so it gets TMDB's
  /// default. Naming it lets an entry written by a detail page -- which does
  /// ask in the user's language -- be recognised as a different language and
  /// its title refetched, while its IMDb id and rating, which have no
  /// language, are still used.
  static const String _requestLanguage = 'en';

  /// How long writes are held back so that a burst of them costs one write.
  static const Duration _flushDelay = Duration(milliseconds: 400);

  static final Map<String, MediaMetadataEntry> _cache = {};

  /// The user the cache in memory belongs to, remembered rather than read from
  /// [currentUser] at the moment it is needed.
  ///
  /// Sign-out clears Firebase's user and this cache from two different places,
  /// and the order is not guaranteed. Holding the uid the entries were loaded
  /// under means the file that gets deleted is always the one they came from,
  /// even if `currentUser` has already been replaced by the time it happens.
  static String? _activeUid;

  static bool _hydrated = false;
  static Future<void>? _hydrating;
  static bool _dirty = false;
  static Timer? _flushTimer;
  static Future<void>? _flushInFlight;

  /// Clears the cache, in memory and on disk.
  ///
  /// Used when the signed-in user changes, and by tests. The stored file is
  /// deleted too: leaving it would let the next account to sign in start from
  /// the previous one's titles.
  /// @return Completes once the stored copy is gone.
  static Future<void> clearCache() async {
    final String? uid = _activeUid;
    _cache.clear();
    _hydrated = false;
    _hydrating = null;
    _dirty = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _activeUid = null;
    if (uid != null) await MediaMetadataStore.clear(uid);
  }

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
    await _hydrate();

    final List<dynamic> pending = items
        .where((item) => _needsFetch(
              _cache[mediaMetadataKey(item)],
              includeImdbRating: includeImdbRating,
            ))
        .toList();

    for (int i = 0; i < pending.length; i += _maxConcurrent) {
      final window = pending.skip(i).take(_maxConcurrent);
      await Future.wait(window.map(
        (item) => _loadOne(item, includeImdbRating: includeImdbRating),
      ));
    }

    _scheduleFlush();

    return {
      for (final item in items)
        if (_cache[mediaMetadataKey(item)] != null)
          mediaMetadataKey(item):
              _cache[mediaMetadataKey(item)]!.toSortMetadata(
            // Read fresh every time rather than stored: it is the one field
            // that belongs to the person rather than the title, and it changes
            // the moment they rate something.
            myRating: _myRatingFor(item),
          ),
    };
  }

  /// Records what a detail page just fetched, so a later sort does not fetch
  /// it again.
  ///
  /// The detail screens already request exactly these fields. Feeding them
  /// back here is what makes sorting free in normal use, and it is the only
  /// way the expensive part -- the IMDb rating, which costs an OMDB request
  /// and, for a show, a TMDB `external_ids` request -- gets paid for once
  /// rather than on the first sort of every session.
  /// @param type The grid's media type, `Movies` or `TVShows`.
  /// @param id The TMDB id.
  /// @param language The language [title] was fetched in.
  static void remember({
    required String type,
    required String id,
    required String language,
    String? title,
    DateTime? releaseDate,
    String? imdbId,
    double? imdbRating,
    bool imdbResolved = false,
  }) {
    if (id.isEmpty) return;
    final String key = mediaMetadataKey([type, id]);
    final MediaMetadataEntry? existing = _cache[key];
    // Nothing to anchor an entry on: a rating with no title would sort as a
    // blank row, which is worse than fetching the title later.
    if (existing == null && (title == null || title.isEmpty)) return;

    _cache[key] = MediaMetadataEntry(
      title: title ?? existing!.title,
      releaseDate: releaseDate ?? existing?.releaseDate,
      imdbId: imdbId ?? existing?.imdbId,
      imdbRating: imdbRating ?? existing?.imdbRating,
      imdbResolved: imdbResolved || (existing?.imdbResolved ?? false),
      language: title != null ? language : (existing?.language ?? language),
      fetchedAt: DateTime.now(),
    );
    _dirty = true;
    _scheduleFlush();
  }

  /// Writes any pending changes out now instead of waiting for the debounce.
  /// Tests await this rather than sleeping; nothing in the app needs it.
  static Future<void> flushPending() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
  }

  static bool _needsFetch(
    MediaMetadataEntry? entry, {
    required bool includeImdbRating,
  }) {
    if (entry == null) return true;
    // A title stored by a detail page in another language is still worth
    // keeping for its IMDb fields, but its name has to be fetched again or the
    // grid would sort a mixture of languages.
    if (!entry.matchesLanguage(_requestLanguage)) return true;
    return includeImdbRating && !entry.imdbResolved;
  }

  static Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrating ??= _readStored();
    await _hydrating;
  }

  static Future<void> _readStored() async {
    final String uid = _uid();
    _activeUid = uid.isEmpty ? null : uid;
    final String? raw = await MediaMetadataStore.read(uid);
    if (raw != null) {
      final stored = MediaMetadataCodec.decode(raw, now: DateTime.now());
      // Anything already in memory was fetched this session and is at least as
      // fresh as the file, so it wins.
      stored.forEach((key, value) => _cache.putIfAbsent(key, () => value));
    }
    _hydrated = true;
    _hydrating = null;
  }

  static void _scheduleFlush() {
    if (!_dirty) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () {
      _flushTimer = null;
      _flush();
    });
  }

  static Future<void> _flush() async {
    if (!_dirty) return;
    // A write already in flight would otherwise be raced by this one, and
    // whichever finished last would be the copy on disk.
    if (_flushInFlight != null) {
      await _flushInFlight;
      if (!_dirty) return;
    }
    final String uid = _activeUid ?? _uid();
    if (uid.isEmpty) return;
    _dirty = false;
    final Future<void> write = MediaMetadataStore.write(
      uid,
      MediaMetadataCodec.encode(Map<String, MediaMetadataEntry>.from(_cache)),
    );
    _flushInFlight = write;
    try {
      await write;
    } finally {
      _flushInFlight = null;
    }
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

    MediaMetadataEntry? entry = _cache[cacheKey];

    try {
      if (entry == null || !entry.matchesLanguage(_requestLanguage)) {
        final String link = isShow ? TV_SHOW_LINK : MOVIE_LINK;
        final response =
            await AppHttp.client.get(Uri.parse('$link$id$API_KEY'));
        if (response.statusCode != 200) return;
        final Map json = jsonDecode(response.body) as Map;

        entry = MediaMetadataEntry(
          title: (isShow ? json['name'] : json['title'])?.toString() ?? '',
          releaseDate: _parseDate(
              isShow ? json['first_air_date'] : json['release_date']),
          // Anything a detail page already resolved survives a title refetch;
          // those are the expensive lookups and they do not vary by language.
          imdbId: json['imdb_id']?.toString() ?? entry?.imdbId,
          imdbRating: entry?.imdbRating,
          imdbResolved: entry?.imdbResolved ?? false,
          language: _requestLanguage,
          fetchedAt: DateTime.now(),
        );
        _cache[cacheKey] = entry;
        _dirty = true;
      }

      if (includeImdbRating && !entry.imdbResolved) {
        // Marked resolved before the lookup rather than after, so that a title
        // with no IMDb entry, or a failed request, is not retried on every
        // sort from here to the end of time.
        entry = entry.copyWith(imdbResolved: true);
        _cache[cacheKey] = entry;
        _dirty = true;

        final String? imdbId = entry.imdbId ?? await _fetchImdbId(type, id);
        if (imdbId != null && imdbId.isNotEmpty) {
          final double? rating = await _fetchImdbRating(imdbId);
          entry = entry.copyWith(imdbId: imdbId, imdbRating: rating);
          _cache[cacheKey] = entry;
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

  static double? _myRatingFor(dynamic item) {
    if (item is! List || item.length < 2) return null;
    return _myRating(item[0].toString(), item[1].toString());
  }

  static double? _myRating(String type, String id) {
    final Map reviews =
        type == "TVShows" ? currentUser.tvShowReviews : currentUser.reviews;
    final review = reviews[id];
    if (review is! Map) return null;
    return double.tryParse(review['Rating']?.toString() ?? '');
  }

  /// The signed-in user, or an empty string when there is none. `currentUser`
  /// is a `late` global, and reading it before it is assigned throws, which
  /// happens in tests that never sign anybody in.
  static String _uid() {
    try {
      return currentUser.uid;
    } catch (_) {
      return '';
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
