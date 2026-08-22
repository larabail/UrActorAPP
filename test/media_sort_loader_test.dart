/// Tests for the persisted media sort cache, from the loader's side.
///
/// The point of the whole exercise is a number: how many network requests a
/// cold start costs versus a warm one. So most of these assert on
/// `HttpStub.requests` rather than on the metadata that comes back. The stub
/// throws on any request a test did not set up, so a stray call fails loudly
/// instead of quietly passing.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/media_metadata_cache.dart';
import 'package:uractor/common/media_sort_loader.dart';
import 'package:uractor/objects/media.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/objects/user.dart';

import 'support/harness.dart';

void main() {
  late HttpStub http;
  late MemoryMetadataCacheBacking store;
  late AppUser user;

  const String uid = 'sorting-user';

  setUp(() {
    user = installTestUser(uid: uid);
    http = installHttpStub();
    installFakeCallableContext();
    store = installMemoryMetadataStore();
  });

  /// Writes a cache file for [uid] as though a previous session had left it.
  void seedStore({
    required Map<String, MediaMetadataEntry> entries,
    String forUid = uid,
  }) {
    store.files[forUid] = MediaMetadataCodec.encode(entries);
  }

  MediaMetadataEntry storedEntry({
    String title = 'Stored title',
    DateTime? releaseDate,
    String? imdbId,
    double? imdbRating,
    bool imdbResolved = false,
    String language = 'en',
    Duration age = Duration.zero,
  }) =>
      MediaMetadataEntry(
        title: title,
        releaseDate: releaseDate,
        imdbId: imdbId,
        imdbRating: imdbRating,
        imdbResolved: imdbResolved,
        language: language,
        fetchedAt: DateTime.now().subtract(age),
      );

  /// The entries currently written to [forUid]'s file.
  Map<String, MediaMetadataEntry> storedFor([String forUid = uid]) {
    final raw = store.files[forUid];
    if (raw == null) return <String, MediaMetadataEntry>{};
    return MediaMetadataCodec.decode(raw, now: DateTime.now());
  }

  group('a warm start', () {
    test('renders from the stored cache without a single request', () async {
      seedStore(entries: {
        'Movies:1': storedEntry(
            title: 'Arrival', releaseDate: DateTime(2016, 11, 11)),
        'TVShows:2': storedEntry(
            title: 'Severance', releaseDate: DateTime(2022, 2, 18)),
      });

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
        ['TVShows', '2'],
      ]);

      // The measurement this change exists for. Before it, the same call cost
      // one TMDB request per item on every cold start.
      expect(http.requests, isEmpty);
      expect(metadata['Movies:1']!.title, 'Arrival');
      expect(metadata['Movies:1']!.releaseDate, DateTime(2016, 11, 11));
      expect(metadata['TVShows:2']!.title, 'Severance');
    });

    test('costs nothing for imdb ratings either, which are the expensive part',
        () async {
      seedStore(entries: {
        'TVShows:1399': storedEntry(
          title: 'Game of Thrones',
          imdbId: 'tt0944947',
          imdbRating: 9.2,
          imdbResolved: true,
        ),
      });

      final metadata = await MediaSortLoader.load([
        ['TVShows', '1399'],
      ], includeImdbRating: true);

      // A show costs three requests cold: TMDB details, TMDB external_ids for
      // the IMDb id a show's details do not carry, then OMDB.
      expect(http.requests, isEmpty);
      expect(metadata['TVShows:1399']!.imdbRating, 9.2);
    });

    test('only fetches the titles the stored cache is missing', () async {
      seedStore(entries: {
        for (int i = 0; i < 10; i++) 'Movies:$i': storedEntry(title: 'Known $i'),
      });
      http.on('/movie/10', json: {'title': 'New one'});
      http.on('/movie/11', json: {'title': 'Other new one'});

      final metadata = await MediaSortLoader.load([
        for (int i = 0; i < 12; i++) ['Movies', '$i'],
      ]);

      expect(http.requests, hasLength(2));
      expect(metadata, hasLength(12));
      expect(metadata['Movies:0']!.title, 'Known 0');
      expect(metadata['Movies:10']!.title, 'New one');
    });

    test('remembers that a title has no imdb rating, so it is not looked up '
        'again on the next start', () async {
      seedStore(entries: {
        'Movies:1': storedEntry(title: 'Obscure', imdbResolved: true),
      });

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ], includeImdbRating: true);

      expect(http.requests, isEmpty);
      expect(metadata['Movies:1']!.imdbRating, isNull);
    });
  });

  group('a cold start', () {
    test('fetches what it needs and writes it down for next time', () async {
      http.on('/movie/550', json: {
        'title': 'Fight Club',
        'release_date': '1999-10-15',
        'imdb_id': 'tt0137523',
      });

      await MediaSortLoader.load([
        ['Movies', '550'],
      ]);
      await MediaSortLoader.flushPending();

      expect(http.countFor('/movie/550'), 1);
      final stored = storedFor();
      expect(stored['Movies:550']!.title, 'Fight Club');
      expect(stored['Movies:550']!.releaseDate, DateTime(1999, 10, 15));
      expect(stored['Movies:550']!.imdbId, 'tt0137523');
    });

    test('costs three requests for a show sorted by imdb rating, and none the '
        'next time', () async {
      http.on('/tv/1399', json: {'name': 'Game of Thrones'});
      http.on('external_ids', json: {'imdb_id': 'tt0944947'});
      http.on('omdbLookup', json: {
        'result': {'imdbRating': '9.2'}
      });

      final items = [
        ['TVShows', '1399']
      ];
      await MediaSortLoader.load(items, includeImdbRating: true);
      await MediaSortLoader.flushPending();

      final int cold = http.requests.length;
      expect(cold, 3);

      // Start again from nothing but the file, exactly as a relaunch would.
      final String file = store.files[uid]!;
      await MediaSortLoader.clearCache();
      store.files[uid] = file;
      http.requests.clear();

      final metadata = await MediaSortLoader.load(items,
          includeImdbRating: true);

      expect(http.requests, isEmpty);
      expect(metadata['TVShows:1399']!.imdbRating, 9.2);
    });

    test('writes once for a whole grid rather than once per title', () async {
      for (int i = 0; i < 8; i++) {
        http.on('/movie/$i', json: {'title': 'Film $i'});
      }

      await MediaSortLoader.load([
        for (int i = 0; i < 8; i++) ['Movies', '$i'],
      ]);
      await MediaSortLoader.flushPending();

      expect(store.writeCountFor(uid), 1);
      expect(storedFor(), hasLength(8));
    });

    test('writes itself out on its own, without anything asking it to',
        () async {
      // Nothing in the app calls the flush directly. A user who sorts once and
      // then leaves has to end up with a file anyway, or none of this helps
      // them on the next start.
      http.on('/movie/1', json: {'title': 'Left to settle'});

      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      expect(store.files, isNot(contains(uid)));

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(storedFor()['Movies:1']!.title, 'Left to settle');
    });

    test('stores nothing for a title that could not be fetched', () async {
      http.on('/movie/404', status: 404);

      final metadata = await MediaSortLoader.load([
        ['Movies', '404'],
      ]);
      await MediaSortLoader.flushPending();

      expect(metadata, isEmpty);
      expect(storedFor(), isEmpty);
    });
  });

  group('staleness', () {
    test('an entry older than the ttl is fetched again', () async {
      seedStore(entries: {
        'Movies:1': storedEntry(
            title: 'Old answer', age: const Duration(days: 31)),
      });
      http.on('/movie/1', json: {'title': 'Corrected answer'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(http.countFor('/movie/1'), 1);
      expect(metadata['Movies:1']!.title, 'Corrected answer');
    });

    test('an entry inside the ttl is not', () async {
      seedStore(entries: {
        'Movies:1': storedEntry(
            title: 'Still good', age: const Duration(days: 29)),
      });

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(http.requests, isEmpty);
      expect(metadata['Movies:1']!.title, 'Still good');
    });
  });

  group('the user rating', () {
    test('is read from the signed-in user, never from the stored cache',
        () async {
      seedStore(entries: {'Movies:1': storedEntry(title: 'Rated')});
      user.reviews['1'] = {'Rating': '8'};

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(metadata['Movies:1']!.myRating, 8);
    });

    test('is never written to the file', () async {
      user.reviews['550'] = {'Rating': '10'};
      http.on('/movie/550', json: {'title': 'Fight Club'});

      await MediaSortLoader.load([
        ['Movies', '550'],
      ]);
      await MediaSortLoader.flushPending();

      // The privacy guarantee is structural: there is no field in the file for
      // a personal rating, so no clearing bug can expose one.
      final decoded = jsonDecode(store.files[uid]!) as Map;
      expect(store.files[uid], isNot(contains('"10"')));
      expect(
        ((decoded['entries'] as Map)['Movies:550'] as Map).keys,
        isNot(contains('myRating')),
      );
    });

    test('reflects a rating given during the session, not the one cached with '
        'the title', () async {
      seedStore(entries: {'Movies:1': storedEntry(title: 'Rated later')});

      final before = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      user.reviews['1'] = {'Rating': '7.5'};
      final after = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(before['Movies:1']!.myRating, isNull);
      expect(after['Movies:1']!.myRating, 7.5);
      expect(http.requests, isEmpty);
    });
  });

  group('language', () {
    test('a title stored in another language is fetched again, but its imdb '
        'lookups are kept', () async {
      // A detail page opened in Spanish stores a Spanish name. Sorting a grid
      // by a mixture of Spanish and English names would order it by whichever
      // titles the user had happened to open.
      seedStore(entries: {
        'Movies:1': storedEntry(
          title: 'La La Land en español',
          language: 'es',
          imdbId: 'tt3783958',
          imdbRating: 8.0,
          imdbResolved: true,
        ),
      });
      http.on('/movie/1', json: {'title': 'La La Land'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ], includeImdbRating: true);

      // One request for the title, and none for the rating: the expensive
      // lookups do not vary by language, so they survive.
      expect(http.requests, hasLength(1));
      expect(metadata['Movies:1']!.title, 'La La Land');
      expect(metadata['Movies:1']!.imdbRating, 8.0);
    });
  });

  group('when the cache cannot be reached', () {
    test('an unreadable store falls back to the network instead of failing',
        () async {
      store.failReads = true;
      http.on('/movie/1', json: {'title': 'Fetched anyway'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(metadata['Movies:1']!.title, 'Fetched anyway');
    });

    test('a store that cannot be written still sorts', () async {
      store.failWrites = true;
      http.on('/movie/1', json: {'title': 'Fetched anyway'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();

      expect(metadata['Movies:1']!.title, 'Fetched anyway');
    });

    test('a file left by an older version is ignored, not fatal', () async {
      store.files[uid] = jsonEncode({
        'version': kMediaMetadataCacheVersion - 1,
        'entries': {
          'Movies:1': {'t': 'From an older build', 'lang': 'en', 'at': 0}
        },
      });
      http.on('/movie/1', json: {'title': 'Fetched fresh'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(metadata['Movies:1']!.title, 'Fetched fresh');
    });
  });

  group('a detail page', () {
    /// Stubs everything one detail page asks for, and runs it.
    ///
    /// Going through `Movie`/`TVShow` rather than calling the cache directly
    /// is the point: it proves the write-through is wired into the path the
    /// app actually takes, not just that a setter works.
    Future<void> openDetailPage({
      required String id,
      required String title,
      String? releaseDate,
      String? imdbId,
      String? imdbRating,
      bool isShow = false,
    }) async {
      http.on(isShow ? '/tv/$id-' : '/movie/$id-', json: {
        if (isShow) 'name': title else 'title': title,
        if (releaseDate != null)
          if (isShow) 'first_air_date': releaseDate else
            'release_date': releaseDate,
        if (imdbId != null && !isShow) 'imdb_id': imdbId,
        'backdrop_path': '',
      });
      if (isShow) {
        http.on('external_ids', json: {'imdb_id': imdbId});
      }
      http.on('omdbLookup', json: {
        'result': {'imdbRating': imdbRating ?? 'N/A', 'Year': '2010'}
      });
      http.on('watch/providers', json: {'results': <String, dynamic>{}});
      http.on(isShow ? 'aggregate_credits' : '/credits',
          json: {'cast': [], 'crew': []});
      http.on('/videos', json: {'results': []});

      final item = isShow
          ? TVShow(id: id, title: title, coverPhoto: '')
          : Movie(id: id, title: title, coverPhoto: '') as MediaItem;
      await item.getExtendedData();
    }

    test('leaves a later sort with nothing to fetch', () async {
      await openDetailPage(
        id: '550',
        title: 'Fight Club',
        releaseDate: '1999-10-15',
        imdbId: 'tt0137523',
        imdbRating: '8.8',
      );
      http.requests.clear();

      final metadata = await MediaSortLoader.load([
        ['Movies', '550'],
      ], includeImdbRating: true);

      // The whole argument for the write-through: this data was already
      // fetched once, and used to be thrown away.
      expect(http.requests, isEmpty);
      expect(metadata['Movies:550']!.title, 'Fight Club');
      expect(metadata['Movies:550']!.releaseDate, DateTime(1999, 10, 15));
      expect(metadata['Movies:550']!.imdbRating, 8.8);
    });

    test('pre-pays the external_ids and omdb lookups a show would otherwise '
        'cost on the first sort', () async {
      await openDetailPage(
        id: '1399',
        title: 'Game of Thrones',
        releaseDate: '2011-04-17',
        imdbId: 'tt0944947',
        imdbRating: '9.2',
        isShow: true,
      );
      http.requests.clear();

      final metadata = await MediaSortLoader.load([
        ['TVShows', '1399'],
      ], includeImdbRating: true);

      expect(http.requests, isEmpty);
      expect(metadata['TVShows:1399']!.imdbRating, 9.2);
    });

    test('records a title with no imdb rating so the sort does not go looking',
        () async {
      await openDetailPage(id: '7', title: 'Obscure');
      http.requests.clear();

      final metadata = await MediaSortLoader.load([
        ['Movies', '7'],
      ], includeImdbRating: true);

      expect(http.requests, isEmpty);
      expect(metadata['Movies:7']!.imdbRating, isNull);
    });

    test('survives the cache being unwritable, because showing the page is '
        'its actual job', () async {
      store.failWrites = true;

      await openDetailPage(id: '550', title: 'Fight Club', imdbRating: '8.8');

      expect(store.files, isEmpty);
    });
  });

  group('clearing', () {
    test('deletes the stored file, not just the copy in memory', () async {
      http.on('/movie/1', json: {'title': 'Cached'});
      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();
      expect(store.files, contains(uid));

      await MediaSortLoader.clearCache();

      expect(store.files, isNot(contains(uid)));
    });

    test('drops a write that was still pending, so it cannot resurrect the '
        'file afterwards', () async {
      http.on('/movie/1', json: {'title': 'Cached'});
      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      // Clear before the debounce has elapsed.
      await MediaSortLoader.clearCache();
      await MediaSortLoader.flushPending();

      expect(store.files, isNot(contains(uid)));
    });
  });
}
