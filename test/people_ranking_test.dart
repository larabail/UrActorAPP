/// Tests for `rankOf`, which decides the "#3" a person page shows.
///
/// The scores themselves are computed on the server now
/// (`functions/people_scores.js`); this is only about reading the standing out
/// of the list the app already holds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/people_ranking.dart';

void main() {
  group('rankOf', () {
    // The shape `AppUser.favActors` holds: [score, id] pairs, highest first.
    final scores = [
      [30, '1'],
      [20, '2'],
      [10, '3'],
    ];

    test('places a person by the score the page just computed', () {
      expect(rankOf(scores, '2', 20), 2);
      expect(rankOf(scores, '1', 30), 1);
      expect(rankOf(scores, '3', 10), 3);
    });

    test('ranks someone the server has never stored', () {
      // Before this change a person only entered the list by being opened, so
      // the common case was someone who was not in it at all.
      expect(rankOf(scores, '99', 25), 2);
      expect(rankOf(scores, '99', 1), 4);
      expect(rankOf(scores, '99', 100), 1);
    });

    test('prefers the local score over a stale stored one', () {
      // A film marked seen since the last server run is in the local score and
      // not yet in the stored one, and the page must not tell the viewer that
      // it did not count.
      expect(rankOf(scores, '3', 25), 2);
    });

    test('does not let a stale entry push its own person down', () {
      // '1' is stored at 30 and now scores 40. Counting its own stored entry
      // as being ahead would report #2 for the top-ranked person.
      expect(rankOf(scores, '1', 40), 1);
    });

    test('gives tied people the same position', () {
      expect(rankOf(scores, '99', 20), 2);
    });

    test('ranks first against an empty list', () {
      expect(rankOf([], '1', 0), 1);
      expect(rankOf([], '1', 12), 1);
    });

    test('reads scores stored as something other than an int', () {
      // Firestore hands numbers back as int or double depending on how they
      // were written, and older documents are not consistent.
      final mixed = [
        [30.0, '1'],
        ['20', '2'],
      ];
      expect(rankOf(mixed, '99', 25), 2);
      expect(rankOf(mixed, '99', 35), 1);
    });

    test('ignores entries that are not a score and an id', () {
      final ragged = [
        [30, '1'],
        ['nonsense'],
        null,
        [20, '2'],
      ];
      expect(rankOf(ragged, '99', 25), 2);
    });

    test('matches an id stored as a number', () {
      final numericIds = [
        [30, 1],
        [20, 2],
      ];
      expect(rankOf(numericIds, '1', 40), 1);
    });
  });
}
