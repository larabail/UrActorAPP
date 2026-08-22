import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/watching_together.dart';

WatchProgressListItem _item(
  String type,
  String id, {
  String started = '2026-01-01',
  String? updated,
}) =>
    WatchProgressListItem(
      type: type,
      id: id,
      started: started,
      updated: updated ?? started,
    );

Map<String, dynamic> _seenWith(Map<String, Map<String, List<String>>> byUid) =>
    <String, dynamic>{
      for (final entry in byUid.entries)
        entry.key: <String, dynamic>{
          'Movies': entry.value['Movies'] ?? const <String>[],
          'TVShows': entry.value['TVShows'] ?? const <String>[],
        },
    };

void main() {
  group('watchingTogetherShows', () {
    test('keeps a started show that is recorded as watched with a friend', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows, hasLength(1));
      expect(shows.single.id, '1399');
      expect(shows.single.friendUids, ['ana']);
    });

    test('drops a started show nobody was watching with the user', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['66732'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows, isEmpty);
    });

    test('drops movies even when they were watched together', () {
      // A film is watched in one sitting, so being part way through one with
      // someone is a state that lasts an evening and does not earn a row.
      final shows = watchingTogetherShows(
        [_item(progressMoviesKey, '27205')],
        _seenWith({
          'ana': {
            'Movies': ['27205'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows, isEmpty);
    });

    test('keeps the order it was given rather than re-sorting', () {
      // ProgressService already sorts by last activity, newest first. Sorting
      // again here would quietly become the real ordering.
      final shows = watchingTogetherShows(
        [
          _item(progressTVShowsKey, '3', updated: '2026-03-01'),
          _item(progressMoviesKey, '9', updated: '2026-02-01'),
          _item(progressTVShowsKey, '1', updated: '2026-01-01'),
        ],
        _seenWith({
          'ana': {
            'TVShows': ['1', '3'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows.map((show) => show.id), ['3', '1']);
      expect(shows.map((show) => show.updated), ['2026-03-01', '2026-01-01']);
    });

    test('names every friend a show is shared with, in friend order', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
          'luis': {
            'TVShows': ['1399'],
          },
        }),
        friends: ['luis', 'ana'],
      );

      // One tile, not one per friend: a household watching the same series
      // should not become three identical posters.
      expect(shows, hasLength(1));
      expect(shows.single.friendUids, ['luis', 'ana']);
    });

    test('names a friend once even if the stored order repeats them', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
        }),
        friends: ['ana', 'ana'],
      );

      expect(shows.single.friendUids, ['ana']);
    });

    test('ignores a uid that is no longer a friend', () {
      // Removing a friend does not rewrite the stored "seen with" data, so the
      // friend list is what decides who still counts.
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ex': {
            'TVShows': ['1399'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows, isEmpty);
    });

    test('scopes to the friends asked for, which is one on their profile', () {
      final shows = watchingTogetherShows(
        [
          _item(progressTVShowsKey, '1399'),
          _item(progressTVShowsKey, '66732'),
        ],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
          'luis': {
            'TVShows': ['66732'],
          },
        }),
        friends: ['ana'],
      );

      expect(shows.map((show) => show.id), ['1399']);
    });

    test('caps the list so a long backlog cannot storm TMDB', () {
      final shows = watchingTogetherShows(
        [
          for (var index = 0; index < 25; index++)
            _item(progressTVShowsKey, '$index'),
        ],
        _seenWith({
          'ana': {
            'TVShows': [for (var index = 0; index < 25; index++) '$index'],
          },
        }),
        friends: ['ana'],
        limit: 3,
      );

      expect(shows, hasLength(3));
      expect(shows.map((show) => show.id), ['0', '1', '2']);
    });

    test('a limit of zero draws nothing', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
        }),
        friends: ['ana'],
        limit: 0,
      );

      expect(shows, isEmpty);
    });

    test('no friends means nothing shared', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        _seenWith({
          'ana': {
            'TVShows': ['1399'],
          },
        }),
        friends: const <String>[],
      );

      expect(shows, isEmpty);
    });

    test('survives a stored entry that predates the TV shows key', () {
      // The map is assembled from a Firestore document written before this
      // feature existed, so a missing or wrongly typed key is a friend with
      // nothing shared rather than a crash on the friends page.
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        <String, dynamic>{
          'ana': <String, dynamic>{'Movies': <String>[]},
          'luis': <String, dynamic>{'TVShows': 'not a list'},
          'sam': 'not a map',
        },
        friends: ['ana', 'luis', 'sam'],
      );

      expect(shows, isEmpty);
    });

    test('reads ids stored as numbers rather than strings', () {
      final shows = watchingTogetherShows(
        [_item(progressTVShowsKey, '1399')],
        <String, dynamic>{
          'ana': <String, dynamic>{
            'TVShows': <dynamic>[1399],
          },
        },
        friends: ['ana'],
      );

      expect(shows.single.id, '1399');
    });
  });

  group('watchingTogetherNames', () {
    test('spells out every name when they fit', () {
      final names = watchingTogetherNames(['Ana', 'Luis']);

      expect(names.shown, ['Ana', 'Luis']);
      expect(names.othersCount, 0);
    });

    test('counts the rest once the line would outgrow the poster', () {
      final names = watchingTogetherNames(['Ana', 'Luis', 'Sam', 'Kim']);

      expect(names.shown, ['Ana', 'Luis']);
      expect(names.othersCount, 2);
    });

    test('drops blank names instead of leaving a gap in the line', () {
      final names = watchingTogetherNames(['Ana', '   ', '']);

      expect(names.shown, ['Ana']);
      expect(names.othersCount, 0);
    });

    test('trims names so a stray space does not offset the join', () {
      final names = watchingTogetherNames([' Ana ']);

      expect(names.shown, ['Ana']);
    });

    test('no names at all leaves nothing to say', () {
      final names = watchingTogetherNames(const <String>[]);

      expect(names.shown, isEmpty);
      expect(names.othersCount, 0);
    });
  });
}
