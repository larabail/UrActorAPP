/// The persisted form of the fields the media grids sort on.
///
/// Kept separate from the fetching and from the file so that versioning, the
/// staleness rule, language matching and eviction can all be exercised without
/// a network, a disk or a widget.
///
/// One field is deliberately missing. [MediaSortMetadata] also carries
/// `myRating`, which is read out of the signed-in user's reviews rather than
/// fetched, and is the only part of a sort row that belongs to a person rather
/// than to a title. It is recomputed on every load instead of being written
/// down, so a cache file cannot show one account another account's ratings
/// however badly the clearing on sign-out goes wrong.
library;

import 'dart:convert';

import 'media_sort.dart';

/// The shape currently written to disk.
///
/// A file that does not say this exact number is discarded rather than
/// migrated. It holds nothing that cannot be fetched again, so dropping it
/// costs one refetch, where guessing at the meaning of an older layout risks
/// showing wrong titles or crashing on a field that has changed type.
const int kMediaMetadataCacheVersion = 1;

/// How long an entry is trusted before it is fetched again.
///
/// Titles and release dates do not move once a title is released, and an IMDb
/// rating drifting by a few hundredths over a month does not reorder a grid in
/// any way a user would notice. A month is long enough that the cache does its
/// job and short enough that a corrected release date is not permanent.
const Duration kMediaMetadataTtl = Duration(days: 30);

/// The most entries a cache file may hold.
///
/// Without a cap the file grows for the life of the install. The limit is well
/// above a realistic library, and the oldest entries go first, so trimming
/// costs a refetch of the titles least recently looked at.
const int kMediaMetadataMaxEntries = 2000;

/// One title's cached sort fields.
class MediaMetadataEntry {
  /// The title as TMDB gave it, in [language].
  final String title;

  final DateTime? releaseDate;

  /// TMDB's IMDb id, kept so a later rating lookup can skip the `external_ids`
  /// request that TV shows would otherwise need.
  final String? imdbId;

  final double? imdbRating;

  /// Whether the IMDb rating has been looked up, regardless of whether one was
  /// found.
  ///
  /// A title with no IMDb entry, or whose lookup failed, would otherwise be
  /// retried on every single sort. Persisting the attempt keeps that true
  /// across restarts, which is the whole point of the exercise.
  final bool imdbResolved;

  /// The TMDB language [title] was fetched in.
  ///
  /// The sort loader asks TMDB without a language and so gets English, while a
  /// detail page asks in the user's own language. Without recording which one
  /// produced an entry, a Spanish user who had opened some titles and not
  /// others would get a grid sorted by a mixture of Spanish and English names,
  /// in an order that changed as they browsed.
  final String language;

  /// When the entry was fetched, for [isFresh].
  final DateTime fetchedAt;

  const MediaMetadataEntry({
    required this.title,
    required this.language,
    required this.fetchedAt,
    this.releaseDate,
    this.imdbId,
    this.imdbRating,
    this.imdbResolved = false,
  });

  /// Whether this entry is still inside [ttl] at [now].
  bool isFresh(DateTime now, {Duration ttl = kMediaMetadataTtl}) =>
      !now.isAfter(fetchedAt.add(ttl));

  /// Whether [title] and [releaseDate] may be used for a lookup made in
  /// [requestLanguage]. The IMDb fields carry no language and are always
  /// usable.
  bool matchesLanguage(String requestLanguage) => language == requestLanguage;

  /// This entry as the grids' sort model, with [myRating] supplied by the
  /// caller from the signed-in user rather than from the cache.
  MediaSortMetadata toSortMetadata({double? myRating}) => MediaSortMetadata(
        title: title,
        releaseDate: releaseDate,
        myRating: myRating,
        imdbRating: imdbRating,
      );

  MediaMetadataEntry copyWith({
    String? title,
    DateTime? releaseDate,
    String? imdbId,
    double? imdbRating,
    bool? imdbResolved,
    String? language,
    DateTime? fetchedAt,
  }) =>
      MediaMetadataEntry(
        title: title ?? this.title,
        releaseDate: releaseDate ?? this.releaseDate,
        imdbId: imdbId ?? this.imdbId,
        imdbRating: imdbRating ?? this.imdbRating,
        imdbResolved: imdbResolved ?? this.imdbResolved,
        language: language ?? this.language,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  /// Short keys because this is written once per title and a library of a few
  /// thousand makes the difference measurable on a phone.
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': title,
        if (releaseDate != null)
          'd': releaseDate!.toIso8601String().split('T').first,
        if (imdbId != null) 'i': imdbId,
        if (imdbRating != null) 'r': imdbRating,
        'ir': imdbResolved,
        'lang': language,
        'at': fetchedAt.millisecondsSinceEpoch,
      };

