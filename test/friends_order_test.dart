// Unit tests for the friend ordering helper in
// `lib/common/firebase/friends_service.dart`.
//
// The order of the friends array is the order friends appear in, both on the
// Friends tab and in the "seen with" pickers. ReorderableListView reports the
// drop index while the dragged item is still in the list, which is one further
// along than where it actually lands when dragging downwards, so the index
// adjustment is easy to get wrong in a way that silently misplaces friends.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/friends_service.dart';

void main() {
  group('FriendsService.reorder', () {
    test('moves an item downwards to the reported position', () {
      // Dragging "a" to sit after "b" reports newIndex 2, not 1.
      expect(FriendsService.reorder(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    });

    test('moves an item upwards to the reported position', () {
      expect(FriendsService.reorder(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('moves an item to the very end', () {
      expect(FriendsService.reorder(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
    });

    test('moves an item to the very start', () {
      expect(FriendsService.reorder(['a', 'b', 'c'], 1, 0), ['b', 'a', 'c']);
    });

    test('leaves the list unchanged when dropped where it started', () {
      expect(FriendsService.reorder(['a', 'b', 'c'], 1, 2), ['a', 'b', 'c']);
    });

    test('never drops or duplicates an entry', () {
      final original = ['a', 'b', 'c', 'd', 'e'];
      for (int from = 0; from < original.length; from++) {
        for (int to = 0; to <= original.length; to++) {
          final result = FriendsService.reorder(original, from, to);
          expect(result.length, original.length, reason: '$from -> $to');
          expect(result.toSet(), original.toSet(), reason: '$from -> $to');
        }
      }
    });

    test('does not modify the list it was given', () {
      final original = ['a', 'b', 'c'];
      FriendsService.reorder(original, 0, 3);
      expect(original, ['a', 'b', 'c']);
    });

    test('converts entries to strings', () {
      expect(FriendsService.reorder([1, 2], 0, 2), ['2', '1']);
    });

    test('ignores an out of range source index', () {
      expect(FriendsService.reorder(['a', 'b'], 5, 0), ['a', 'b']);
    });

    test('handles a single entry and an empty list', () {
      expect(FriendsService.reorder(['a'], 0, 1), ['a']);
      expect(FriendsService.reorder([], 0, 0), isEmpty);
    });
  });
}
