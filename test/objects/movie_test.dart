/// Tests for `Movie`.
///
/// The membership helpers decide which badges a tile shows and whether the
/// buttons on a media page start filled in, and they are the kind of thing a
/// stray `toString()` breaks silently. `getExtendedData` is the assembly point
/// for everything a media page renders, so what it does when a piece is
/// missing is worth pinning down.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/user.dart';

import '../support/harness.dart';

Movie inception() =>
    Movie(id: '27205', title: 'Inception', coverPhoto: '/cover.jpg');

void main() {
  late AppUser user;

  setUp(() {
    user = installTestUser();
    installFakeCallableContext();
    app.reviewed = false;
  });

  tearDown(() {
    app.reviewed = false;
  });

  group('membership', () {
    test('a film in the seen list reads as seen', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      expect(inception().isSeen(), isTrue);
    });

    test('a film that is not in the seen list does not', () {
      user.seenMovies = [
        ['Movies', '603'],
      ];

      expect(inception().isSeen(), isFalse);
    });

    test('a show with the same id does not make the film read as seen', () {
      // Ids are only unique within a type, so a show and a film can share one.
      user.seenMovies = [
        ['TVShows', '27205'],
      ];

      expect(inception().isSeen(), isFalse);
    });

    test('an id stored as a number still matches', () {
      // The lists are written from Firestore, which hands numbers back as
      // numbers, while the id on the object is always a string.
      user.watchlist = [
        ['Movies', 27205],
      ];

      expect(inception().isBookmarked(), isTrue);
    });

    test('the favourites list drives isFavorite alone', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      expect(inception().isFavorite(), isFalse);

      user.favMovies = [
        ['Movies', '27205'],
      ];

      expect(inception().isFavorite(), isTrue);
    });
  });

  group('getData', () {
    test('returns the decoded film', () async {
      final http = installHttpStub();
      http.on('/movie/27205', json: {'id': 27205, 'title': 'Inception'});

      expect(await inception().getData(), {'id': 27205, 'title': 'Inception'});
    });

    test('returns nothing rather than throwing when TMDB refuses', () async {
      // Callers render this straight into a tile, so an empty map degrades to
      // a blank tile where an exception would take the whole screen down.
      final http = installHttpStub();
      http.on('/movie/27205', status: 404, body: '');

      expect(await inception().getData(), isEmpty);
    });
  });

  group('getExtendedData', () {
    late HttpStub http;

    setUp(() {
      http = installHttpStub();
      http.on('27205-Inception?', json: {
        'id': 27205,
        'title': 'Inception',
        'imdb_id': 'tt1375666',
        'backdrop_path': '/backdrop.jpg',
      });
      http.on('omdbLookup',
          json: {'result': {'imdbRating': '8.8', 'Year': '2010'}});
      http.on('watch/providers', json: {'results': <String, dynamic>{}});
      http.on('/credits?', json: {'cast': [], 'crew': []});
      http.on('/videos?', json: {'results': []});
    });

    test('the rating and year come from OMDB, not the placeholders', () async {
      // Both are set to "0.0" and "None" before the second fetch, so a
      // regression that dropped the merge would leave those in place.
      final json = await inception().getExtendedData();

      expect(json['imdb_rating'], '8.8');
      expect(json['year'], '2010');
    });

    test('a film seen once but never re-logged counts as seen once', () async {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      expect((await inception().getExtendedData())['times_seen'], 1);
    });

    test('an unseen film counts as seen zero times', () async {
      expect((await inception().getExtendedData())['times_seen'], 0);
    });

    test('a rewatch count overrides the seen list', () async {
      user.seenMovies = [
        ['Movies', '27205'],
      ];
      user.rewatchedMovies = {'27205': 3};

      expect((await inception().getExtendedData())['times_seen'], 3);
    });

    test('the review is only attached when one is being shown', () async {
      user.reviews = {
        '27205': {'Opinion': 'Dreams within dreams', 'Rating': '5'}
      };

      expect((await inception().getExtendedData())['review'], isNull);

      app.reviewed = true;

      expect(
        (await inception().getExtendedData())['review'],
        {'Opinion': 'Dreams within dreams', 'Rating': '5'},
      );
    });

    test('the dates it was watched come back newest first', () async {
      user.calendar = {
        '2024-01-05': [
          {'id': '27205', 'type': 'movie', 'friends': []},
        ],
        '2024-03-09': [
          {'id': '27205', 'type': 'movie', 'friends': ['friend-uid']},
        ],
        '2024-02-01': [
          {'id': '603', 'type': 'movie', 'friends': []},
        ],
      };

      expect((await inception().getExtendedData())['seen_dates'], [
        ['2024-03-09', ['friend-uid']],
        ['2024-01-05', []],
      ]);
    });

    test('a film with no backdrop gets an empty one, not a null', () async {
      http.on('27205-Inception?', json: {
        'id': 27205,
        'title': 'Inception',
        'imdb_id': 'tt1375666',
        'backdrop_path': null,
      });

      expect((await inception().getExtendedData())['backdrop_path'], '');
    });

    test('punctuation in the title becomes a dash each, spaces included',
        () async {
      // The slug is part of the URL TMDB is asked for, so the exact rule
      // matters: every character that is not a letter, digit or space becomes
      // one dash, and only then do spaces become dashes too. "Wall·E: A Story"
      // therefore has a double dash where the colon and the space met.
      http.on('/movie/1-Wall-E--A-Story?', json: {'id': 1, 'imdb_id': null});

      await Movie(id: '1', title: 'Wall·E: A Story', coverPhoto: '')
          .getExtendedData();

      expect(http.countFor('/movie/1-Wall-E--A-Story?'), 1);
    });
  });

  group('removeFriend', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = installFakeFirestore();
    });

    Future<void> seedBothSides() async {
      await seedUserDoc(firestore, 'test-uid', 'SeenWith', {
        'Movies': {
          '27205': {
            'friends': ['friend-uid', 'other-uid']
          }
        }
      });
      await seedUserDoc(firestore, 'friend-uid', 'SeenWith', {
        'Movies': {
          '27205': {
            'friends': ['test-uid']
          }
        }
      });
      user.seenWith = {
        'friend-uid': {
          'Movies': ['27205'],
          'TVShows': [],
        }
      };
    }

    test('the friend is dropped from the user record', () async {
      await seedBothSides();

      await inception().removeFriend('friend-uid', []);

      final doc = await firestore.collection('test-uid').doc('SeenWith').get();
      expect(doc.data()!['Movies']['27205']['friends'], ['other-uid']);
    });

    test('and the user is dropped from the friend record', () async {
      // Only removing one side leaves the film showing on the friend's profile
      // as watched together after the user says it was not.
      await seedBothSides();

      await inception().removeFriend('friend-uid', []);

      final doc =
          await firestore.collection('friend-uid').doc('SeenWith').get();
      expect(doc.data()!['Movies']['27205']['friends'], isEmpty);
    });

    test('the in-memory copy is updated so the screen reflects it', () async {
      await seedBothSides();

      await inception().removeFriend('friend-uid', []);

      expect(user.seenWith['friend-uid']['Movies'], isEmpty);
    });

    test('other films watched with the same friend are untouched', () async {
      await seedUserDoc(firestore, 'test-uid', 'SeenWith', {
        'Movies': {
          '27205': {
            'friends': ['friend-uid']
          },
          '603': {
            'friends': ['friend-uid']
          },
        }
      });
      await seedUserDoc(firestore, 'friend-uid', 'SeenWith', {
        'Movies': {
          '27205': {
            'friends': ['test-uid']
          },
          '603': {
            'friends': ['test-uid']
          },
        }
      });
      user.seenWith = {
        'friend-uid': {
          'Movies': ['27205', '603'],
          'TVShows': [],
        }
      };

      await inception().removeFriend('friend-uid', []);

      final doc = await firestore.collection('test-uid').doc('SeenWith').get();
      expect(doc.data()!['Movies']['603']['friends'], ['friend-uid']);
      expect(user.seenWith['friend-uid']['Movies'], ['603']);
    });
  });
}