  /// Reads one entry, or null if it cannot be trusted.
  ///
  /// Returning null rather than throwing lets one damaged entry be dropped
  /// while the rest of the file survives; a whole library should not be
  /// refetched because a single record was written during a crash.
  static MediaMetadataEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final title = raw['t'];
    final language = raw['lang'];
    final fetchedAt = raw['at'];
    if (title is! String || language is! String || fetchedAt is! int) {
      return null;
    }
    return MediaMetadataEntry(
      title: title,
      language: language,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt),
      releaseDate: _parseDate(raw['d']),
      imdbId: raw['i'] is String ? raw['i'] as String : null,
      imdbRating: _parseRating(raw['r']),
      imdbResolved: raw['ir'] == true,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static double? _parseRating(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}

/// Turns a cache file's contents into entries and back.
///
/// Everything here is a pure function of its arguments and an explicit clock,
/// so the awkward parts -- an old version, a truncated file, an entry a month
/// past its date -- are all reachable from a plain unit test.
class MediaMetadataCodec {
  /// Reads a whole cache file.
  ///
  /// A file that is not valid JSON, is not an object, or does not carry the
  /// current version is discarded entirely: the result is empty and the caller
  /// simply behaves as though nothing had ever been cached. Entries already
  /// past [ttl] are dropped on the way in, so nothing downstream has to
  /// remember to check.
  /// @param source The raw file contents.
  /// @param now The current time, for expiry.
  /// @param ttl How long an entry stays valid.
  /// @return The usable entries, keyed by [mediaMetadataKey].
  static Map<String, MediaMetadataEntry> decode(
    String source, {
    required DateTime now,
    Duration ttl = kMediaMetadataTtl,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return <String, MediaMetadataEntry>{};
    }
    if (decoded is! Map) return <String, MediaMetadataEntry>{};
    if (decoded['version'] != kMediaMetadataCacheVersion) {
      return <String, MediaMetadataEntry>{};
    }
    final entries = decoded['entries'];
    if (entries is! Map) return <String, MediaMetadataEntry>{};

    final result = <String, MediaMetadataEntry>{};
    entries.forEach((key, value) {
      if (key is! String) return;
      final entry = MediaMetadataEntry.fromJson(value);
      if (entry == null) return;
      if (!entry.isFresh(now, ttl: ttl)) return;
      result[key] = entry;
    });
    return result;
  }

  /// Writes [entries] out, trimmed to [maxEntries].
  /// @param entries The entries to store.
  /// @param maxEntries The cap to trim to.
  /// @return The file contents to write.
  static String encode(
    Map<String, MediaMetadataEntry> entries, {
    int maxEntries = kMediaMetadataMaxEntries,
  }) {
    final kept = trim(entries, maxEntries: maxEntries);
    return jsonEncode(<String, dynamic>{
      'version': kMediaMetadataCacheVersion,
      'entries': <String, dynamic>{
        for (final entry in kept.entries) entry.key: entry.value.toJson(),
      },
    });
  }

  /// Drops the least recently fetched entries until at most [maxEntries]
  /// remain, so a long-lived install cannot grow the file without bound. The
  /// oldest go first because they are the ones whose titles the user has
  /// looked at least recently, and losing one costs a single request.
  /// @param entries The entries to trim.
  /// @param maxEntries The cap.
  /// @return At most [maxEntries] entries.
  static Map<String, MediaMetadataEntry> trim(
    Map<String, MediaMetadataEntry> entries, {
    int maxEntries = kMediaMetadataMaxEntries,
  }) {
    if (entries.length <= maxEntries) return entries;
    final ordered = entries.entries.toList()
      ..sort((a, b) => b.value.fetchedAt.compareTo(a.value.fetchedAt));
    return <String, MediaMetadataEntry>{
      for (final entry in ordered.take(maxEntries)) entry.key: entry.value,
    };
  }
}
