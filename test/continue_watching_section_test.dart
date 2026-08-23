import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/continue_watching.dart';
import 'package:uractor/continue_watching_section.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late HttpStub http;

  const uid = 'test-uid';

  setUp(() {
    installTestUser(uid: uid);
    firestore = installFakeFirestore();
    http = installHttpStub();
  });

  Future<void> seedProgress({
    Map<String, dynamic> movies = const <String, dynamic>{},
    Map<String, dynamic> shows = const <String, dynamic>{},
  }) {
    return seedUserDoc(firestore, uid, 'Progress', {
      'Movies': movies,
      'TVShows': shows,
    });
  }

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: ContinueWatchingSection()),
        ),
      ),
    );
    // The progress read, the TMDB lookup and the next-episode read are three
    // chained futures, so a single pump is not enough to see the finished row.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('nothing in progress hides the section entirely', (tester) async {
    await seedProgress();

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue watching'), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    // No heading, no placeholder, and no request for a title to put in one.
    expect(http.requests, isEmpty);
    expect(
      tester.getSize(find.byType(ContinueWatchingSection)),
      Size.zero,
    );
  });

  testWidgets('a progress document that was never written hides the section',
      (tester) async {
    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue watching'), findsNothing);
  });

  testWidgets('a finished title alone still hides the section', (tester) async {
    await seedProgress(
      movies: {
        '27205': {
          'started': '2026-01-01',
          'finished': '2026-01-02',
          'updated': '2026-01-02',
        },
      },
    );

    await pumpSection(tester);

    expect(find.text('Continue watching'), findsNothing);
  });

  testWidgets('started titles show newest first, with the next episode',
      (tester) async {
    await seedProgress(
      movies: {
        '27205': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
      shows: {
        '1399': {
          'started': '2026-01-03',
          'updated': '2026-01-04',
          'episodes': {
            '1': [1, 2],
          },
        },
      },
    );
    http.on('/3/movie/27205', json: {
      'id': 27205,
      'title': 'Inception',
      'poster_path': '/inception.jpg',
    });
    http.on('/3/tv/1399', json: {
      'id': 1399,
      'name': 'Severance',
      'poster_path': '/severance.jpg',
      'seasons': [
        {'season_number': 0, 'episode_count': 2},
        {'season_number': 1, 'episode_count': 3},
      ],
    });

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue watching'), findsOneWidget);
    // Season 1 episodes 1 and 2 are watched, and the specials season is not
    // counted, so the show resumes at S1 E3.
    expect(find.text('Next: S1 E3'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('continueWatching-TVShows-1399')))
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('continueWatching-Movies-27205')),
            )
            .dx,
      ),
    );
    // A movie has no episode to name, so it gets no second line.
    expect(find.textContaining('Next:'), findsOneWidget);
  });

  testWidgets('an id TMDB no longer resolves stays readable and inert',
      (tester) async {
    await seedProgress(
      movies: {
        '404': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/movie/404', status: 404, body: '');

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    final tile = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('continueWatching-Movies-404')),
    );
    // Opening a detail page for an id TMDB has never heard of is what leaves
    // the user staring at an empty screen, so the tile does not respond.
    expect(tile.onTap, isNull);
    expect(http.countFor('/3/movie/404'), 1);
    expect(http.countFor('/3/tv/404'), 0);
  });

  testWidgets('a show whose payload carries no seasons still renders',
      (tester) async {
    await seedProgress(
      shows: {
        '77': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/77', json: {'id': 77, 'name': 'Seasonless', 'seasons': null});

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Seasonless'), findsOneWidget);
    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('a viewer who joined late resumes where they are, not at S1 E1',
      (tester) async {
    // University Challenge, in effect: seasons 1 and 2 were never watched and
    // are not going to be. Sending this viewer back to the first episode is
    // the bug — the only useful answer is the one after where they stopped.
    await seedProgress(
      shows: {
        '2316': {
          'started': '2026-01-03',
          'updated': '2026-01-04',
          'episodes': {
            '3': [1, 2],
          },
        },
      },
    );
    http.on('/3/tv/2316', json: {
      'id': 2316,
      'name': 'University Challenge',
      'seasons': [
        {'season_number': 1, 'episode_count': 4},
        {'season_number': 2, 'episode_count': 4},
        {'season_number': 3, 'episode_count': 4},
      ],
    });

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Next: S3 E3'), findsOneWidget);
    expect(find.text('Next: S1 E1'), findsNothing);
  });

  testWidgets('a viewer with nothing left ahead is told they are caught up',
      (tester) async {
    // The final season is finished but earlier seasons never were, so the show
    // is still in progress. There is no next episode to name, and naming one
    // from the backlog would be the same lie in the other direction.
    await seedProgress(
      shows: {
        '2316': {
          'started': '2026-01-03',
          'updated': '2026-01-04',
          'episodes': {
            '2': [1, 2],
          },
        },
      },
    );
    http.on('/3/tv/2316', json: {
      'id': 2316,
      'name': 'University Challenge',
      'seasons': [
        {'season_number': 1, 'episode_count': 2},
        {'season_number': 2, 'episode_count': 2},
      ],
    });

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Caught up'), findsOneWidget);
    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('a long backlog is capped instead of storming TMDB',
      (tester) async {
    await seedProgress(
      movies: {
        for (var index = 0; index < 25; index++)
          '$index': {
            'started': '2026-01-01',
            // Descending dates so the newest ids land at the front.
            'updated': '2026-02-${(25 - index).toString().padLeft(2, '0')}',
          },
      },
    );
    http.on('/3/movie/', json: {'id': 1, 'title': 'Any', 'poster_path': null});

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Continue watching'), findsOneWidget);
    // The row is capped whether or not laziness happens to save the requests.
    expect(
      tester.widget<ListView>(find.byType(ListView)).semanticChildCount,
      kContinueWatchingLimit,
    );
    expect(http.requests.length, lessThanOrEqualTo(kContinueWatchingLimit));
  });

  group('list membership badges', () {
    testWidgets('a resumable title carries the badges for its lists',
        (tester) async {
      final user = installTestUser(uid: uid);
      user.favMovies = [
        ['Movies', '27205'],
      ];
      user.watchlist = [
        ['Movies', '27205'],
      ];
      firestore = installFakeFirestore();
      await seedProgress(
        movies: {
          '27205': {'started': '2026-01-01', 'updated': '2026-01-02'},
        },
      );
      http.on('/3/movie/27205', json: {
        'id': 27205,
        'title': 'Inception',
        'poster_path': null,
      });

      await pumpSection(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('a title on neither list carries no badge', (tester) async {
      await seedProgress(
        movies: {
          '27205': {'started': '2026-01-01', 'updated': '2026-01-02'},
        },
      );
      http.on('/3/movie/27205', json: {
        'id': 27205,
        'title': 'Inception',
        'poster_path': null,
      });

      await pumpSection(tester);

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });

    testWidgets('a show is matched against the TV lists, not the movie ones',
        (tester) async {
      // The two lists are keyed by type, so a show sharing an id with a
      // favourited movie must not inherit its badge.
      final user = installTestUser(uid: uid);
      user.favMovies = [
        ['Movies', '1399'],
      ];
      user.watchlistTVShows = [
        ['TVShows', '1399'],
      ];
      firestore = installFakeFirestore();
      await seedProgress(
        shows: {
          '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
        },
      );
      http.on('/3/tv/1399', json: {
        'id': 1399,
        'name': 'Severance',
        'poster_path': null,
        'seasons': null,
      });

      await pumpSection(tester);

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('an unresolvable title still shows what lists it is on',
        (tester) async {
      // The pair comes from the progress entry rather than the item map, so a
      // tile that fell back to the placeholder — where there is no name left to
      // infer a type from — is still badged. It can no longer be opened, but
      // its membership is true and is the more useful thing to say.
      final user = installTestUser(uid: uid);
      user.favMovies = [
        ['Movies', '404'],
      ];
      firestore = installFakeFirestore();
      await seedProgress(
        movies: {
          '404': {'started': '2026-01-01', 'updated': '2026-01-02'},
        },
      );
      http.on('/3/movie/404', status: 404, body: '');

      await pumpSection(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });
  });

  testWidgets('the section reads in Spanish too', (tester) async {
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/1399', json: {
      'id': 1399,
      'name': 'Severance',
      'seasons': [
        {'season_number': 1, 'episode_count': 3},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: ContinueWatchingSection()),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Seguir viendo'), findsOneWidget);
    expect(find.text('Siguiente: T1 E1'), findsOneWidget);
  });
}
