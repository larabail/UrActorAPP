// Unit tests for the search relevance helpers in `lib/common/api/apiutils.dart`.
//
// TMDB orders multi-search results by popularity alone, which buries an exact
// title match under better known but less relevant entries. These are pure
// functions over plain maps, so they need no Firebase or network access.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/apiutils.dart';

Map<String, dynamic> _result(String title, {double popularity = 0}) {
  return {'title': title, 'popularity': popularity};
}

List<String> _titles(List<dynamic> results) {
  return results.map((r) => (r as Map)['title'] as String).toList();
}

void main() {
  group('ApiUtils.relevanceScore', () {
    test('ranks an exact title match above a prefix match', () {
      expect(
        ApiUtils.relevanceScore(_result('Dune'), 'Dune'),
        greaterThan(ApiUtils.relevanceScore(_result('Dune: Part Two'), 'Dune')),
      );
    });

    test('ranks a prefix match above a mid-string match', () {
      expect(
        ApiUtils.relevanceScore(_result('Dune: Part Two'), 'Dune'),
        greaterThan(ApiUtils.relevanceScore(_result('Jodorowsky Dune'), 'Dune')),
      );
    });

    test('scores a title that does not match at all on popularity alone', () {
      final score = ApiUtils.relevanceScore(_result('Alien'), 'Dune');
      expect(score, lessThan(1000));
    });

    test('ignores case', () {
      expect(
        ApiUtils.relevanceScore(_result('DUNE'), 'dune'),
        ApiUtils.relevanceScore(_result('Dune'), 'Dune'),
      );
    });

    test('matches an accented title from an unaccented query', () {
      // The old search replaced every non-ASCII character with a dash, so
      // "Amelie" could never reach "Amélie".
      expect(
        ApiUtils.relevanceScore(_result('Amélie'), 'Amelie'),
        ApiUtils.relevanceScore(_result('Amelie'), 'Amelie'),
      );
    });

    test('matches a punctuated title from an unpunctuated query', () {
      expect(
        ApiUtils.relevanceScore(_result('WALL·E'), 'wall e'),
        greaterThanOrEqualTo(2000),
      );
    });

    test('falls back to the name field when there is no title', () {
      expect(
        ApiUtils.relevanceScore({'name': 'Dune', 'popularity': 0}, 'Dune'),
        greaterThanOrEqualTo(4000),
      );
    });

    test('never lets popularity outweigh a better title match', () {
      // An unpopular exact match must still beat a wildly popular loose one.
      final exact = ApiUtils.relevanceScore(_result('Dune'), 'Dune');
      final popular = ApiUtils.relevanceScore(
        _result('Jodorowsky Dune', popularity: 100000),
        'Dune',
      );
      expect(exact, greaterThan(popular));
    });

    test('handles a missing title and an empty query without throwing', () {
      expect(ApiUtils.relevanceScore({}, 'Dune'), 0);
      expect(ApiUtils.relevanceScore(_result('Dune'), ''), 0);
    });
  });

  group('ApiUtils.sortByRelevance', () {
    test('puts the exact match first regardless of incoming order', () {
      final results = [
        _result('Dune: Part Two', popularity: 500),
        _result('Jodorowsky Dune', popularity: 900),
        _result('Dune', popularity: 1),
      ];
      expect(_titles(ApiUtils.sortByRelevance(results, 'Dune')).first, 'Dune');
    });

    test('orders equally matching titles by popularity', () {
      final results = [
        _result('Dune', popularity: 1),
        _result('Dune', popularity: 100),
      ];
      final sorted = ApiUtils.sortByRelevance(results, 'Dune');
      expect((sorted.first as Map)['popularity'], 100);
    });

    test('is stable for results that score identically', () {
      final results = [
        _result('Alien', popularity: 5),
        _result('Aliens', popularity: 5),
      ];
      // Neither matches, and popularity ties, so the original order must hold.
      expect(_titles(ApiUtils.sortByRelevance(results, 'Dune')),
          ['Alien', 'Aliens']);
    });

    test('does not modify the list it was given', () {
      final results = [
        _result('Dune: Part Two'),
        _result('Dune'),
      ];
      ApiUtils.sortByRelevance(results, 'Dune');
      expect(_titles(results), ['Dune: Part Two', 'Dune']);
    });

    test('returns an empty list unchanged', () {
      expect(ApiUtils.sortByRelevance([], 'Dune'), isEmpty);
    });

    test('tolerates entries that are not maps', () {
      expect(ApiUtils.sortByRelevance(['nonsense'], 'Dune').length, 1);
    });
  });
}
