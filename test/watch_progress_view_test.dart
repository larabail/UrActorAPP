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
}
