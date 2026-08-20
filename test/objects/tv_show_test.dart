/// Tests for `TVShow`.
///
/// A show and a film with the same TMDB id are different titles, and almost
/// every field here is the TV half of a pair whose film half lives on `Movie`.
/// These tests exist mostly to catch a show reading the film lists, which
/// looks right until two ids happen to collide.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/objects/user.dart';

import '../support/harness.dart';

TVShow breakingBad() =>
    TVShow(id: '1396', title: 'Breaking Bad', coverPhoto: '/cover.jpg');

void main() {
  late AppUser user;

  setUp(() {
    user = installTestUser();
    app.reviewed = false;
  });

  tearDown(() {
    app.reviewed = false;
  });

  group('membership', () {
    test('a show in the seen list reads as seen', () {
      user.seenTVShows = [
        ['TVShows', '1396'],
      ];

      expect(breakingBad().isSeen(), isTrue);
    });

    test('a film with the same id does not make the show read as seen', () {
      user.seenMovies = [
        ['Movies', '1396'],
      ];
      user.seenTVShows = [
        ['Movies', '1396'],
      ];

      expect(breakingBad().isSeen(), isFalse);
    });

    test('the TV watchlist and favourites are read, not the film ones', () {
      user.watchlist = [
        ['Movies', '1396'],
      ];
      user.favMovies = [
        ['Movies', '1396'],
      ];

      expect(breakingBad().isBookmarked(), isFalse);
      expect(breakingBad().isFavorite(), isFalse);

      user.watchlistTVShows = [
        ['TVShows', '1396'],
      ];
      user.favTVShows = [
        ['TVShows', '1396'],
      ];

      expect(breakingBad().isBookmarked(), isTrue);
      expect(breakingBad().isFavorite(), isTrue);
    });
  });

  group('getData', () {
    test('returns the decoded show', () async {
      final http = installHttpStub();
      http.on('/tv/1396', json: {'id': 1396, 'name': 'Breaking Bad'});

      expect(await breakingBad().getData(), {
        'id': 1396,
        'name': 'Breaking Bad',
      });
    });

    test('returns nothing rather than throwing when TMDB refuses', () async {
      final http = installHttpStub();
      http.on('/tv/1396', status: 500, body: '');

      expect(await breakingBad().getData(), isEmpty);
    });
  });

  group('getSeasonsData', () {
    test('asks for the season that was requested', () async {
      final http = installHttpStub();
      http.on('/tv/1396/season/2', json: {
        'season_number': 2,
        'episodes': [
          {'episode_number': 1}
        ],
      });

      final json = await breakingBad().getSeasonsData(2);

      expect(json['season_number'], 2);
      expect(http.countFor('/tv/1396/season/2'), 1);
    });

    test('a season TMDB does not have comes back empty', () async {
      // Shows whose metadata is incomplete are still browsable, so a missing
      // season has to render as no episodes rather than take the page down.
      final http = installHttpStub();
      http.on('/tv/1396/season/99', status: 404, body: '');

      expect(await breakingBad().getSeasonsData(99), isEmpty);
    });
  });

  group('getExtendedData', () {
    late HttpStub http;

    setUp(() {
      http = installHttpStub();
      http.on('1396-Breaking-Bad?', json: {
        'id': 1396,
        'name': 'Breaking Bad',
        'backdrop_path': '/backdrop.jpg',
      });
      http.on('/external_ids', json: {'imdb_id': 'tt0903747'});
      http.on('omdbapi.com', json: {'imdbRating': '9.5', 'Year': '2008–2013'});
      http.on('watch/providers', json: {'results': <String, dynamic>{}});
      // A show's credits come from `/aggregate_credits`, since `/credits`
      // returns the newest season's regulars alone.
      http.on('/aggregate_credits?', json: {'cast': [], 'crew': []});
      http.on('/videos?', json: {'results': []});
    });

    test('the IMDb id comes from the external ids call, not the show itself',
        () async {
      // TMDB does not carry imdb_id on a show the way it does on a film, so
      // skipping this second call silently loses every rating and year.
      final json = await breakingBad().getExtendedData();

      expect(http.countFor('/external_ids'), 1);
      expect(json['imdb_rating'], '9.5');
      expect(json['year'], '2008–2013');
    });

    test('a rewatch count comes from the TV map, not the film one', () async {
      user.rewatchedMovies = {'1396': 9};
      user.rewatchedTVShows = {'1396': 2};

      expect((await breakingBad().getExtendedData())['times_seen'], 2);
    });

    test('the review comes from the TV reviews', () async {
      app.reviewed = true;
      user.reviews = {
        '1396': {'Opinion': 'wrong one', 'Rating': '1'}
      };
      user.tvShowReviews = {
        '1396': {'Opinion': 'All hail the king', 'Rating': '5'}
      };

      expect((await breakingBad().getExtendedData())['review'],
          {'Opinion': 'All hail the king', 'Rating': '5'});
    });

    test('only calendar entries recorded as a series count as watch dates',
        () async {
      // A calendar entry with no type at all predates the field and is treated
      // as a film, so a show must not pick it up even when the id matches.
      user.calendar = {
        '2024-01-05': [
          {'id': '1396', 'type': 'series', 'friends': []},
        ],
        '2024-02-01': [
          {'id': '1396', 'type': 'movie', 'friends': []},
        ],
        '2024-03-09': [
          {'id': '1396', 'friends': []},
        ],
      };

      expect((await breakingBad().getExtendedData())['seen_dates'], [
        ['2024-01-05', []],
      ]);
    });
  });

  group('removeFriend', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = installFakeFirestore();
      await seedUserDoc(firestore, 'test-uid', 'SeenWith', {
        'TVShows': {
          '1396': {
            'friends': ['friend-uid', 'other-uid']
          }
        },
        'Movies': {
          '1396': {
            'friends': ['friend-uid']
          }
        },
      });
      await seedUserDoc(firestore, 'friend-uid', 'SeenWith', {
        'TVShows': {
          '1396': {
            'friends': ['test-uid']
          }
        },
      });
      user.seenWith = {
        'friend-uid': {
          'Movies': ['1396'],
          'TVShows': ['1396'],
        }
      };
    });

    test('the friend is dropped from both records', () async {
      await breakingBad().removeFriend('friend-uid', []);

      final mine = await firestore.collection('test-uid').doc('SeenWith').get();
      final theirs =
          await firestore.collection('friend-uid').doc('SeenWith').get();

      expect(mine.data()!['TVShows']['1396']['friends'], ['other-uid']);
      expect(theirs.data()!['TVShows']['1396']['friends'], isEmpty);
    });

    test('the film watched with the same friend is left alone', () async {
      await breakingBad().removeFriend('friend-uid', []);

      final mine = await firestore.collection('test-uid').doc('SeenWith').get();

      expect(mine.data()!['Movies']['1396']['friends'], ['friend-uid']);
      expect(user.seenWith['friend-uid']['Movies'], ['1396']);
      expect(user.seenWith['friend-uid']['TVShows'], isEmpty);
    });
  });
}
