/// Carries a calendar entry's meaning into the watch progress record.
///
/// `CalendarProgress` decides what an entry means and `ProgressService` stores
/// it; this is the seam between them, and the only place that reads the
/// current state in order to make that decision. It is deliberately thin: the
/// bookkeeping for marking something seen stays with the dialogues, which also
/// have to keep the in-memory lists on `currentUser` in step.
library;

import '../calendar_episode.dart';
import '../calendar_progress.dart';
import '../watch_progress_view.dart';
import 'progress_service.dart';

class CalendarProgressService {
  /// Applies [episode] to the logging user's progress and reports what the
  /// entry means, so the caller knows whether it still has to mark the title
  /// seen and whether tagged friends should be marked seen too.
  ///
  /// [type] is the calendar entry's own type — `movie` for a film, anything
  /// else for a show. [seasons] is TMDB's season list for the title, used to
  /// fill in the episodes before the one named; an empty list still records
  /// the show as in progress, since the calendar accepts shows TMDB has no
  /// metadata for and refusing to log those would be worse than logging them
  /// approximately.
  static Future<CalendarProgressIntent> apply({
    required String type,
    required String id,
    required CalendarEpisode? episode,
    required List<SeasonEpisodeCount> seasons,
    DateTime? date,
  }) async {
    final progressType =
        type == calendarMovieType ? progressMoviesKey : progressTVShowsKey;
    final state = await ProgressService.stateFor(progressType, id);
    final intent = CalendarProgress.intentFor(
      type: type,
      episode: episode,
      alreadyFinished: state == WatchProgressState.finished,
    );

    if (intent.action != CalendarProgressAction.markWatchedThrough) {
      return intent;
    }

    final season = intent.season!;
    // An entry naming only a season means the whole season, which needs
    // TMDB's episode count. Without one there is nothing defensible to tick,
    // so the show is recorded as in progress and left at that rather than
    // guessing at a length.
    final through = intent.episode ?? _episodeCountOf(seasons, season);
    await ProgressService.markEpisodesWatched(
      id,
      through <= 0
          ? const <int, List<int>>{}
          : WatchProgressView.episodesThrough(
              seasons: seasons,
              season: season,
              episode: through,
            ),
      seasons,
      date: date,
      keepFinished: intent.keepsFinished,
    );
    return intent;
  }

  static int _episodeCountOf(List<SeasonEpisodeCount> seasons, int season) {
    for (final entry in seasons) {
      if (entry.seasonNumber == season) return entry.episodeCount;
    }
    return 0;
  }
}
