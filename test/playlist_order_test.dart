// Unit tests for the per-user playlist ordering in
// `lib/common/playlist_order.dart`.
//
// Playlists are shared documents, so the order lives in the user's own
// settings and has to survive playlists being created, joined and left without
// leaving holes or dropping anything.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/playlist_order.dart';

void main() {
  group('orderPlaylistIds', () {
    test('follows the stored order', () {
      expect(orderPlaylistIds(['a', 'b', 'c'], ['c', 'a', 'b']),
          ['c', 'a', 'b']);
    });

    test('keeps the incoming order when nothing is stored', () {
      expect(orderPlaylistIds(['a', 'b', 'c'], null), ['a', 'b', 'c']);
    });

    test('puts playlists added since the order was saved at the end', () {
      // A newly joined playlist should appear predictably rather than at some
      // arbitrary position in the middle.
      expect(orderPlaylistIds(['a', 'b', 'c'], ['c', 'a']), ['c', 'a', 'b']);
    });

    test('drops stored ids for playlists that no longer exist', () {
      // Leaving a playlist must not leave a hole in the order.
      expect(orderPlaylistIds(['a', 'b'], ['b', 'gone', 'a']), ['b', 'a']);
    });

    test('always excludes the generated recommendations list', () {
      expect(
        orderPlaylistIds(['a', kRecommendationsPlaylistId, 'b'], null),
        ['a', 'b'],
      );
    });

    test('excludes recommendations even when it is in the stored order', () {
      expect(
        orderPlaylistIds(
            ['a', kRecommendationsPlaylistId], [kRecommendationsPlaylistId, 'a']),
        ['a'],
      );
    });

    test('ignores a malformed stored order', () {
      expect(orderPlaylistIds(['a', 'b'], 'nonsense'), ['a', 'b']);
      expect(orderPlaylistIds(['a', 'b'], 42), ['a', 'b']);
    });

    test('never duplicates an id repeated in the stored order', () {
      expect(orderPlaylistIds(['a', 'b'], ['a', 'a', 'b']), ['a', 'b']);
    });

    test('handles an empty set of playlists', () {
      expect(orderPlaylistIds([], ['a']), isEmpty);
    });

    test('coerces stored entries to strings', () {
      expect(orderPlaylistIds(['1', '2'], [2, 1]), ['2', '1']);
    });
  });

  group('reorderPlaylistIds', () {
    test('moves an item downwards to the reported position', () {
      expect(reorderPlaylistIds(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    });

    test('moves an item upwards to the reported position', () {
      expect(reorderPlaylistIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('moves an item to the very end', () {
      expect(reorderPlaylistIds(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
    });

    test('never drops or duplicates an entry', () {
      final original = ['a', 'b', 'c', 'd'];
      for (int from = 0; from < original.length; from++) {
        for (int to = 0; to <= original.length; to++) {
          final result = reorderPlaylistIds(original, from, to);
          expect(result.length, original.length, reason: '$from -> $to');
          expect(result.toSet(), original.toSet(), reason: '$from -> $to');
        }
      }
    });

    test('does not modify the list it was given', () {
      final original = ['a', 'b', 'c'];
      reorderPlaylistIds(original, 0, 3);
      expect(original, ['a', 'b', 'c']);
    });

    test('ignores an out of range index', () {
      expect(reorderPlaylistIds(['a', 'b'], 9, 0), ['a', 'b']);
      expect(reorderPlaylistIds([], 0, 0), isEmpty);
    });
  });

  group('the home page selection', () {
    test('takes the first six of the arranged order', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
      final ordered = orderPlaylistIds(ids, ['g', 'f', 'e', 'd', 'c', 'b', 'a']);
      expect(ordered.take(6).toList(), ['g', 'f', 'e', 'd', 'c', 'b']);
    });
  });
}
