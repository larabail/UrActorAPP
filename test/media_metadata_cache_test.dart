/// Tests for the persisted form of the media sort cache.
///
/// Everything here is a pure function of its arguments and an explicit clock,
/// which is the point of keeping this file separate from the fetching: the
/// awkward cases -- a file from an older build, a truncated write, an entry a
/// month past its date -- are all reachable without a network, a disk or a
/// widget.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/media_metadata_cache.dart';

void main() {
  // Local rather than UTC, because that is what production produces: TMDB
  // sends a plain `1999-10-15` with no timezone, and `DateTime.tryParse` reads
  // a bare date as local time.
  final DateTime now = DateTime(2026, 8, 22);

  MediaMetadataEntry entry({
    String title = 'Fight Club',
    DateTime? releaseDate,
    String? imdbId = 'tt0137523',
    double? imdbRating = 8.8,
    bool imdbResolved = true,
    String language = 'en',
    DateTime? fetchedAt,
  }) =>
      MediaMetadataEntry(
        title: title,
        releaseDate: releaseDate ?? DateTime(1999, 10, 15),
        imdbId: imdbId,
        imdbRating: imdbRating,
        imdbResolved: imdbResolved,
        language: language,
        fetchedAt: fetchedAt ?? now,
      );

  group('a stored entry', () {
    test('survives a round trip through json intact', () {
      final restored = MediaMetadataEntry.fromJson(entry().toJson());

      expect(restored, isNotNull);
      expect(restored!.title, 'Fight Club');
      expect(restored.releaseDate, DateTime(1999, 10, 15));
      expect(restored.imdbId, 'tt0137523');
      expect(restored.imdbRating, 8.8);
      expect(restored.imdbResolved, isTrue);
      expect(restored.language, 'en');
      expect(restored.fetchedAt, now);
    });

    test('keeps a title that has no release date, id or rating', () {
      final sparse = MediaMetadataEntry(
        title: 'Unreleased',
        language: 'en',
        fetchedAt: now,
      );

      final restored = MediaMetadataEntry.fromJson(sparse.toJson());

      expect(restored!.title, 'Unreleased');
      expect(restored.releaseDate, isNull);
      expect(restored.imdbId, isNull);
      expect(restored.imdbRating, isNull);
      expect(restored.imdbResolved, isFalse);
    });

    test('remembers that a lookup found no rating, so it is not repeated', () {
      // The expensive case: a title with no IMDb entry costs an OMDB request
      // to discover that, and would pay it again on every sort if the attempt
      // were not written down.
      final resolved = MediaMetadataEntry(
        title: 'Obscure',
        language: 'en',
        fetchedAt: now,
        imdbResolved: true,
      );

      final restored = MediaMetadataEntry.fromJson(resolved.toJson());

      expect(restored!.imdbResolved, isTrue);
      expect(restored.imdbRating, isNull);
    });

    test('reads a rating written as a string as well as a number', () {
      final fromString = MediaMetadataEntry.fromJson({
        't': 'Film',
        'lang': 'en',
        'at': now.millisecondsSinceEpoch,
        'r': '7.5',
      });

      expect(fromString!.imdbRating, 7.5);
    });

    test('is rejected when a field it cannot work without is missing or of '
        'the wrong type', () {
      final base = <String, dynamic>{
        't': 'Film',
        'lang': 'en',
        'at': now.millisecondsSinceEpoch,
      };

      expect(MediaMetadataEntry.fromJson('not a map'), isNull);
      expect(MediaMetadataEntry.fromJson({...base}..remove('t')), isNull);
      expect(MediaMetadataEntry.fromJson({...base}..remove('lang')), isNull);
      expect(MediaMetadataEntry.fromJson({...base}..remove('at')), isNull);
      expect(MediaMetadataEntry.fromJson({...base, 'at': 'yesterday'}), isNull);
      expect(MediaMetadataEntry.fromJson({...base, 't': 42}), isNull);
    });

    test('ignores a release date it cannot parse rather than being thrown out',
        () {
      final restored = MediaMetadataEntry.fromJson({
        't': 'Film',
        'lang': 'en',
        'at': now.millisecondsSinceEpoch,
        'd': 'sometime in the nineties',
      });

      expect(restored, isNotNull);
      expect(restored!.releaseDate, isNull);
    });

    test('ignores keys it does not know, so a newer build\'s file still reads',
        () {
      final restored = MediaMetadataEntry.fromJson({
        't': 'Film',
        'lang': 'en',
        'at': now.millisecondsSinceEpoch,
        'runtime': 139,
      });

      expect(restored!.title, 'Film');
    });

    test('never carries the signed-in user\'s own rating', () {
      // The structural half of the privacy guarantee: myRating is the one
      // field that belongs to a person rather than a title, and there is no
      // way to put it in a file because nothing serialises it.
      final encoded = MediaMetadataCodec.encode({'Movies:550': entry()});
      final decoded = jsonDecode(encoded) as Map;
      final stored =
          (decoded['entries'] as Map)['Movies:550'] as Map<String, dynamic>;

      expect(stored.keys, isNot(contains('myRating')));
      expect(stored.keys, isNot(contains('my')));
      expect(encoded, isNot(contains('myRating')));
    });

    test('supplies the user rating from the caller, not from itself', () {
      final metadata = entry().toSortMetadata(myRating: 9);

      expect(metadata.myRating, 9);
      expect(metadata.title, 'Fight Club');
      expect(metadata.imdbRating, 8.8);
    });
  });

  group('staleness', () {
    test('an entry inside the ttl is used', () {
      final fresh = entry(fetchedAt: now.subtract(const Duration(days: 29)));

      expect(fresh.isFresh(now), isTrue);
    });

    test('an entry past the ttl is not', () {
      final stale = entry(fetchedAt: now.subtract(const Duration(days: 31)));

      expect(stale.isFresh(now), isFalse);
    });

    test('the boundary is inclusive, so an entry does not expire early', () {
      final exact = entry(fetchedAt: now.subtract(kMediaMetadataTtl));

      expect(exact.isFresh(now), isTrue);
    });

    test('an expired entry is dropped on the way in, not left to the caller',
        () {
      final source = MediaMetadataCodec.encode({
        'Movies:1': entry(fetchedAt: now.subtract(const Duration(days: 31))),
        'Movies:2': entry(fetchedAt: now.subtract(const Duration(days: 2))),
      });

      final decoded = MediaMetadataCodec.decode(source, now: now);

      expect(decoded.keys, ['Movies:2']);
    });
  });

  group('language', () {
    test('an entry matches only the language it was fetched in', () {
      expect(entry(language: 'en').matchesLanguage('en'), isTrue);
      expect(entry(language: 'es').matchesLanguage('en'), isFalse);
    });
  });

  group('reading a whole file', () {
    test('gives back what was written', () {
      final source = MediaMetadataCodec.encode({
        'Movies:550': entry(),
        'TVShows:1399': entry(title: 'Game of Thrones', imdbId: 'tt0944947'),
      });

      final decoded = MediaMetadataCodec.decode(source, now: now);

      expect(decoded, hasLength(2));
      expect(decoded['Movies:550']!.title, 'Fight Club');
      expect(decoded['TVShows:1399']!.imdbId, 'tt0944947');
    });

    test('discards a file written by a version that no longer exists', () {
      // Migration by discarding: the file holds nothing that cannot be
      // fetched again, so guessing at an older layout risks showing wrong
      // titles for no gain.
      final old = jsonEncode({
        'version': kMediaMetadataCacheVersion - 1,
        'entries': {'Movies:550': entry().toJson()},
      });

      expect(MediaMetadataCodec.decode(old, now: now), isEmpty);
    });

    test('discards a file from a future version too', () {
      final ahead = jsonEncode({
        'version': kMediaMetadataCacheVersion + 1,
        'entries': {'Movies:550': entry().toJson()},
      });

      expect(MediaMetadataCodec.decode(ahead, now: now), isEmpty);
    });

    test('discards a file with no version at all', () {
      final unversioned = jsonEncode({
        'entries': {'Movies:550': entry().toJson()},
      });

      expect(MediaMetadataCodec.decode(unversioned, now: now), isEmpty);
    });

    test('survives contents that are not json, or not an object', () {
      expect(MediaMetadataCodec.decode('', now: now), isEmpty);
      expect(MediaMetadataCodec.decode('{"version": 1', now: now), isEmpty);
      expect(MediaMetadataCodec.decode('[1, 2, 3]', now: now), isEmpty);
      expect(MediaMetadataCodec.decode('null', now: now), isEmpty);
    });

    test('survives a version that is right but entries that are not a map', () {
      final wrong = jsonEncode({
        'version': kMediaMetadataCacheVersion,
        'entries': ['Movies:550'],
      });

      expect(MediaMetadataCodec.decode(wrong, now: now), isEmpty);
    });

    test('keeps the good entries when one of them is damaged', () {
      // A crash mid-write should cost one title, not a whole library.
      final partly = jsonEncode({
        'version': kMediaMetadataCacheVersion,
        'entries': {
          'Movies:550': entry().toJson(),
          'Movies:99': {'t': 'Truncated'},
          'Movies:100': 'not an entry at all',
        },
      });

      final decoded = MediaMetadataCodec.decode(partly, now: now);

      expect(decoded.keys, ['Movies:550']);
    });
  });

  group('the size cap', () {
    test('leaves a cache below the cap alone', () {
      final entries = {
        for (int i = 0; i < 5; i++) 'Movies:$i': entry(),
      };

      expect(MediaMetadataCodec.trim(entries, maxEntries: 10), hasLength(5));
    });

    test('drops the least recently fetched first', () {
      final entries = {
        'Movies:old': entry(fetchedAt: now.subtract(const Duration(days: 20))),
        'Movies:newest': entry(fetchedAt: now),
        'Movies:middle': entry(fetchedAt: now.subtract(const Duration(days: 1))),
      };

      final trimmed = MediaMetadataCodec.trim(entries, maxEntries: 2);

      expect(trimmed.keys, containsAll(['Movies:newest', 'Movies:middle']));
      expect(trimmed.keys, isNot(contains('Movies:old')));
    });

    test('is applied when the file is written, so it cannot grow forever', () {
      final entries = {
        for (int i = 0; i < 12; i++)
          'Movies:$i': entry(fetchedAt: now.subtract(Duration(days: i))),
      };

      final decoded = MediaMetadataCodec.decode(
        MediaMetadataCodec.encode(entries, maxEntries: 4),
        now: now,
      );

      expect(decoded, hasLength(4));
      expect(decoded.keys, contains('Movies:0'));
      expect(decoded.keys, isNot(contains('Movies:11')));
    });
  });
}
