import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/friends_service.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart';
import 'package:uractor/watching_together_section.dart';

import 'support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late HttpStub http;

  const uid = 'test-uid';

  setUp(() {
    installTestUser(uid: uid);
    firestore = installFakeFirestore();
    http = installHttpStub();
    // The service caches profiles for the session, so a name seeded by one
    // test would otherwise show up in the next one.
    FriendsService.clearCache();
    addTearDown(FriendsService.clearCache);
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

  Future<void> seedFriend(String friendUid, String userName) {
    return seedUserDoc(firestore, friendUid, 'Settings', {
      'username': userName,
      'profile_photo': '',
    });
  }

  /// Puts [friends] on the signed-in user and records the shows each of them
  /// was watched with, in the shape `AppUser` builds from the SeenWith
  /// document.
  void seedSeenWith(Map<String, List<String>> showsByFriend) {
    currentUser.friends = showsByFriend.keys.toList();
    currentUser.seenWith = <String, dynamic>{
      for (final entry in showsByFriend.entries)
        entry.key: <String, dynamic>{
          'Movies': <String>[],
          'TVShows': entry.value,
        },
    };
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    String friend = 'ana',
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WatchingTogetherSection.forFriend(friend),
          ),
        ),
      ),
    );
    // The progress read, the profile reads, the TMDB lookup and the
    // next-episode read are chained futures, so a single pump is not enough to
    // see the finished row.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('nothing shared and unfinished hides the section entirely',
      (tester) async {
    seedSeenWith({'ana': <String>[]});
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Watching together'), findsNothing);
    // No heading, no placeholder, and no request for a title to put in one.
    expect(http.requests, isEmpty);
    expect(tester.getSize(find.byType(WatchingTogetherSection)), Size.zero);
  });

  testWidgets('a user with no friends hides the section', (tester) async {
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );

    await pumpSection(tester);

    expect(find.text('Watching together'), findsNothing);
    expect(http.requests, isEmpty);
  });

  testWidgets('a show finished together is no longer being watched together',
      (tester) async {
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '1399': {
          'started': '2026-01-01',
          'finished': '2026-01-05',
          'updated': '2026-01-05',
        },
      },
    );

    await pumpSection(tester);

    expect(find.text('Watching together'), findsNothing);
  });

  testWidgets('a shared show in progress names where to resume',
      (tester) async {
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '1399': {
          'started': '2026-01-01',
          'updated': '2026-01-04',
          'episodes': {
            '1': [1, 2],
          },
        },
      },
    );
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
    expect(find.text('Watching together'), findsOneWidget);
    // Season 1 episodes 1 and 2 are watched, and the specials season is not
    // counted, so the show resumes at S1 E3.
    expect(find.text('Next: S1 E3'), findsOneWidget);
  });

  testWidgets('a movie watched together never reaches the row', (tester) async {
    currentUser.friends = ['ana'];
    currentUser.seenWith = <String, dynamic>{
      'ana': <String, dynamic>{
        'Movies': ['27205'],
        'TVShows': <String>[],
      },
    };
    await seedFriend('ana', 'Ana');
    await seedProgress(
      movies: {
        '27205': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );

    await pumpSection(tester);

    expect(find.text('Watching together'), findsNothing);
    expect(http.countFor('/3/movie/27205'), 0);
  });

  testWidgets('shows newest activity first', (tester) async {
    seedSeenWith({
      'ana': ['1399', '66732'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
        '66732': {'started': '2026-01-01', 'updated': '2026-03-02'},
      },
    );
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
    http.on('/3/tv/66732', json: {'id': 66732, 'name': 'Stranger Things'});

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('watchingTogether-66732'))).dx,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('watchingTogether-1399')))
            .dx,
      ),
    );
  });

  testWidgets('draws only the shows shared with this friend', (tester) async {
    // The page already says whose profile it is, so the tiles never repeat the
    // name; scoping is the whole of what the friend uid does here.
    seedSeenWith({
      'ana': ['1399'],
      'luis': ['66732'],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
        '66732': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Severance'), findsOneWidget);
    // The other friend's show belongs to the other profile.
    expect(http.countFor('/3/tv/66732'), 0);
  });

  testWidgets('a show shared with two friends appears on either profile',
      (tester) async {
    seedSeenWith({
      'ana': ['1399'],
      'luis': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpSection(tester, friend: 'luis');

    expect(find.byKey(const ValueKey('watchingTogether-1399')), findsOneWidget);
    expect(http.countFor('/3/tv/1399'), 1);
  });

  testWidgets('an id TMDB no longer resolves stays readable and inert',
      (tester) async {
    seedSeenWith({
      'ana': ['404'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '404': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/404', status: 404, body: '');

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Watching together'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    final tile = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('watchingTogether-404')),
    );
    // Opening a detail page for an id TMDB has never heard of is what leaves
    // the user staring at an empty screen, so the tile does not respond.
    expect(tile.onTap, isNull);
  });

  testWidgets('a title on the watchlist carries its badge', (tester) async {
    final user = installTestUser(uid: uid);
    user.watchlistTVShows = [
      ['TVShows', '1399'],
    ];
    firestore = installFakeFirestore();
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress(
      shows: {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    );
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpSection(tester);

    expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
  });

  testWidgets('the section reads in Spanish too', (tester) async {
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
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

    await pumpSection(tester, locale: const Locale('es'));

    expect(find.text('Viendo juntos'), findsOneWidget);
    expect(find.text('Siguiente: T1 E1'), findsOneWidget);
  });
}
