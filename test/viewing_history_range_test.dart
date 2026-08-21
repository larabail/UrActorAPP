/// Tests for the viewing history date range.
///
/// The history disappeared entirely when a show moved out of Seen and into
/// progress, even though its dates come from the calendar and nothing had
/// touched them. These cover the replacement, and in particular the account
/// that has calendar entries and no progress document at all — which is every
/// account that existed before watch progress shipped, and which must keep
/// showing exactly what it showed before.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/viewing_history_range.dart';

/// A calendar date in the shape `ApiUtils.processSeenDates` returns.
List<dynamic> entry(String date, [List<String> friends = const []]) =>
    <dynamic>[date, friends];

void main() {
  group('rangeFor', () {
    test('is null when nothing has ever been recorded', () {
      expect(
        ViewingHistory.rangeFor(seenDates: const [], seen: false),
        isNull,
      );
    });

    test('is null for a title marked seen with no dates anywhere', () {
      expect(
        ViewingHistory.rangeFor(seenDates: const [], seen: true),
        isNull,
      );
    });

    test('is open for a show being watched', () {
      final range = ViewingHistory.rangeFor(
        seenDates: const [],
        seen: false,
        progressStarted: '2026-03-01',
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
      expect(range.end, isNull);
      expect(range.isOpen, isTrue);
    });

    test('closes on the recorded finish date', () {
      final range = ViewingHistory.rangeFor(
        seenDates: const [],
        seen: true,
        progressStarted: '2026-03-01',
        progressFinished: '2026-04-09',
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
      expect(range.end, DateTime.parse('2026-04-09'));
      expect(range.isOpen, isFalse);
    });

    test('starts at the earliest calendar entry, whatever order they arrive in',
        () {
      final range = ViewingHistory.rangeFor(
        seenDates: [
          entry('2026-04-09'),
          entry('2026-03-01'),
          entry('2026-03-20'),
        ],
        seen: false,
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
    });

    test('prefers whichever of the two starts is earlier', () {
      // Logging a day you watched it before you told the app you had started
      // is ordinary: the calendar is a log and can be filled in afterwards.
      final range = ViewingHistory.rangeFor(
        seenDates: [entry('2026-02-14')],
        seen: false,
        progressStarted: '2026-03-01',
      );

      expect(range!.start, DateTime.parse('2026-02-14'));
      expect(range.isOpen, isTrue);
    });

    test('stays open for a show in progress that has logged days', () {
      final range = ViewingHistory.rangeFor(
        seenDates: [entry('2026-03-01'), entry('2026-04-09')],
        seen: false,
        progressStarted: '2026-03-01',
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
      expect(range.end, isNull);
    });

    test('closes an account that has no progress document at all', () {
      // Seen, calendar entries, nothing under Progress: what every account
      // looked like before watch progress existed. There is no stored finish
      // date, and the last logged day is the only defensible answer.
      final range = ViewingHistory.rangeFor(
        seenDates: [entry('2024-11-02'), entry('2024-09-18')],
        seen: true,
      );

      expect(range!.start, DateTime.parse('2024-09-18'));
      expect(range.end, DateTime.parse('2024-11-02'));
      expect(range.isOpen, isFalse);
    });

    test('collapses a finish date that precedes the start', () {
      final range = ViewingHistory.rangeFor(
        seenDates: const [],
        seen: true,
        progressStarted: '2026-04-09',
        progressFinished: '2026-03-01',
      );

      expect(range!.start, DateTime.parse('2026-04-09'));
      expect(range.end, DateTime.parse('2026-04-09'));
    });

    test('drops entries it cannot read rather than throwing', () {
      // Calendar entries are written by several client versions and by
      // friends, so a malformed one has to be survivable on a screen the user
      // is already looking at.
      final range = ViewingHistory.rangeFor(
        seenDates: <dynamic>[
          entry('not a date'),
          <dynamic>[],
          null,
          42,
          entry('2026-03-01'),
        ],
        seen: false,
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
    });

    test('reads a bare date as well as a pair', () {
      final range = ViewingHistory.rangeFor(
        seenDates: <dynamic>['2026-03-01'],
        seen: false,
      );

      expect(range!.start, DateTime.parse('2026-03-01'));
    });

    test('compares by value', () {
      final one = ViewingHistoryRange(start: DateTime.parse('2026-03-01'));
      final same = ViewingHistoryRange(start: DateTime.parse('2026-03-01'));
      final closed = ViewingHistoryRange(
        start: DateTime.parse('2026-03-01'),
        end: DateTime.parse('2026-04-09'),
      );

      expect(one, same);
      expect(one.hashCode, same.hashCode);
      expect(one, isNot(closed));
      expect(one.toString(), contains('present'));
    });
  });

  group('hasAnything', () {
    test('is false for a title nobody has touched', () {
      expect(
        ViewingHistory.hasAnything(
          seenDates: const [],
          seen: false,
          hasProgress: false,
        ),
        isFalse,
      );
    });

    test('is true for logged days even when the title is not seen', () {
      // The regression: ticking one episode takes a show out of Seen, and the
      // history used to be drawn only for titles in Seen.
      expect(
        ViewingHistory.hasAnything(
          seenDates: [entry('2026-03-01')],
          seen: false,
          hasProgress: true,
        ),
        isTrue,
      );
    });

    test('is true for a seen title with no logged days', () {
      expect(
        ViewingHistory.hasAnything(
          seenDates: const [],
          seen: true,
          hasProgress: false,
        ),
        isTrue,
      );
    });

    test('is true for a title in progress with nothing logged', () {
      expect(
        ViewingHistory.hasAnything(
          seenDates: const [],
          seen: false,
          hasProgress: true,
        ),
        isTrue,
      );
    });
  });

  group('hasProgressEntry', () {
    test('finds an entry under its type', () {
      expect(
        ViewingHistory.hasProgressEntry(
          {
            'TVShows': {
              '1396': {'started': '2026-03-01'},
            },
          },
          'TVShows',
          '1396',
        ),
        isTrue,
      );
    });

    test('matches an id stored as a number', () {
      expect(
        ViewingHistory.hasProgressEntry(
          {
            'TVShows': {1396: <String, dynamic>{}},
          },
          'TVShows',
          '1396',
        ),
        isTrue,
      );
    });

    test('does not look in the other type', () {
      expect(
        ViewingHistory.hasProgressEntry(
          {
            'Movies': {'1396': <String, dynamic>{}},
          },
          'TVShows',
          '1396',
        ),
        isFalse,
      );
    });

    test('survives a document that has never been written', () {
      expect(
        ViewingHistory.hasProgressEntry(<String, dynamic>{}, 'TVShows', '1396'),
        isFalse,
      );
      expect(
        ViewingHistory.hasProgressEntry(
          {'TVShows': 'nonsense'},
          'TVShows',
          '1396',
        ),
        isFalse,
      );
    });
  });
}
