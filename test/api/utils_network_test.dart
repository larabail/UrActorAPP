/// Tests for the network side of `Utils`, the fetch helpers shared by the
/// several screens that used to duplicate this logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/utils.dart';

import '../support/harness.dart';

void main() {
  late HttpStub http;

  setUp(() {
    installTestUser();
    http = installHttpStub();
  });

  group('fetchMediaData', () {
    test('reads a movie title from the title field', () async {
      http.on('/3/movie/', json: {
        'title': 'Inception',
        'poster_path': '/poster.jpg',
        'id': 27205,
      });

      final cache = <Map<String, dynamic>>[];
      final data = await Utils.fetchMediaData('27205', 'Movies', cache);

      expect(data['title'], 'Inception');
      expect(data['poster_path'], '/poster.jpg');
      expect(data['type'], 'Movies');
    });

    test('reads a tv title from the name field instead', () async {
      // TMDB names the field differently per media type, and reading the wrong
      // one leaves every show in the grid with a blank title.
      http.on('/3/tv/', json: {
        'name': 'Game of Thrones',
        'poster_path': '/got.jpg',
        'id': 1399,
      });

      final cache = <Map<String, dynamic>>[];
      final data = await Utils.fetchMediaData('1399', 'TVShows', cache);

      expect(data['title'], 'Game of Thrones');
    });

    test('adds the result to the cache', () async {
      http.on('/3/movie/',
          json: {'title': 'Inception', 'poster_path': '/p.jpg', 'id': 27205});

      final cache = <Map<String, dynamic>>[];
      await Utils.fetchMediaData('27205', 'Movies', cache);

      expect(cache, hasLength(1));
    });

    test('does not add the same item to the cache twice', () async {
      http.on('/3/movie/',
          json: {'title': 'Inception', 'poster_path': '/p.jpg', 'id': 27205});

      final cache = <Map<String, dynamic>>[];
      await Utils.fetchMediaData('27205', 'Movies', cache);
      await Utils.fetchMediaData('27205', 'Movies', cache);

      expect(cache, hasLength(1));
    });

    test('keeps a movie and a show that share an id apart', () async {
      // Ids are only unique within a type, so the cache must not treat these
      // as the same entry.
      http.on('/3/movie/',
          json: {'title': 'A Movie', 'poster_path': '/a.jpg', 'id': 100});
      http.on('/3/tv/',
          json: {'name': 'A Show', 'poster_path': '/b.jpg', 'id': 100});

      final cache = <Map<String, dynamic>>[];
      await Utils.fetchMediaData('100', 'Movies', cache);
      await Utils.fetchMediaData('100', 'TVShows', cache);

      expect(cache, hasLength(2));
    });

    test('throws when the request fails', () async {
      http.on('/3/movie/', status: 404, body: '');

      expect(
        () => Utils.fetchMediaData('27205', 'Movies', <Map<String, dynamic>>[]),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchCalendarElement', () {
    test('appends the fetched entry to the target list', () async {
      http.on('/3/movie/', json: {'id': 27205, 'title': 'Inception'});

      final target = [];
      await Utils.fetchCalendarElement(
          {'id': '27205', 'title': 'Inception'}, target);

      expect(target, hasLength(1));
      expect(target.single['title'], 'Inception');
    });

    test('carries the friends field over onto the result', () async {
      http.on('/3/movie/', json: {'id': 27205, 'title': 'Inception'});

      final target = [];
      await Utils.fetchCalendarElement({
        'id': '27205',
        'title': 'Inception',
        'friends': ['friend-uid'],
      }, target);

      expect(target.single['friends'], ['friend-uid']);
    });

    test('uses the tv endpoint for a tv entry', () async {
      http.on('/3/tv/', json: {'id': 1399, 'name': 'Thrones'});

      await Utils.fetchCalendarElement(
          {'id': '1399', 'title': 'Thrones', 'type': 'tv'}, []);

      expect(http.requests.single.toString(), contains('/3/tv/'));
    });

    test('treats an entry with no type as a movie', () async {
      http.on('/3/movie/', json: {'id': 27205, 'title': 'Inception'});

      await Utils.fetchCalendarElement(
          {'id': '27205', 'title': 'Inception'}, []);

      expect(http.requests.single.toString(), contains('/3/movie/'));
    });

    test('strips punctuation from the title when asked', () async {
      http.on('/3/movie/', json: {'id': 1, 'title': 'x'});

      await Utils.fetchCalendarElement(
        {'id': '1', 'title': "Ocean's Eleven"},
        [],
        sanitizeName: true,
      );

      expect(http.requests.single.toString(), contains('Ocean-s-Eleven'));
    });

    test('leaves the title alone when not asked to sanitize', () async {
      http.on('/3/movie/', json: {'id': 1, 'title': 'x'});

      await Utils.fetchCalendarElement({'id': '1', 'title': 'Inception'}, []);

      expect(http.requests.single.toString(), contains('1-Inception'));
    });

    test('appends duplicates unless deduping was requested', () async {
      http.on('/3/movie/', json: {'id': 27205, 'title': 'Inception'});
      final element = {'id': '27205', 'title': 'Inception'};

      final target = [];
      await Utils.fetchCalendarElement(element, target);
      await Utils.fetchCalendarElement(element, target);
      expect(target, hasLength(2),
          reason: 'a title genuinely watched twice is two calendar entries');

      final deduped = [];
      await Utils.fetchCalendarElement(element, deduped, dedupe: true);
      await Utils.fetchCalendarElement(element, deduped, dedupe: true);
      expect(deduped, hasLength(1));
    });

    test('throws when the request fails', () async {
      http.on('/3/movie/', status: 500, body: '');

      expect(
        () => Utils.fetchCalendarElement({'id': '1', 'title': 'x'}, []),
        throwsA(isA<Exception>()),
      );
    });
  });
}
