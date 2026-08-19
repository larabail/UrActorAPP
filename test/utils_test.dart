import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/utils.dart';

void main() {
  group('Utils.containsMap', () {
    test('finds a map with identical keys and values', () {
      expect(
        Utils.containsMap([
          {'id': 1, 'type': 'Movies'}
        ], {
          'id': 1,
          'type': 'Movies'
        }),
        isTrue,
      );
    });

    test('rejects a map whose values differ', () {
      expect(
        Utils.containsMap([
          {'id': 1}
        ], {
          'id': 2
        }),
        isFalse,
      );
    });

    test('returns false for an empty list', () {
      expect(Utils.containsMap([], {'id': 1}), isFalse);
    });

    test('is sensitive to key order, because it compares encoded JSON', () {
      // Documents current behaviour rather than endorsing it: the same pair of
      // entries in a different insertion order encodes to a different string.
      expect(
        Utils.containsMap([
          {'a': 1, 'b': 2}
        ], {
          'b': 2,
          'a': 1
        }),
        isFalse,
      );
    });
  });

  group('Utils.contains', () {
    test('matches on id and the requested type', () {
      expect(
        Utils.contains([
          ['Movies', 42]
        ], [
          'Movies',
          42
        ], 'Movies'),
        isTrue,
      );
    });

    test('rejects an entry stored under a different type', () {
      expect(
        Utils.contains([
          ['Movies', 42]
        ], [
          'Movies',
          42
        ], 'TVShows'),
        isFalse,
      );
    });

    test('compares ids as strings, so 42 and "42" match', () {
      expect(
        Utils.contains([
          ['Movies', '42']
        ], [
          'Movies',
          42
        ], 'Movies'),
        isTrue,
      );
    });
  });

  group('Utils.contains_non_type', () {
    test('matches when both the type and the id agree', () {
      expect(
        Utils.contains_non_type([
          ['TVShows', 7]
        ], [
          'TVShows',
          7
        ]),
        isTrue,
      );
    });

    test('rejects a matching id under a different type', () {
      expect(
        Utils.contains_non_type([
          ['Movies', 7]
        ], [
          'TVShows',
          7
        ]),
        isFalse,
      );
    });
  });

  group('Utils.containsList', () {
    test('matches a movie entry by id', () {
      expect(
        Utils.containsList([
          ['Movies', 42]
        ], [
          'Movies',
          42
        ]),
        isTrue,
      );
    });

    test('never matches a TV entry, because the type is hardcoded to Movies',
        () {
      // Documents current behaviour: containsList ignores the type of the
      // needle and only ever matches entries stored as "Movies".
      expect(
        Utils.containsList([
          ['TVShows', 42]
        ], [
          'TVShows',
          42
        ]),
        isFalse,
      );
    });
  });
}
