import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/watch_progress_view.dart';

void main() {
  group('seasonCounts', () {
    test('reads season numbers and episode counts from a TMDB payload', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': 1, 'episode_count': 10, 'name': 'Season 1'},
        {'season_number': 2, 'episode_count': 8, 'name': 'Season 2'},
      ]);

      expect(counts.map((season) => season.seasonNumber), [1, 2]);
      expect(counts.map((season) => season.episodeCount), [10, 8]);
    });

    test('keeps specials so the service can decide what to ignore', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': 1, 'episode_count': 4},
        {'season_number': 0, 'episode_count': 3},
      ]);

      expect(counts.map((season) => season.seasonNumber), [0, 1]);
    });

    test('orders seasons by number regardless of payload order', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': 3, 'episode_count': 1},
        {'season_number': 1, 'episode_count': 1},
        {'season_number': 2, 'episode_count': 1},
      ]);

      expect(counts.map((season) => season.seasonNumber), [1, 2, 3]);
    });

    test('accepts numbers that arrive as strings', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': '2', 'episode_count': '6'},
      ]);

      expect(counts.single.seasonNumber, 2);
      expect(counts.single.episodeCount, 6);
    });

    test('drops entries with no usable season number', () {
      final counts = WatchProgressView.seasonCounts([
        {'episode_count': 6},
        {'season_number': null, 'episode_count': 6},
        'not a season',
        {'season_number': 1, 'episode_count': 6},
      ]);

      expect(counts.map((season) => season.seasonNumber), [1]);
    });

    test('defaults a missing episode count to zero rather than guessing', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': 1},
      ]);

      expect(counts.single.episodeCount, 0);
    });

    test('keeps the first entry when a season number repeats', () {
      final counts = WatchProgressView.seasonCounts([
        {'season_number': 1, 'episode_count': 10},
        {'season_number': 1, 'episode_count': 99},
      ]);

      expect(counts.single.episodeCount, 10);
    });

    test('returns nothing for a missing seasons array', () {
      expect(WatchProgressView.seasonCounts(null), isEmpty);
      expect(WatchProgressView.seasonCounts(const []), isEmpty);
    });
  });

  group('tickable seasons', () {
    test('excludes season 0 because the service ignores specials', () {
      expect(WatchProgressView.isTickableSeason(0), isFalse);
      expect(WatchProgressView.isTickableSeason(1), isTrue);
    });

    test('excludes a negative season number', () {
      expect(WatchProgressView.isTickableSeason(-1), isFalse);
    });
  });

  group('watchedInSeason', () {
    test('counts only episodes inside the season', () {
      expect(
        WatchProgressView.watchedInSeason(
          episodeCount: 3,
          watched: const [1, 2],
        ),
        2,
      );
    });

    test('ignores episodes beyond the season length', () {
      // TMDB corrects episode counts downwards, and a record kept from the
      // longer version must not report more watched than the season now has.
      expect(
        WatchProgressView.watchedInSeason(
          episodeCount: 2,
          watched: const [1, 2, 3, 4],
        ),
        2,
      );
    });

    test('ignores episode numbers below one', () {
      expect(
        WatchProgressView.watchedInSeason(
          episodeCount: 3,
          watched: const [0, -1, 1],
        ),
        1,
      );
    });

    test('counts a repeated episode once', () {
      expect(
        WatchProgressView.watchedInSeason(
          episodeCount: 3,
          watched: const [1, 1, 2],
        ),
        2,
      );
    });

    test('reports nothing for a season with no episodes', () {
      expect(
        WatchProgressView.watchedInSeason(
          episodeCount: 0,
          watched: const [1],
        ),
        0,
      );
    });
  });

  group('seasonTickState', () {
    test('reports none when nothing is watched', () {
      expect(
        WatchProgressView.seasonTickState(
          episodeCount: 3,
          watched: const [],
        ),
        SeasonTickState.none,
      );
    });

    test('reports partial part way through', () {
      expect(
        WatchProgressView.seasonTickState(
          episodeCount: 3,
          watched: const [1, 2],
        ),
        SeasonTickState.partial,
      );
    });

    test('reports all once every episode is watched', () {
      expect(
        WatchProgressView.seasonTickState(
          episodeCount: 3,
          watched: const [1, 2, 3],
        ),
        SeasonTickState.all,
      );
    });

    test('does not treat an unaired season as complete', () {
      expect(
        WatchProgressView.seasonTickState(
          episodeCount: 0,
          watched: const [],
        ),
        SeasonTickState.none,
      );
    });
  });

  group('available actions', () {
    test('offers only start before anything is recorded', () {
      final actions = WatchProgressView.actionsForType(
        WatchProgressState.notStarted,
        progressMoviesKey,
      );

      expect(actions.canStart, isTrue);
      expect(actions.canFinish, isFalse);
      expect(actions.canReopen, isFalse);
    });

    test('offers only finish while watching', () {
      final actions = WatchProgressView.actionsForType(
        WatchProgressState.inProgress,
        progressTVShowsKey,
      );

      expect(actions.canStart, isFalse);
      expect(actions.canFinish, isTrue);
      expect(actions.canReopen, isFalse);
    });

    test('offers reopen for a finished show', () {
      final actions = WatchProgressView.actionsForType(
        WatchProgressState.finished,
        progressTVShowsKey,
      );

      expect(actions.canReopen, isTrue);
      expect(actions.isEmpty, isFalse);
    });

    test('offers nothing for a finished movie', () {
      // ProgressService.reopenMovie throws, so a reopen offered here would be
      // a control that can only fail.
      final actions = WatchProgressView.actionsForType(
        WatchProgressState.finished,
        progressMoviesKey,
      );

      expect(actions.canStart, isFalse);
      expect(actions.canFinish, isFalse);
      expect(actions.canReopen, isFalse);
      expect(actions.isEmpty, isTrue);
    });

    test('only shows are reopenable', () {
      expect(WatchProgressView.isReopenable(progressTVShowsKey), isTrue);
      expect(WatchProgressView.isReopenable(progressMoviesKey), isFalse);
    });
  });

  group('episodesThrough', () {
    const seasons = [
      SeasonEpisodeCount(seasonNumber: 0, episodeCount: 3),
      SeasonEpisodeCount(seasonNumber: 1, episodeCount: 4),
      SeasonEpisodeCount(seasonNumber: 2, episodeCount: 6),
      SeasonEpisodeCount(seasonNumber: 3, episodeCount: 5),
    ];

    test('fills earlier seasons and truncates the one named', () {
      // "I finished S2E5 today" almost always means the earlier episodes are
      // watched too, and recording only E5 leaves the next unwatched episode
      // at S1E1.
      final through = WatchProgressView.episodesThrough(
        seasons: seasons,
        season: 2,
        episode: 5,
      );

      expect(through[1], [1, 2, 3, 4]);
      expect(through[2], [1, 2, 3, 4, 5]);
    });

    test('leaves later seasons out entirely, so applying it cannot undo one',
        () {
      final through = WatchProgressView.episodesThrough(
        seasons: seasons,
        season: 2,
        episode: 5,
      );

      expect(through.containsKey(3), isFalse);
    });

    test('skips specials', () {
      final through = WatchProgressView.episodesThrough(
        seasons: seasons,
        season: 2,
        episode: 1,
      );

      expect(through.containsKey(0), isFalse);
    });

    test('clamps an episode past the end of its season', () {
      // TMDB corrects season lengths, so a stale record must not claim more
      // episodes than the season has.
      final through = WatchProgressView.episodesThrough(
        seasons: seasons,
        season: 1,
        episode: 99,
      );

      expect(through[1], [1, 2, 3, 4]);
    });

    test('records a season TMDB has no count for', () {
      // The calendar deliberately accepts shows TMDB knows nothing about.
      final through = WatchProgressView.episodesThrough(
        seasons: seasons,
        season: 9,
        episode: 3,
      );

      expect(through[9], [1, 2, 3]);
      expect(through[1], [1, 2, 3, 4]);
    });

    test('records the first episode of a show with no metadata at all', () {
      final through = WatchProgressView.episodesThrough(
        seasons: const [],
        season: 1,
        episode: 1,
      );

      expect(through, {
        1: [1],
      });
    });

    test('skips a known season that has no episodes yet', () {
      final through = WatchProgressView.episodesThrough(
        seasons: const [
          SeasonEpisodeCount(seasonNumber: 1, episodeCount: 0),
          SeasonEpisodeCount(seasonNumber: 2, episodeCount: 3),
        ],
        season: 2,
        episode: 2,
      );

      expect(through.containsKey(1), isFalse);
      expect(through[2], [1, 2]);
    });

    test('records nothing for a nonsensical pointer', () {
      expect(
        WatchProgressView.episodesThrough(
          seasons: seasons,
          season: 0,
          episode: 1,
        ),
        isEmpty,
      );
      expect(
        WatchProgressView.episodesThrough(
          seasons: seasons,
          season: 1,
          episode: 0,
        ),
        isEmpty,
      );
    });
  });
}
