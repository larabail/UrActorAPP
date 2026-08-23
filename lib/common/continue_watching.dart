/// The derivations behind the home page's Continue watching section.
///
/// `ProgressService` already answers the hard questions — which titles are
/// started but unfinished, in what order, and which episode comes next. What is
/// left over is the part that touches TMDB payloads and decides how much of the
/// list to draw, and that is what lives here.
///
/// It is a separate file from the widget on purpose. The section cannot be
/// exercised without a `MediaQuery`, an HTTP stub and a fake Firestore, whereas
/// everything below is a plain function over plain data, so the rules can be
/// pinned down cheaply and the widget test is left to cover only what a widget
/// test uniquely can.
library;

import 'firebase/progress_service.dart';

/// How many in-progress titles the section draws.
///
/// Each tile costs one TMDB request, and a heavy user can accumulate far more
/// unfinished titles than anyone scrolls through on a home page. Capping the
/// list bounds the request count regardless of how lazily the row builds.
const int kContinueWatchingLimit = 10;

/// Takes the front of [items], up to [limit].
///
/// `ProgressService.inProgressItems()` already sorts by last activity, newest
/// first, so this deliberately does not re-sort: doing so a second time here
/// would quietly become the real ordering and the service's would stop being
/// the thing anyone maintains.
/// @param items The in-progress titles, already in display order.
/// @param limit How many to keep.
/// @return The kept items, in the order they arrived.
List<WatchProgressListItem> continueWatchingEntries(
  List<WatchProgressListItem> items, {
  int limit = kContinueWatchingLimit,
}) {
  if (limit <= 0) return const <WatchProgressListItem>[];
  return List<WatchProgressListItem>.unmodifiable(items.take(limit));
}

/// Reads the `seasons` array of a TMDB show payload into the shape
/// `WatchProgressView.resumeFrom` expects.
///
/// The show detail response already carries this, so the section gets season
/// counts out of the request it was making anyway rather than firing a second
/// one per show.
///
/// Season 0 is kept rather than filtered, because `ProgressService` is the
/// thing that decides specials do not count and stripping them here as well
/// would put that rule in two places. Anything unparseable is dropped instead
/// of defaulting, since a season with a made-up number would send the caller to
/// an episode that does not exist.
/// @param seasons The decoded `seasons` value, of whatever shape TMDB sent.
/// @return One entry per usable season, in the order given.
List<SeasonEpisodeCount> seasonCountsFromTmdb(dynamic seasons) {
  if (seasons is! Iterable) return const <SeasonEpisodeCount>[];
  final counts = <SeasonEpisodeCount>[];
  for (final season in seasons) {
    if (season is! Map) continue;
    final number = _asInt(season['season_number']);
    if (number == null || number < 0) continue;
    final episodes = _asInt(season['episode_count']) ?? 0;
    counts.add(
      SeasonEpisodeCount(
        seasonNumber: number,
        episodeCount: episodes < 0 ? 0 : episodes,
      ),
    );
  }
  return counts;
}

/// What the section knows about one title after asking TMDB.
///
/// A TMDB id stored in progress can stop resolving — the title is merged into
/// another entry, or withdrawn. That must not take the home page down with it,
/// so a failed lookup becomes a [ContinueWatchingMedia.missing] value that
/// still renders, rather than an exception or a null the caller has to
/// remember to handle.
class ContinueWatchingMedia {
  const ContinueWatchingMedia({
    required this.type,
    required this.id,
    this.title,
    this.posterPath,
    this.seasons = const <SeasonEpisodeCount>[],
    this.missing = false,
  });

  /// Builds an entry from a decoded TMDB detail payload.
  ///
  /// Movies carry `title` and shows carry `name`; both are normalised to
  /// [title] so the tile does not have to care which it is looking at.
  /// @param type `Movies` or `TVShows`, as stored in progress.
  /// @param id The TMDB id.
  /// @param json The decoded detail response.
  /// @return The entry to render.
  factory ContinueWatchingMedia.fromTmdb(String type, String id, Map json) {
    final isShow = type == progressTVShowsKey;
    final rawTitle = isShow ? json['name'] : json['title'];
    final rawPoster = json['poster_path'];
    return ContinueWatchingMedia(
      type: type,
      id: id,
      title: rawTitle is String && rawTitle.trim().isNotEmpty ? rawTitle : null,
      posterPath:
          rawPoster is String && rawPoster.isNotEmpty ? rawPoster : null,
      seasons: isShow
          ? seasonCountsFromTmdb(json['seasons'])
          : const <SeasonEpisodeCount>[],
    );
  }

  /// The stand-in for an id TMDB would not resolve.
  /// @param type `Movies` or `TVShows`, as stored in progress.
  /// @param id The TMDB id that failed to resolve.
  /// @return An entry that renders as a placeholder and opens nothing.
  factory ContinueWatchingMedia.missing(String type, String id) =>
      ContinueWatchingMedia(type: type, id: id, missing: true);

  final String type;
  final String id;

  /// Null when TMDB gave no usable name, which the caller replaces with a
  /// localized fallback — this file has no `BuildContext` to reach one from.
  final String? title;

  /// Null when there is no artwork, which the tile renders as the placeholder
  /// cover with the title written over it.
  final String? posterPath;

  /// Empty for movies and for shows whose payload carried no seasons.
  final List<SeasonEpisodeCount> seasons;

  /// Whether the lookup failed. A missing entry must not be tappable: opening
  /// a detail page for an id TMDB has never heard of is what leaves the user
  /// staring at an empty screen.
  final bool missing;

  bool get isShow => type == progressTVShowsKey;

  /// The map shape `getItemContainer` reads.
  ///
  /// It looks for `name` before `title` when there is no artwork, so only
  /// `title` is emitted and shows come through the same path as movies.
  /// @param unknownTitle The localized fallback for a title TMDB did not give.
  /// @return The item map to hand to `getItemContainer`.
  Map<String, dynamic> itemData(String unknownTitle) => <String, dynamic>{
        'id': id,
        'type': type,
        'title': title ?? unknownTitle,
        'poster_path': posterPath,
      };
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
