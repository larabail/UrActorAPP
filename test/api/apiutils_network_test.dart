/// Tests for the network side of `ApiUtils`.
///
/// These used to be impossible to write: every call went straight out to TMDB
/// and OMDB. Through the `AppHttp` seam they now run against stubbed responses,
/// so the parsing, fallbacks and error handling are all covered without a
/// network call or a single request against the rate limited keys.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/apiutils.dart';
import 'package:uractor/main.dart';

import '../support/harness.dart';

void main() {
  late HttpStub http;

  setUp(() {
    installTestUser();
    http = installHttpStub();
  });

  group('fetchOmdbData', () {
    test('decodes a successful response', () async {
      http.on('omdbapi.com', json: {'imdbRating': '8.8', 'Year': '2010'});

      final data = await ApiUtils.fetchOmdbData('tt1375666');

      expect(data['imdbRating'], '8.8');
      expect(data['Year'], '2010');
    });

    test('sends the imdb id it was given', () async {
      http.on('omdbapi.com', json: {});

      await ApiUtils.fetchOmdbData('tt1375666');

      expect(http.requests.single.toString(), contains('i=tt1375666'));
    });

    test('throws when the request fails', () async {
      http.on('omdbapi.com', status: 500, body: 'nope');

      expect(
        () => ApiUtils.fetchOmdbData('tt1375666'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchProviders', () {
    test('returns provider names paired with absolute logo urls', () async {
      http.on('watch/providers', json: {
        'results': {
          'US': {
            'flatrate': [
              {'provider_name': 'Netflix', 'logo_path': 'netflix.jpg'},
              {'provider_name': 'Max', 'logo_path': 'max.jpg'},
            ]
          }
        }
      });

      final providers = await ApiUtils.fetchProviders('27205', 'Inception',
          'US', 'movie');

      expect(providers, [
        ['Netflix', 'https://image.tmdb.org/t/p/w500/netflix.jpg'],
        ['Max', 'https://image.tmdb.org/t/p/w500/max.jpg'],
      ]);
    });

    test('returns nothing for a country with no listing', () async {
      http.on('watch/providers', json: {
        'results': {
          'US': {
            'flatrate': [
              {'provider_name': 'Netflix', 'logo_path': 'netflix.jpg'}
            ]
          }
        }
      });

      final providers = await ApiUtils.fetchProviders('27205', 'Inception',
          'JP', 'movie');

      expect(providers, isEmpty);
    });

    test('returns nothing when the country is listed without streaming',
        () async {
      // A country can appear with only rent or buy options and no flatrate at
      // all, which must not be read as a missing key and blow up.
      http.on('watch/providers', json: {
        'results': {
          'US': {
            'rent': [
              {'provider_name': 'Apple TV', 'logo_path': 'apple.jpg'}
            ]
          }
        }
      });

      final providers = await ApiUtils.fetchProviders('27205', 'Inception',
          'US', 'movie');

      expect(providers, isEmpty);
    });

    test('asks the tv endpoint for a tv show', () async {
      http.on('watch/providers', json: {'results': {}});

      await ApiUtils.fetchProviders('1399', 'Thrones', 'US', 'tv');

      expect(http.requests.single.toString(), contains('/3/tv/'));
    });

    test('throws when the request fails', () async {
      http.on('watch/providers', status: 404, body: '');

      expect(
        () => ApiUtils.fetchProviders('27205', 'Inception', 'US', 'movie'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchMovieDetails', () {
    test('decodes the details response', () async {
      http.on('/3/movie/', json: {'title': 'Inception', 'id': 27205});

      final details = await ApiUtils.fetchMovieDetails('27205', 'Inception',
          'movie');

      expect(details['title'], 'Inception');
    });

    test('requests the language the user has selected', () async {
      currentUser.settings['language'] = 'es';
      http.on('/3/movie/', json: {});

      await ApiUtils.fetchMovieDetails('27205', 'Inception', 'movie');

      expect(http.requests.single.toString(), contains('language=es'));
    });

    test('falls back to english when no language is set', () async {
      currentUser.settings = {};
      http.on('/3/movie/', json: {});

      await ApiUtils.fetchMovieDetails('27205', 'Inception', 'movie');

      expect(http.requests.single.toString(), contains('language=en'));
    });

    test('throws when the request fails', () async {
      http.on('/3/movie/', status: 401, body: '');

      expect(
        () => ApiUtils.fetchMovieDetails('27205', 'Inception', 'movie'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchCreditsAndTrailer', () {
    void stubCreditsAndVideos({
      List<Map<String, dynamic>>? crew,
      List<Map<String, dynamic>>? videos,
    }) {
      http.on('/credits', json: {
        'cast': [
          {'id': 1, 'name': 'Leonardo DiCaprio'}
        ],
        'crew': crew ??
            [
              {'id': 10, 'name': 'Christopher Nolan', 'job': 'Director'}
            ],
      });
      http.on('/videos', json: {'results': videos ?? []});
    }

    test('returns cast, crew and no trailer when there is none', () async {
      stubCreditsAndVideos();

      final data = await ApiUtils.fetchCreditsAndTrailer('27205', 'Inception',
          'movie');

      expect(data['cast'], hasLength(1));
      expect(data['crew'], hasLength(1));
      expect(data['trailer'], isNull);
    });

    test('picks the youtube trailer out of the video list', () async {
      stubCreditsAndVideos(videos: [
        {'site': 'Vimeo', 'type': 'Trailer', 'key': 'wrong-site'},
        {'site': 'YouTube', 'type': 'Featurette', 'key': 'wrong-type'},
        {'site': 'YouTube', 'type': 'Trailer', 'key': 'right'},
      ]);

      final data = await ApiUtils.fetchCreditsAndTrailer('27205', 'Inception',
          'movie');

      expect(data['trailer']['key'], 'right');
    });

    test('merges a person credited with two jobs into one entry', () async {
      stubCreditsAndVideos(crew: [
        {'id': 10, 'name': 'Nolan', 'job': 'Director'},
        {'id': 10, 'name': 'Nolan', 'job': 'Writer'},
      ]);

      final data = await ApiUtils.fetchCreditsAndTrailer('27205', 'Inception',
          'movie');

      expect(data['crew'], hasLength(1));
      expect(data['crew'][0]['job'], 'Director / Writer');
    });

    test('throws when either request fails', () async {
      http.on('/credits', json: {'cast': [], 'crew': []});
      http.on('/videos', status: 500, body: '');

      expect(
        () => ApiUtils.fetchCreditsAndTrailer('27205', 'Inception', 'movie'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchAdditionalMovieData', () {
    setUp(() {
      http.on('/credits', json: {'cast': [], 'crew': []});
      http.on('/videos', json: {'results': []});
      http.on('watch/providers', json: {'results': {}});
    });

    test('takes the imdb rating and year from omdb', () async {
      http.on('omdbapi.com', json: {'imdbRating': '8.8', 'Year': '2010'});

      final data = await ApiUtils.fetchAdditionalMovieData(
          {'imdb_id': 'tt1375666'}, '27205', 'Inception', 'movie');

      expect(data['imdb_rating'], '8.8');
      expect(data['year'], '2010');
    });

    test('treats an omdb rating of N/A as unrated', () async {
      // OMDB returns the string "N/A" rather than omitting the field, and
      // showing that verbatim next to a score would look like a bug.
      http.on('omdbapi.com', json: {'imdbRating': 'N/A', 'Year': '2010'});

      final data = await ApiUtils.fetchAdditionalMovieData(
          {'imdb_id': 'tt1375666'}, '27205', 'Inception', 'movie');

      expect(data['imdb_rating'], '0.0');
    });

    test('falls back when the title has no imdb id at all', () async {
      final data = await ApiUtils.fetchAdditionalMovieData(
          {'imdb_id': null}, '27205', 'Inception', 'movie');

      expect(data['imdb_rating'], '0.0');
      expect(data['year'], 'None');
      expect(http.countFor('omdbapi.com'), 0);
    });

    test('looks up the imdb id separately for a tv show', () async {
      // Only movie details carry an imdb_id, so a show needs the external ids
      // endpoint first or it would always come back unrated.
      http.on('external_ids', json: {'imdb_id': 'tt0944947'});
      http.on('omdbapi.com', json: {'imdbRating': '9.2', 'Year': '2011'});

      final data = await ApiUtils.fetchAdditionalMovieData(
          {}, '1399', 'Thrones', 'tv');

      expect(http.countFor('external_ids'), 1);
      expect(data['imdb_rating'], '9.2');
    });

    test('leaves a tv show unrated when it has no external imdb id', () async {
      http.on('external_ids', json: {'imdb_id': null});

      final data = await ApiUtils.fetchAdditionalMovieData(
          {}, '1399', 'Thrones', 'tv');

      expect(data['imdb_rating'], '0.0');
      expect(http.countFor('omdbapi.com'), 0);
    });

    test('asks for providers in the country on the user profile', () async {
      currentUser.country = 'ES';
      http.on('omdbapi.com', json: {'imdbRating': '8.8', 'Year': '2010'});

      await ApiUtils.fetchAdditionalMovieData(
          {'imdb_id': 'tt1375666'}, '27205', 'Inception', 'movie');

      expect(http.countFor('watch/providers'), 1);
    });
  });

  group('searchData', () {
    test('returns the results array', () async {
      http.on('search/multi', json: {
        'results': [
          {'id': 1, 'title': 'Inception'}
        ]
      });

      final results = await ApiUtils.searchData('inception');

      expect(results, hasLength(1));
    });

    test('does not call the api for an empty term', () async {
      final results = await ApiUtils.searchData('');

      expect(results, isEmpty);
      expect(http.requests, isEmpty);
    });

    test('returns nothing rather than throwing when the request fails',
        () async {
      // Multi-search backs the search-as-you-type screen, where a thrown error
      // would surface as a crash on a keystroke.
      http.on('search/multi', status: 500, body: '');

      expect(await ApiUtils.searchData('inception'), isEmpty);
    });
  });

  group('searchMovies and searchTvShows', () {
    test('return the results array', () async {
      http.on('search/movie', json: {
        'results': [
          {'id': 1}
        ]
      });
      http.on('search/tv', json: {
        'results': [
          {'id': 2},
          {'id': 3}
        ]
      });

      expect(await ApiUtils.searchMovies('inception'), hasLength(1));
      expect(await ApiUtils.searchTvShows('thrones'), hasLength(2));
    });

    test('skip the call for an empty term', () async {
      expect(await ApiUtils.searchMovies(''), isEmpty);
      expect(await ApiUtils.searchTvShows(''), isEmpty);
      expect(http.requests, isEmpty);
    });

    test('throw when the request fails', () async {
      http.on('search/movie', status: 500, body: '');
      http.on('search/tv', status: 500, body: '');

      expect(() => ApiUtils.searchMovies('x'), throwsA(isA<Exception>()));
      expect(() => ApiUtils.searchTvShows('x'), throwsA(isA<Exception>()));
    });
  });

  group('processSeenDates', () {
    test('returns the dates a title was watched, newest first', () {
      final calendar = {
        '2024-01-01': [
          {'id': '27205', 'type': 'movie'}
        ],
        '2024-03-01': [
          {'id': '27205', 'type': 'movie'}
        ],
        '2024-02-01': [
          {'id': '27205', 'type': 'movie'}
        ],
      };

      final dates = ApiUtils.processSeenDates(calendar, '27205', 'movie');

      expect(dates.map((entry) => entry[0]),
          ['2024-03-01', '2024-02-01', '2024-01-01']);
    });

    test('ignores other titles on the same day', () {
      final calendar = {
        '2024-01-01': [
          {'id': '27205', 'type': 'movie'},
          {'id': '999', 'type': 'movie'},
        ],
      };

      expect(ApiUtils.processSeenDates(calendar, '999', 'movie'), hasLength(1));
    });

    test('treats an entry with no type as a movie', () {
      // Calendar entries predating the addition of a type field are all movies,
      // and would otherwise disappear from a film's watch history.
      final calendar = {
        '2024-01-01': [
          {'id': '27205'}
        ],
      };

      expect(ApiUtils.processSeenDates(calendar, '27205', 'movie'),
          hasLength(1));
      expect(ApiUtils.processSeenDates(calendar, '27205', 'tv'), isEmpty);
    });

    test('carries the friends watched with through', () {
      final calendar = {
        '2024-01-01': [
          {
            'id': '27205',
            'type': 'movie',
            'friends': ['friend-uid']
          }
        ],
      };

      expect(ApiUtils.processSeenDates(calendar, '27205', 'movie').single[1],
          ['friend-uid']);
    });
  });
}
