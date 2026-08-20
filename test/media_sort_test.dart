// Unit tests for the media grid ordering in `lib/common/media_sort.dart`.
//
// The Seen, Watchlist and Favorites grids store only `[type, id]` pairs, so
// every field except insertion order is supplied separately. The ordering
// itself is pure, so it needs no network or Firebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/media_sort.dart';

List<dynamic> _items(List<String> ids) {
  return [for (final id in ids) ['Movies', id]];
}

List<String> _ids(List<dynamic> items) {
  return [for (final item in items) (item as List)[1] as String];
}

void main() {
  group('MediaSort.fromStorage', () {
    test('round trips through its stored value', () {
      const sort = MediaSort(MediaSortKey.title, descending: false);
      expect(MediaSort.fromStorage(sort.storageValue), sort);
    });

    test('falls back to the default for an unset value', () {
      expect(MediaSort.fromStorage(null), MediaSort.defaultSort);
    });

    test('falls back to the default for an unrecognised key', () {
      // A key removed in a later version must not break the screen for a user
      // who still has it stored.
      expect(MediaSort.fromStorage('somethingElse:desc'), MediaSort.defaultSort);
    });

    test('falls back to the default for a malformed value', () {
      expect(MediaSort.fromStorage('title'), MediaSort.defaultSort);
      expect(MediaSort.fromStorage(42), MediaSort.defaultSort);
    });
  });

  group('MediaSort metadata requirements', () {
    test('date added needs no lookups', () {
      expect(const MediaSort(MediaSortKey.added).needsMetadata, isFalse);
    });

    test('every other field needs lookups', () {
      for (final key in MediaSortKey.values.where((k) => k != MediaSortKey.added)) {
        expect(MediaSort(key).needsMetadata, isTrue, reason: key.name);
      }
    });

    test('only the IMDb rating needs the extra OMDB request', () {
      expect(const MediaSort(MediaSortKey.imdbRating).needsImdbRating, isTrue);
      expect(const MediaSort(MediaSortKey.title).needsImdbRating, isFalse);
    });
  });

  group('sortMediaItems by date added', () {
    test('shows newest first when descending, matching the old behaviour', () {
      final items = _items(['1', '2', '3']);
      final sorted = sortMediaItems(items, const MediaSort(MediaSortKey.added), {});
      expect(_ids(sorted), ['3', '2', '1']);
    });

    test('shows oldest first when ascending', () {
      final items = _items(['1', '2', '3']);
      final sorted = sortMediaItems(
          items, const MediaSort(MediaSortKey.added, descending: false), {});
      expect(_ids(sorted), ['1', '2', '3']);
    });

    test('needs no metadata at all', () {
      expect(_ids(sortMediaItems(_items(['1']), const MediaSort(MediaSortKey.added), {})),
          ['1']);
    });
  });

  group('sortMediaItems by title', () {
    final metadata = {
      'Movies:1': const MediaSortMetadata(title: 'Zodiac'),
      'Movies:2': const MediaSortMetadata(title: 'Amelie'),
      'Movies:3': const MediaSortMetadata(title: 'Memento'),
    };

    test('orders A to Z when ascending', () {
      final sorted = sortMediaItems(_items(['1', '2', '3']),
          const MediaSort(MediaSortKey.title, descending: false), metadata);
      expect(_ids(sorted), ['2', '3', '1']);
    });

    test('orders Z to A when descending', () {
      final sorted = sortMediaItems(_items(['1', '2', '3']),
          const MediaSort(MediaSortKey.title), metadata);
      expect(_ids(sorted), ['1', '3', '2']);
    });

    test('ignores case', () {
      final mixed = {
        'Movies:1': const MediaSortMetadata(title: 'apple'),
        'Movies:2': const MediaSortMetadata(title: 'Banana'),
      };
      final sorted = sortMediaItems(_items(['2', '1']),
          const MediaSort(MediaSortKey.title, descending: false), mixed);
      expect(_ids(sorted), ['1', '2']);
    });
  });

  group('sortMediaItems by release date', () {
    final metadata = {
      'Movies:1': MediaSortMetadata(releaseDate: DateTime(1999)),
      'Movies:2': MediaSortMetadata(releaseDate: DateTime(2021)),
      'Movies:3': MediaSortMetadata(releaseDate: DateTime(2010)),
    };

    test('orders newest first when descending', () {
      final sorted = sortMediaItems(
          _items(['1', '2', '3']), const MediaSort(MediaSortKey.releaseDate), metadata);
      expect(_ids(sorted), ['2', '3', '1']);
    });

    test('orders oldest first when ascending', () {
      final sorted = sortMediaItems(_items(['1', '2', '3']),
          const MediaSort(MediaSortKey.releaseDate, descending: false), metadata);
      expect(_ids(sorted), ['1', '3', '2']);
    });
  });

  group('sortMediaItems by rating', () {
    test('orders by my rating, highest first', () {
      final metadata = {
        'Movies:1': const MediaSortMetadata(myRating: 3),
        'Movies:2': const MediaSortMetadata(myRating: 9),
      };
      final sorted = sortMediaItems(
          _items(['1', '2']), const MediaSort(MediaSortKey.myRating), metadata);
      expect(_ids(sorted), ['2', '1']);
    });

    test('orders by IMDb rating, highest first', () {
      final metadata = {
        'Movies:1': const MediaSortMetadata(imdbRating: 7.1),
        'Movies:2': const MediaSortMetadata(imdbRating: 8.9),
      };
      final sorted = sortMediaItems(
          _items(['1', '2']), const MediaSort(MediaSortKey.imdbRating), metadata);
      expect(_ids(sorted), ['2', '1']);
    });
  });

  group('sortMediaItems with missing data', () {
    test('sinks items with no metadata when descending', () {
      final metadata = {
        'Movies:2': const MediaSortMetadata(title: 'Amelie'),
      };
      final sorted = sortMediaItems(
          _items(['1', '2']), const MediaSort(MediaSortKey.title), metadata);
      expect(_ids(sorted), ['2', '1']);
    });

    test('sinks items with no metadata when ascending too', () {
      // Missing data must not masquerade as an empty title that sorts first.
      final metadata = {
        'Movies:2': const MediaSortMetadata(title: 'Amelie'),
      };
      final sorted = sortMediaItems(_items(['1', '2']),
          const MediaSort(MediaSortKey.title, descending: false), metadata);
      expect(_ids(sorted), ['2', '1']);
    });

    test('sinks an item whose title is present but blank', () {
      final metadata = {
        'Movies:1': const MediaSortMetadata(title: '   '),
        'Movies:2': const MediaSortMetadata(title: 'Amelie'),
      };
      final sorted = sortMediaItems(_items(['1', '2']),
          const MediaSort(MediaSortKey.title, descending: false), metadata);
      expect(_ids(sorted), ['2', '1']);
    });

    test('keeps the original order among items that are all missing data', () {
      final sorted = sortMediaItems(
          _items(['1', '2', '3']), const MediaSort(MediaSortKey.title), {});
      expect(_ids(sorted), ['1', '2', '3']);
    });
  });

  group('sortMediaItems general behaviour', () {
    test('is stable for equal values', () {
      final metadata = {
        'Movies:1': const MediaSortMetadata(myRating: 5),
        'Movies:2': const MediaSortMetadata(myRating: 5),
        'Movies:3': const MediaSortMetadata(myRating: 5),
      };
      final sorted = sortMediaItems(
          _items(['1', '2', '3']), const MediaSort(MediaSortKey.myRating), metadata);
      expect(_ids(sorted), ['1', '2', '3']);
    });

    test('does not modify the list it was given', () {
      final items = _items(['1', '2', '3']);
      sortMediaItems(items, const MediaSort(MediaSortKey.added), {});
      expect(_ids(items), ['1', '2', '3']);
    });

    test('returns an empty list unchanged', () {
      expect(sortMediaItems([], const MediaSort(MediaSortKey.title), {}), isEmpty);
    });

    test('distinguishes a movie and a show sharing an id', () {
      // Ids are only unique within a type, so the metadata key must include it.
      expect(mediaMetadataKey(['Movies', '42']),
          isNot(mediaMetadataKey(['TVShows', '42'])));
    });
  });
}
