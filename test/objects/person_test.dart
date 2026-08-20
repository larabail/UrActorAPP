/// Tests for the person screen's data layer.
///
/// The two scoring functions are the reason this file exists. They decide the
/// order of the favourite actors, directors and writers lists, and they are
/// pure -- a user and a list of credits in, two numbers out -- so they can be
/// checked exactly rather than eyeballed on a screen. Everything else here
/// covers the filtering that decides which credits reach them at all.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/objects/person.dart';
import 'package:uractor/objects/user.dart';

import '../support/harness.dart';

/// A credit as TMDB returns it, trimmed to the fields the filters read.
Map<String, dynamic> credit(
  Object id, {
  String? poster = '/poster.jpg',
  String character = 'Someone',
  String? job,
}) {
  return {
    'id': id,
    'poster_path': poster,
    if (job == null) 'character': character,
    if (job != null) 'job': job,
  };
}

void main() {
  late AppUser user;

  setUp(() {
    user = installTestUser();
  });

  Person personUnderTest() =>
      Person(id: '287', name: 'Brad Pitt', data: const {});

  group('getCastStats', () {
    test('a film that was seen counts once and scores two', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [2, 1],
      );
    });

    test('a favourite adds three on top of the two for having seen it', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];
      user.favMovies = [
        ['Movies', '27205'],
      ];

      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [5, 1],
      );
    });

    test('a rewatched film scores once per watch', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];
      user.rewatchedMovies = {'27205': 4};

      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [4, 1],
      );
    });

    test('a single recorded watch still scores the flat two', () {
      // Rewatched is written with a count of 1 the first time a film is
      // logged, so the map holding the id is not on its own evidence of a
      // rewatch and must not score less than a film absent from it.
      user.seenMovies = [
        ['Movies', '27205'],
      ];
      user.rewatchedMovies = {'27205': 1};

      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [2, 1],
      );
    });

    test('two credits on the same film score and count once', () {
      // TMDB lists an actor twice when they play two parts. That is one film
      // watched, not two.
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      expect(
        personUnderTest().getCastStats(
          user,
          [credit(27205, character: 'Cobb'), credit(27205, character: 'Mal')],
          'Movies',
        ),
        [2, 1],
      );
    });

    test('a film only on the watchlist scores one and counts nothing', () {
      user.watchlist = [
        ['Movies', '27205'],
      ];

      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [1, 0],
      );
    });

    test('a film in neither list scores nothing', () {
      expect(
        personUnderTest().getCastStats(user, [credit(27205)], 'Movies'),
        [0, 0],
      );
    });

    test('a TV credit is scored against the TV lists, not the film ones', () {
      // The film lists are deliberately seeded with the same id, so a function
      // that read the wrong pair would still score and this would pass for the
      // wrong reason. Only the TV entry should count.
      user.seenMovies = [
        ['Movies', '1396'],
      ];
      user.favMovies = [
        ['Movies', '1396'],
      ];
      user.seenTVShows = [
        ['TVShows', '1396'],
      ];

      expect(
        personUnderTest().getCastStats(user, [credit(1396)], 'TVShows'),
        [2, 1],
      );
    });
  });

  group('getCrewStats', () {
    test('directing a film that was seen scores and counts as directing', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      final stats = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Director')], 'Movies');

      expect(stats[0], 2, reason: 'director score');
      expect(stats[1], 1, reason: 'directed and seen');
      expect(stats[2], 1, reason: 'films directed at all');
      expect(stats[3], 0, reason: 'writer score');
      expect(stats[4], 0, reason: 'written and seen');
    });

    test('a film they directed but that was never seen still counts as theirs',
        () {
      final stats = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Director')], 'Movies');

      expect(stats[1], 0, reason: 'nothing was seen');
      expect(stats[2], 1, reason: 'the film is still one they directed');
    });

    test('a screenplay credit scores as writing, not as directing', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      final stats = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Screenplay')], 'Movies');

      expect(stats[0], 0, reason: 'director score');
      expect(stats[3], 2, reason: 'writer score');
      expect(stats[4], 1, reason: 'written and seen');
    });

    test('directing a favourite that was rewatched scores for both', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];
      user.favMovies = [
        ['Movies', '27205'],
      ];
      user.rewatchedMovies = {'27205': 3};

      final stats = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Director')], 'Movies');

      expect(stats[0], 6, reason: '3 for the favourite plus 3 rewatches');
    });

    test('a queued film scores one for its director and nothing for its writer',
        () {
      user.watchlist = [
        ['Movies', '27205'],
      ];

      final directing = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Director')], 'Movies');
      final writing = personUnderTest()
          .getCrewStats(user, [credit(27205, job: 'Writer')], 'Movies');

      expect(directing[0], 1);
      expect(directing[1], 0, reason: 'queued is not seen');
      expect(writing[3], 1);
    });

    test('a job the app does not score is ignored', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      final stats = personUnderTest().getCrewStats(
          user, [credit(27205, job: 'Director of Photography')], 'Movies');

      expect(stats[0], 0);
      expect(stats[3], 0);
      expect(stats[2], 0, reason: 'not a directing credit');
    });

    test('two jobs on one film are merged into a single credit', () {
      // Otherwise the screen lists the same film twice, once per job, instead
      // of once reading "Director / Writer".
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      final stats = personUnderTest().getCrewStats(
        user,
        [credit(27205, job: 'Director'), credit(27205, job: 'Writer')],
        'Movies',
      );

      final merged = stats[5] as List;
      expect(merged, hasLength(1));
      expect(merged.single['job'], 'Director / Writer');
      expect(stats[1], 1, reason: 'still one film directed and seen');
      expect(stats[4], 1, reason: 'and one film written and seen');
    });

    test('the same job twice on one film is only scored once', () {
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      final stats = personUnderTest().getCrewStats(
        user,
        [credit(27205, job: 'Director'), credit(27205, job: 'Director')],
        'Movies',
      );

      expect(stats[0], 2, reason: 'one film, scored once');
      expect(stats[1], 1);
      expect(stats[2], 1);
    });
  });

  group('getCastCredits', () {
    late HttpStub http;

    setUp(() {
      http = installHttpStub();
      http.on('/person/287-Brad-Pitt?', json: {'name': 'Brad Pitt'});
    });

    void stubCredits({
      List<Map<String, dynamic>> movieCast = const [],
      List<Map<String, dynamic>> movieCrew = const [],
      List<Map<String, dynamic>> tvCast = const [],
      List<Map<String, dynamic>> tvCrew = const [],
    }) {
      http.on('/person/287-Brad-Pitt/movie_credits',
          json: {'cast': movieCast, 'crew': movieCrew});
      http.on('/person/287-Brad-Pitt/tv_credits',
          json: {'cast': tvCast, 'crew': tvCrew});
    }

    test('drops appearances as themselves, archive footage and walk-ons',
        () async {
      // These are the credits that make a filmography look padded: talk show
      // appearances, clips reused in a documentary, and unbilled cameos.
      stubCredits(movieCast: [
        credit(1, character: 'Tyler Durden'),
        credit(2, character: 'Self'),
        credit(3, character: 'Himself - Guest'),
        credit(4, character: 'Tyler Durden (archived footage)'),
        credit(5, character: 'Man in bar (uncredited)'),
        credit(6, character: ''),
        credit(7, character: 'Detective', poster: null),
      ]);

      final json = await personUnderTest().getCastCredits();

      expect(
        (json['movie_credits_cast'] as List).map((c) => c['id']),
        [1],
      );
    });

    test('keeps every crew credit except a thanks', () async {
      stubCredits(movieCrew: [
        credit(1, job: 'Producer'),
        credit(2, job: 'Thanks'),
        credit(3, job: 'Director', poster: null),
      ]);

      final json = await personUnderTest().getCastCredits();

      expect(
        (json['movie_credits_crew'] as List).map((c) => c['id']),
        [1],
      );
    });

    test('a TV appearance as themselves is dropped, an archive clip is not',
        () async {
      // Television is filtered less strictly than film on purpose: a recurring
      // role is often billed with a qualifier that the film filter would throw
      // away. Only "self" and a blank part are dropped.
      stubCredits(tvCast: [
        credit(1, character: 'Rusty'),
        credit(2, character: 'Self'),
        credit(3, character: 'Rusty (archived footage)'),
        credit(4, character: ''),
        credit(5, character: 'Rusty', poster: null),
      ]);

      final json = await personUnderTest().getCastCredits();

      expect(
        (json['tv_credits_cast'] as List).map((c) => c['id']),
        [1, 3],
      );
    });

    test('a TV crew credit only needs a poster', () async {
      stubCredits(tvCrew: [
        credit(1, job: 'Thanks'),
        credit(2, job: 'Executive Producer', poster: null),
      ]);

      final json = await personUnderTest().getCastCredits();

      expect(
        (json['tv_credits_crew'] as List).map((c) => c['id']),
        [1],
      );
    });

    test('punctuation in a name is stripped out of the request path',
        () async {
      final http = installHttpStub();
      http.on('/person/1-Joseph-Gordon-Levitt?', json: {'name': 'JGL'});
      http.on('/movie_credits', json: {'cast': [], 'crew': []});
      http.on('/tv_credits', json: {'cast': [], 'crew': []});

      await Person(id: '1', name: 'Joseph Gordon-Levitt', data: const {})
          .getCastCredits();

      expect(http.countFor('/person/1-Joseph-Gordon-Levitt?'), 1);
    });

    test('a failed person lookup returns no credits rather than partial ones',
        () async {
      final http = installHttpStub();
      http.on('/person/287-Brad-Pitt?', status: 500, json: {'status': 'nope'});

      final json = await personUnderTest().getCastCredits();

      expect(json.containsKey('movie_credits_cast'), isFalse);
      expect(json.containsKey('tv_credits_cast'), isFalse);
      expect(http.countFor('/movie_credits'), 0);
    });
  });

  group('getSimpleData', () {
    test('asks TMDB in the language the user reads', () async {
      final user = installTestUser(settings: {'language': 'es'});
      final http = installHttpStub();
      http.on('/person/287', json: {'name': 'Brad Pitt'});

      final json = await Person(id: '287', name: user.userName, data: const {})
          .getSimpleData();

      expect(json['name'], 'Brad Pitt');
      expect(http.requests.single.toString(), contains('language=es'));
    });

    test('throws rather than returning an empty person on failure', () async {
      final http = installHttpStub();
      http.on('/person/287', status: 404, body: '');

      await expectLater(personUnderTest().getSimpleData(), throwsException);
    });
  });

  group('updateStatsDoc', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = installFakeFirestore();
    });

    test('ranks the person against everyone else in the document', () async {
      await seedUserDoc(firestore, user.uid, 'FavActors', {
        '1': 30,
        '2': 10,
      });

      final rank =
          await personUnderTest().updateStatsDoc(20, user, 'FavActors');

      expect(rank, 2, reason: 'between the 30 and the 10');
    });

    test('a new best score ranks first', () async {
      await seedUserDoc(firestore, user.uid, 'FavActors', {'1': 30});

      expect(await personUnderTest().updateStatsDoc(31, user, 'FavActors'), 1);
    });

    test('the score is written back, not just compared', () async {
      await personUnderTest().updateStatsDoc(7, user, 'FavDirectors');

      final doc =
          await firestore.collection(user.uid).doc('FavDirectors').get();
      expect(doc.data(), {'287': 7});
    });

    test('a re-scored person is ranked on the new score, not the old one',
        () async {
      await seedUserDoc(firestore, user.uid, 'FavActors', {
        '287': 1,
        '1': 30,
      });

      expect(await personUnderTest().updateStatsDoc(40, user, 'FavActors'), 1);
    });
  });

  group('fetchNewStats', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = installFakeFirestore();
    });

    test('reloads all three lists best first', () async {
      await seedUserDoc(firestore, user.uid, 'FavActors', {'1': 5, '2': 50});
      await seedUserDoc(firestore, user.uid, 'FavDirectors', {'3': 7});
      await seedUserDoc(firestore, user.uid, 'FavWriters', {'4': 2, '5': 9});

      await personUnderTest().fetchNewStats(user);

      expect(user.favActors, [
        [50, '2'],
        [5, '1'],
      ]);
      expect(user.favDirectors, [
        [7, '3'],
      ]);
      expect(user.favWriters, [
        [9, '5'],
        [2, '4'],
      ]);
    });

    test('a list that no longer has a document is emptied, not left stale',
        () async {
      user.favActors = [
        [99, 'someone-who-was-removed'],
      ];

      await personUnderTest().fetchNewStats(user);

      expect(user.favActors, isEmpty);
    });
  });

  group('getPersonData', () {
    late FakeFirebaseFirestore firestore;
    late HttpStub http;

    setUp(() {
      firestore = installFakeFirestore();
      http = installHttpStub();
      http.on('/person/287-Brad-Pitt?', json: {'name': 'Brad Pitt'});
      http.on('/movie_credits', json: {
        'cast': [credit(1, character: 'Tyler Durden')],
        'crew': [credit(2, job: 'Director')],
      });
      http.on('/tv_credits', json: {'cast': [], 'crew': []});
    });

    test('rolls film and television into one score per role', () async {
      user.seenMovies = [
        ['Movies', '1'],
        ['Movies', '2'],
      ];

      final person = personUnderTest();
      await person.getPersonData(user, {});

      expect(person.personStats['scoreActor'], 2);
      expect(person.personStats['scoreDirector'], 2);
      expect(person.personStats['stats'], 1, reason: 'films acted in and seen');
      expect(person.personStats['stats_dir'], 1);
      expect(person.personStats['allDirMovies'], 1);
    });

    test('the rankings it returns are the ones now stored', () async {
      final json = await personUnderTest().getPersonData(user, {});

      expect(json['actor_ranking'], 1);
      expect(json['director_ranking'], 1);
      expect(json['writer_ranking'], 1);
      final doc = await firestore.collection(user.uid).doc('FavActors').get();
      expect(doc.data(), {'287': 0});
    });

    test('awards are regrouped by film so the screen can list them', () async {
      final json = await personUnderTest().getPersonData(user, {
        '287': {
          'num_oscars': 2,
          'oscars': {
            '1995': [
              {'movie': '12 Monkeys', 'oscar': 'Best Supporting Actor'},
            ],
            '2019': [
              {
                'movie': 'Once Upon a Time in Hollywood',
                'oscar': 'Best Supporting Actor'
              },
              {
                'movie': 'ONCE UPON A TIME IN HOLLYWOOD',
                'oscar': 'Best Picture'
              },
            ],
          },
        },
      });

      expect(json['num_oscars'], 2);
      expect(json['oscars'], {
        '12 monkeys': ['Best Supporting Actor'],
        'once upon a time in hollywood': [
          'Best Supporting Actor',
          'Best Picture',
        ],
      });
    });

    test('a person with no awards gets an empty set, not a missing key',
        () async {
      final json = await personUnderTest().getPersonData(user, {
        '999': {'num_oscars': 1, 'oscars': <String, dynamic>{}},
      });

      expect(json['num_oscars'], 0);
      expect(json['oscars'], isEmpty);
    });
  });
}
