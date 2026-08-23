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

/// Where a part-watched show should be picked back up.
///
/// A bare nullable episode cannot tell "play this next" apart from "there is
/// nothing ahead of you", and a screen has to word those differently — so this
/// carries both.
class ResumePoint {
  /// There is an episode to play.
  const ResumePoint.at(WatchProgressEpisode this.episode) : caughtUp = false;

  /// Nothing follows the furthest episode ticked. Earlier gaps may remain, but
  /// none of them is the next episode from where the viewer actually is.
  const ResumePoint.caughtUp()
      : episode = null,
        caughtUp = true;

  /// Nothing is known about the show's episodes, so no claim can be made. This
  /// is what a title TMDB would not resolve, or one whose seasons all report no
  /// episodes, comes back as.
  const ResumePoint.unknown()
      : episode = null,
        caughtUp = false;

  /// The episode to play, or null when there is none to name.
  final WatchProgressEpisode? episode;

  /// Whether the viewer has reached the end of what has been released.
  final bool caughtUp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumePoint &&
          runtimeType == other.runtimeType &&
          episode == other.episode &&
          caughtUp == other.caughtUp;

  @override
  int get hashCode => Object.hash(episode, caughtUp);

  @override
  String toString() =>
      'ResumePoint(${episode ?? (caughtUp ? 'caught up' : 'unknown')})';
}

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
  /// and the result is ordered so [resumeFrom] walks the show in
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
  /// came before it, and recording only E5 leaves the record visibly wrong in
  /// ways they will meet later: the season guide draws S2 as one episode deep,
  /// the show never registers as complete, and the gap is theirs to go back and
  /// tick by hand. So the earlier seasons are filled in.
  ///
  /// It is not always right — a viewer who joined a long-running series partway
  /// never watched those seasons and does not want them claimed — which is why
  /// it is a setting and this is only half of the pair. [episodesWithin] is the
  /// other half.
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

  /// The episodes a log entry names, with nothing before them filled in.
  ///
  /// The counterpart to [episodesThrough], for a viewer who has turned the
  /// filling in off. [episode] is the single episode named, or null when the
  /// entry named a whole season — which is still recorded in full, because
  /// naming a season is a claim about all of it and not about its finale.
  ///
  /// A season TMDB has no count for still records the episode named, on the
  /// same reasoning as [episodesThrough]: the calendar accepts shows TMDB knows
  /// nothing about, and refusing to record those makes the entry a lie. It
  /// cannot record a whole season of unknown length, so that comes back empty.
  static Map<int, List<int>> episodesWithin({
    required List<SeasonEpisodeCount> seasons,
    required int season,
    int? episode,
  }) {
    if (season <= 0) return const <int, List<int>>{};
    final count = _episodeCountOf(seasons, season);
    if (episode == null) {
      if (count <= 0) return const <int, List<int>>{};
      return <int, List<int>>{season: _upTo(count)};
    }
    if (episode <= 0) return const <int, List<int>>{};
    // A season can shrink when TMDB corrects its data, so an episode number
    // past the end of the season is clamped rather than recorded as watched.
    final number = count > 0 && episode > count ? count : episode;
    return <int, List<int>>{
      season: <int>[number],
    };
  }

  /// The episode to resume a show at, given what has been ticked.
  ///
  /// Answers from where the viewer actually is — the episode after the furthest
  /// one ticked — rather than from the beginning of the show. Someone who joined
  /// a long-running series at its latest run has every earlier episode unticked,
  /// and being sent back to season 1 answers a question they did not ask.
  ///
  /// The gaps behind that point are deliberately left alone. Once the show runs
  /// out ahead there is no single next episode to name, only a backlog, and
  /// [ResumePoint.caughtUp] says that instead of picking one arbitrarily.
  ///
  /// Specials and seasons TMDB gives no episode count for are skipped, matching
  /// what the rest of the progress model counts. A ticked episode outside its
  /// season's range is ignored for the same reason [watchedInSeason] ignores it:
  /// a season can shrink, and a stale record must not name an episode that no
  /// longer exists.
  /// @param seasons TMDB's season list for the show, in any order.
  /// @param watched The ticked episodes, keyed by season number.
  /// @return Where to pick the show back up.
  static ResumePoint resumeFrom({
    required List<SeasonEpisodeCount> seasons,
    required Map<int, Iterable<int>> watched,
  }) {
    final ordered = seasons
        .where((season) => season.seasonNumber > 0 && season.episodeCount > 0)
        .toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    if (ordered.isEmpty) return const ResumePoint.unknown();

    // Walking backwards finds the furthest tick, and everything past it is
    // unwatched by construction — so the first one found settles the answer
    // and no second pass over the show is needed.
    for (var index = ordered.length - 1; index >= 0; index--) {
      final season = ordered[index];
      final ticked = watched[season.seasonNumber]?.toSet() ?? const <int>{};
      for (var episode = season.episodeCount; episode >= 1; episode--) {
        if (!ticked.contains(episode)) continue;
        if (episode < season.episodeCount) {
          return ResumePoint.at(
            WatchProgressEpisode(
              seasonNumber: season.seasonNumber,
              episodeNumber: episode + 1,
            ),
          );
        }
        if (index + 1 < ordered.length) {
          return ResumePoint.at(
            WatchProgressEpisode(
              seasonNumber: ordered[index + 1].seasonNumber,
              episodeNumber: 1,
            ),
          );
        }
        return const ResumePoint.caughtUp();
      }
    }

    // Nothing ticked anywhere, so the show has not been started and begins at
    // its first counted episode.
    return ResumePoint.at(
      WatchProgressEpisode(
        seasonNumber: ordered.first.seasonNumber,
        episodeNumber: 1,
      ),
    );
  }

  static int _episodeCountOf(List<SeasonEpisodeCount> seasons, int season) {
    for (final entry in seasons) {
      if (entry.seasonNumber == season) return entry.episodeCount;
    }
    return 0;
  }

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
