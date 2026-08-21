/// Pure reasoning about watch progress, kept free of Firestore and widgets so
/// the rules can be tested without a network call or a pumped frame.
///
/// `ProgressService` owns the storage and the transitions; everything here only
/// answers questions a screen needs before it draws: which seasons may be
/// ticked, how full a season is, and which actions a title currently offers.
library;

import 'firebase/progress_service.dart';

/// How much of a season the user has ticked off.
enum SeasonTickState { none, partial, all }

/// The progress transitions a title offers right now.
class WatchProgressActions {
  const WatchProgressActions({
    required this.canStart,
    required this.canFinish,
    required this.canReopen,
  });

  final bool canStart;
  final bool canFinish;
  final bool canReopen;

  /// True when the state is terminal and the control is informational only,
  /// which is the case for a finished movie.
  bool get isEmpty => !canStart && !canFinish && !canReopen;
}

class WatchProgressView {
  /// Season 0 is TMDB's bucket for specials. `ProgressService` silently ignores
  /// it, so offering a tick for it would leave the user pressing a control that
  /// never changes anything.
  static bool isTickableSeason(int seasonNumber) => seasonNumber > 0;

  /// Only shows can be reopened. `ProgressService.reopenMovie` throws, so a
  /// finished movie must never be offered the action.
  static bool isReopenable(String type) => type == progressTVShowsKey;

  /// Turns the raw `seasons` array of a TMDB show payload into the metadata
  /// `ProgressService` needs to decide when a show is complete.
  ///
  /// Entries without a usable season number are dropped rather than guessed at,
  /// and the result is ordered so `nextUnwatchedEpisode` walks the show in
  /// broadcast order regardless of how TMDB happened to sort the payload.
  static List<SeasonEpisodeCount> seasonCounts(Iterable<dynamic>? rawSeasons) {
    if (rawSeasons == null) return const <SeasonEpisodeCount>[];
    final counts = <SeasonEpisodeCount>[];
    final seen = <int>{};
    for (final raw in rawSeasons) {
      if (raw is! Map) continue;
      final seasonNumber = _asInt(raw['season_number']);
      if (seasonNumber == null || !seen.add(seasonNumber)) continue;
      counts.add(
        SeasonEpisodeCount(
          seasonNumber: seasonNumber,
          episodeCount: _asInt(raw['episode_count']) ?? 0,
        ),
      );
    }
    counts.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return counts;
  }

  /// How many of a season's episodes are ticked.
  ///
  /// Episode numbers outside `1..episodeCount` are ignored: a season can shrink
  /// when TMDB corrects its data, and a stale record would otherwise report
  /// more watched episodes than the season has.
  static int watchedInSeason({
    required int episodeCount,
    required Iterable<int> watched,
  }) {
    if (episodeCount <= 0) return 0;
    return watched
        .where((episode) => episode >= 1 && episode <= episodeCount)
        .toSet()
        .length;
  }

  /// Every episode up to and including season [season] episode [episode].
  ///
  /// Someone who says they finished S2E5 today has almost always watched what
  /// came before it, and recording only E5 is worse in a way they see at once:
  /// the next unwatched episode stays S1E1 and Continue watching points at
  /// something they finished months ago. So the earlier seasons are filled in.
  ///
  /// The result is a set to add, never one to replace with — a later season
  /// already ticked is not mentioned here and so cannot be undone by applying
  /// it. Specials are skipped, because `ProgressService` does not track them.
  ///
  /// A season TMDB has no count for is still ticked through [episode]. The
  /// calendar deliberately accepts shows TMDB knows nothing about, and
  /// refusing to record those would make the entry a lie rather than an
  /// approximation.
  static Map<int, List<int>> episodesThrough({
    required List<SeasonEpisodeCount> seasons,
    required int season,
    required int episode,
  }) {
    if (season <= 0 || episode <= 0) return const <int, List<int>>{};
    final through = <int, List<int>>{};
    var targetCount = 0;
    for (final entry in seasons) {
      if (entry.seasonNumber <= 0) continue;
      if (entry.seasonNumber == season) {
        targetCount = entry.episodeCount;
        continue;
      }
      if (entry.seasonNumber > season || entry.episodeCount <= 0) continue;
      through[entry.seasonNumber] = _upTo(entry.episodeCount);
    }
    // A season can shrink when TMDB corrects its data, so an episode number
    // past the end of the season is clamped rather than recorded as watched.
    final count =
        targetCount > 0 && episode > targetCount ? targetCount : episode;
    through[season] = _upTo(count);
    return through;
  }

  static List<int> _upTo(int count) =>
      List<int>.generate(count, (index) => index + 1);

  static SeasonTickState seasonTickState({
    required int episodeCount,
    required Iterable<int> watched,
  }) {
    // A season with no episodes yet is not vacuously complete; drawing it as
    // watched would claim progress the user never made.
    if (episodeCount <= 0) return SeasonTickState.none;
    final count = watchedInSeason(
      episodeCount: episodeCount,
      watched: watched,
    );
    if (count == 0) return SeasonTickState.none;
    if (count >= episodeCount) return SeasonTickState.all;
    return SeasonTickState.partial;
  }

  /// The actions a detail screen should offer for [state].
  ///
  /// Deliberately narrow: each state offers the single move that follows from
  /// it. "Mark as finished" is not offered for a title that was never started,
  /// because the seen control beside it already does exactly that and two
  /// controls doing one job is how a user ends up with contradictory records.
  static WatchProgressActions actionsFor(
    WatchProgressState state, {
    required bool reopenable,
  }) {
    switch (state) {
      case WatchProgressState.notStarted:
        return const WatchProgressActions(
          canStart: true,
          canFinish: false,
          canReopen: false,
        );
      case WatchProgressState.inProgress:
        return const WatchProgressActions(
          canStart: false,
          canFinish: true,
          canReopen: false,
        );
      case WatchProgressState.finished:
        return WatchProgressActions(
          canStart: false,
          canFinish: false,
          canReopen: reopenable,
        );
    }
  }

  /// [actionsFor] for a `ProgressService` type key.
  static WatchProgressActions actionsForType(
    WatchProgressState state,
    String type,
  ) =>
      actionsFor(state, reopenable: isReopenable(type));

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
