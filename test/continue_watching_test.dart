import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/continue_watching.dart';
import 'package:uractor/common/firebase/progress_service.dart';

void main() {
  WatchProgressListItem item(String id, String updated) =>
      WatchProgressListItem(
        type: progressMoviesKey,
        id: id,
        started: '2026-01-01',
        updated: updated,
      );

  group('continueWatchingEntries', () {
    test('keeps the order it was given', () {
      // inProgressItems() already sorts newest activity first. Re-sorting here
      // would make this the real ordering and quietly orphan the service's.
      final ordered = [
        item('c', '2026-03-01'),
        item('a', '2026-02-01'),
        item('b', '2026-01-01'),
      ];

      expect(
        continueWatchingEntries(ordered).map((entry) => entry.id),
        ['c', 'a', 'b'],
      );
    });

    test('caps the list at the limit', () {
      final many = List.generate(25, (index) => item('$index', '2026-01-01'));

      final kept = continueWatchingEntries(many);

      expect(kept, hasLength(kContinueWatchingLimit));
      expect(kept.first.id, '0');
      expect(kept.last.id, '${kContinueWatchingLimit - 1}');
    });

    test('honours an explicit limit', () {
      final many = List.generate(5, (index) => item('$index', '2026-01-01'));

      expect(continueWatchingEntries(many, limit: 2), hasLength(2));
      expect(continueWatchingEntries(many, limit: 99), hasLength(5));
    });

    test('returns nothing for an empty list or a limit of zero', () {
      expect(continueWatchingEntries(const []), isEmpty);
      expect(
        continueWatchingEntries([item('a', '2026-01-01')], limit: 0),
        isEmpty,
      );
      expect(
        continueWatchingEntries([item('a', '2026-01-01')], limit: -3),
        isEmpty,
      );
    });
  });

  group('seasonCountsFromTmdb', () {
    test('reads a TMDB seasons array', () {
      final seasons = seasonCountsFromTmdb([
        {'season_number': 1, 'episode_count': 10},
        {'season_number': 2, 'episode_count': 8},
      ]);

      expect(seasons.map((season) => season.seasonNumber), [1, 2]);
      expect(seasons.map((season) => season.episodeCount), [10, 8]);
    });

    test('keeps season zero and lets ProgressService skip it', () {
      final seasons = seasonCountsFromTmdb([
        {'season_number': 0, 'episode_count': 3},
        {'season_number': 1, 'episode_count': 2},
      ]);

      expect(seasons.map((season) => season.seasonNumber), [0, 1]);
    });

    test('accepts numbers TMDB sent as strings or doubles', () {
      final seasons = seasonCountsFromTmdb([
        {'season_number': '1', 'episode_count': '12'},
        {'season_number': 2.0, 'episode_count': 6.0},
      ]);

      expect(seasons.map((season) => season.seasonNumber), [1, 2]);
      expect(seasons.map((season) => season.episodeCount), [12, 6]);
    });

    test('drops a season with no usable number', () {
      final seasons = seasonCountsFromTmdb([
        {'episode_count': 4},
        {'season_number': null, 'episode_count': 4},
        {'season_number': 'special', 'episode_count': 4},
        {'season_number': -1, 'episode_count': 4},
        {'season_number': 3, 'episode_count': 4},
      ]);

      expect(seasons.map((season) => season.seasonNumber), [3]);
    });

    test('treats a missing or negative episode count as none', () {
      final seasons = seasonCountsFromTmdb([
        {'season_number': 1},
        {'season_number': 2, 'episode_count': -5},
      ]);

      expect(seasons.map((season) => season.episodeCount), [0, 0]);
    });

    test('returns nothing when the payload has no seasons', () {
      expect(seasonCountsFromTmdb(null), isEmpty);
      expect(seasonCountsFromTmdb('seasons'), isEmpty);
      expect(seasonCountsFromTmdb(const []), isEmpty);
      expect(seasonCountsFromTmdb([1, 'two', null]), isEmpty);
    });
  });

  group('ContinueWatchingMedia', () {
    test('reads a movie payload from title', () {
      final media = ContinueWatchingMedia.fromTmdb(progressMoviesKey, '27205', {
        'title': 'Inception',
        'poster_path': '/inception.jpg',
        'seasons': [
          {'season_number': 1, 'episode_count': 3},
        ],
      });

      expect(media.title, 'Inception');
      expect(media.posterPath, '/inception.jpg');
      expect(media.isShow, isFalse);
      expect(media.missing, isFalse);
      // A movie has no seasons even when the payload confusingly carries some.
      expect(media.seasons, isEmpty);
    });

    test('reads a show payload from name, with its seasons', () {
      final media = ContinueWatchingMedia.fromTmdb(progressTVShowsKey, '1399', {
        'name': 'Severance',
        'poster_path': '/severance.jpg',
        'seasons': [
          {'season_number': 1, 'episode_count': 9},
        ],
      });

      expect(media.title, 'Severance');
      expect(media.isShow, isTrue);
      expect(media.seasons.single.episodeCount, 9);
    });

    test('nulls a title or poster TMDB left blank', () {
      final media = ContinueWatchingMedia.fromTmdb(progressMoviesKey, '1', {
        'title': '   ',
        'poster_path': '',
      });

      expect(media.title, isNull);
      expect(media.posterPath, isNull);
    });

    test('marks an unresolved id as missing', () {
      final media = ContinueWatchingMedia.missing(progressMoviesKey, '404');

      expect(media.missing, isTrue);
      expect(media.title, isNull);
      expect(media.posterPath, isNull);
      expect(media.seasons, isEmpty);
    });

    test('falls back to the supplied title when TMDB gave none', () {
      final media = ContinueWatchingMedia.missing(progressTVShowsKey, '404');

      final data = media.itemData('Unknown');

      expect(data['title'], 'Unknown');
      expect(data['poster_path'], isNull);
      expect(data['id'], '404');
      expect(data['type'], progressTVShowsKey);
      // getItemContainer prefers "name" over "title", so a show must not carry
      // one or its placeholder cover would be captioned with the wrong field.
      expect(data.containsKey('name'), isFalse);
    });
  });
}
