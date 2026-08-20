/// Tests for the optional season/episode a calendar entry may carry.
///
/// The point of nearly all of these is backwards compatibility: entries
/// written before this feature existed, and entries written by friends
/// running an older build, have to keep reading exactly as they did.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/calendar_episode.dart';

void main() {
  group('CalendarEpisode.fromEntry', () {
    test('reads a season and episode a show entry recorded', () {
      final episode = CalendarEpisode.fromEntry({
        'id': 't1',
        'title': 'Show',
        'type': 'series',
        'season': 2,
        'episode': 5,
      });

      expect(episode, equals(const CalendarEpisode(season: 2, episode: 5)));
      expect(episode!.hasEpisode, isTrue);
    });

    test('reads a season on its own', () {
      // Someone who watched a whole season in a sitting records the season and
      // nothing else, which has to stay a valid record rather than being
      // thrown away for lack of an episode.
      final episode = CalendarEpisode.fromEntry({'season': 3});

      expect(episode, equals(const CalendarEpisode(season: 3)));
      expect(episode!.hasEpisode, isFalse);
    });

    test('reads nothing from an entry that recorded nothing', () {
      // The shape every entry in the wild has today.
      expect(
        CalendarEpisode.fromEntry({
          'id': 'm1',
          'title': 'Movie',
          'runtime': 90,
          'rating': 7.5,
          'friends': <String>[],
          'type': 'movie',
        }),
        isNull,
      );
    });

    test('reads nothing from a null entry', () {
      expect(CalendarEpisode.fromEntry(null), isNull);
    });

    test('drops an episode recorded without a season', () {
      // "E5" of an unnamed season cannot be displayed usefully and is far
      // likelier to be corrupt than deliberate.
      expect(CalendarEpisode.fromEntry({'episode': 5}), isNull);
    });

    test('accepts numbers stored as strings', () {
      // Text fields hand back strings, and hand-repaired documents contain
      // them, so both have to read back as the number they mean.
      expect(
        CalendarEpisode.fromEntry({'season': '2', 'episode': ' 5 '}),
        equals(const CalendarEpisode(season: 2, episode: 5)),
      );
    });

    test('accepts whole numbers stored as doubles', () {
      // JSON round-trips turn small ints into doubles.
      expect(
        CalendarEpisode.fromEntry({'season': 2.0, 'episode': 5.0}),
        equals(const CalendarEpisode(season: 2, episode: 5)),
      );
    });

    test('discards a season of zero or less', () {
      // Season 0 is TMDB's specials bucket, which the watch progress model
      // already refuses to track.
      expect(CalendarEpisode.fromEntry({'season': 0, 'episode': 1}), isNull);
      expect(CalendarEpisode.fromEntry({'season': -1}), isNull);
    });

    test('keeps the season when only the episode is nonsense', () {
      // Losing the whole record because one field is junk would be worse than
      // showing the part that is readable.
      expect(
        CalendarEpisode.fromEntry({'season': 2, 'episode': 'pilot'}),
        equals(const CalendarEpisode(season: 2)),
      );
      expect(
        CalendarEpisode.fromEntry({'season': 2, 'episode': 0}),
        equals(const CalendarEpisode(season: 2)),
      );
    });

    test('discards a season that is not a number at all', () {
      expect(CalendarEpisode.fromEntry({'season': 'two'}), isNull);
      expect(CalendarEpisode.fromEntry({'season': <int>[2]}), isNull);
      expect(CalendarEpisode.fromEntry({'season': 2.5}), isNull);
    });
  });

  group('CalendarEpisode.parsePositiveInt', () {
    test('treats an empty or blank field as nothing recorded', () {
      // Both boxes are optional, so leaving one empty is not an error.
      expect(CalendarEpisode.parsePositiveInt(''), isNull);
      expect(CalendarEpisode.parsePositiveInt('   '), isNull);
      expect(CalendarEpisode.parsePositiveInt(null), isNull);
    });

    test('parses a typed number', () {
      expect(CalendarEpisode.parsePositiveInt('12'), equals(12));
    });

    test('rejects zero, negatives and non-numbers', () {
      expect(CalendarEpisode.parsePositiveInt('0'), isNull);
      expect(CalendarEpisode.parsePositiveInt('-3'), isNull);
      expect(CalendarEpisode.parsePositiveInt('3a'), isNull);
    });
  });

  group('CalendarEpisode.tracksEpisodes', () {
    test('is true for a show entry', () {
      expect(CalendarEpisode.tracksEpisodes({'type': 'series'}), isTrue);
    });

    test('is false for a movie entry', () {
      expect(CalendarEpisode.tracksEpisodes({'type': 'movie'}), isFalse);
    });

    test('is false for an entry with no type', () {
      // Entries predating the type field are read as movies everywhere else
      // in the app, so they are read as movies here too.
      expect(CalendarEpisode.tracksEpisodes({'id': 'm1'}), isFalse);
      expect(CalendarEpisode.tracksEpisodes(null), isFalse);
    });
  });

  group('CalendarEpisode.fieldsFor', () {
    test('adds nothing when no episode was recorded', () {
      // This is what keeps an untagged entry byte-identical to what earlier
      // clients wrote, so friends running an older build see no change.
      expect(CalendarEpisode.fieldsFor(null), isEmpty);
    });

    test('writes only the season when no episode was recorded', () {
      expect(
        CalendarEpisode.fieldsFor(const CalendarEpisode(season: 4)),
        equals({'season': 4}),
      );
    });

    test('writes both when both were recorded', () {
      expect(
        CalendarEpisode.fieldsFor(const CalendarEpisode(season: 4, episode: 2)),
        equals({'season': 4, 'episode': 2}),
      );
    });
  });

  group('CalendarEpisode.copyOnto', () {
    test('carries a show entry recording onto the fetched payload', () {
      final target = <String, dynamic>{'id': 1399, 'name': 'Thrones'};

      CalendarEpisode.copyOnto(
        {'type': 'series', 'season': 2, 'episode': 9},
        target,
      );

      expect(target['season'], equals(2));
      expect(target['episode'], equals(9));
    });

    test('leaves the payload alone for a movie entry', () {
      final target = <String, dynamic>{'id': 27205};

      CalendarEpisode.copyOnto(
        {'type': 'movie', 'season': 2, 'episode': 9},
        target,
      );

      expect(target, equals({'id': 27205}));
    });

    test('leaves the payload alone when nothing was recorded', () {
      final target = <String, dynamic>{'id': 1399};

      CalendarEpisode.copyOnto({'type': 'series'}, target);

      expect(target, equals({'id': 1399}));
    });
  });

  group('CalendarEpisode value semantics', () {
    test('compares by season and episode', () {
      expect(
        const CalendarEpisode(season: 1, episode: 2),
        equals(const CalendarEpisode(season: 1, episode: 2)),
      );
      expect(
        const CalendarEpisode(season: 1, episode: 2).hashCode,
        equals(const CalendarEpisode(season: 1, episode: 2).hashCode),
      );
      expect(
        const CalendarEpisode(season: 1, episode: 2),
        isNot(equals(const CalendarEpisode(season: 1))),
      );
    });

    test('describes itself for debugging', () {
      expect(const CalendarEpisode(season: 1, episode: 2).toString(), 'S1 E2');
      expect(const CalendarEpisode(season: 1).toString(), 'S1');
    });
  });
}
