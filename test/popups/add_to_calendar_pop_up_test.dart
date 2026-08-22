/// Tests for the two calendar dialogues.
///
/// Logging what you watched is the app's central act, and it fans out further
/// than anything else: the entry lands on the user's calendar, on every tagged
/// friend's calendar, on both seen lists, on the rewatch counter and on the
/// seen-with record. These cover that fan-out, and the season and episode a
/// show entry may carry, which older entries do not have and must not gain.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/add_to_calendar_pop_up.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  late HttpStub http;

  setUp(() async {
    firestore = installFakeFirestore();
    user = installTestUser();
    http = installHttpStub();
    installFakeCallableContext();
    // The seen-with record is read inside a transaction that refuses to
    // create it, so an account that has never tagged anyone must still have
    // the document. Every real account does.
    await seedUserDoc(firestore, 'test-uid', 'SeenWith', {
      'Movies': <String, dynamic>{},
      'TVShows': <String, dynamic>{},
    });
    http.on('/search/movie', json: {
      'results': [
        {'id': 27205, 'title': 'Inception', 'poster_path': '/inception.jpg'},
      ]
    });
    http.on('/search/tv', json: {
      'results': [
        {'id': 1396, 'name': 'Breaking Bad', 'poster_path': '/bb.jpg'},
      ]
    });
    // What getExtendedData needs, for either kind of title.
    http.on('27205-Inception?',
        json: {'id': 27205, 'imdb_id': 'tt1375666', 'runtime': 148});
    http.on('1396-Breaking-Bad?', json: {'id': 1396});
    http.on('/external_ids', json: {'imdb_id': 'tt0903747'});
    http.on('omdbLookup', json: {
      'result': {'imdbRating': '8.8', 'Year': '2010'}
    });
    http.on('watch/providers', json: {'results': <String, dynamic>{}});
    http.on('/credits?', json: {'cast': [], 'crew': []});
    // A show reaches for `/aggregate_credits` instead, which spans every
    // season rather than just the newest one.
    http.on('/aggregate_credits?', json: {'cast': [], 'crew': []});
    http.on('/videos?', json: {'results': []});
  });

  Future<void> addFriend(String uid, String username) async {
    user.friends = [...user.friends, uid];
    await seedUserDoc(firestore, uid, 'Settings', {
      'username': username,
      'profile_photo': '',
    });
    await seedUserDoc(firestore, uid, 'SeenWith', {
      'Movies': <String, dynamic>{},
      'TVShows': <String, dynamic>{},
    });
  }

  Future<void> pump(WidgetTester tester, Widget dialog) async {
    ignoreNetworkImageFailures();
    usePhoneSurface(tester, size: const Size(560, 1400));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDialog<bool>(context: context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>?> calendarOf(String uid) async {
    final doc = await firestore.collection(uid).doc('Calendar').get();
    return doc.data();
  }

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
  }

  group('logging something from the calendar', () {
    Widget dialogue({String type = 'movie', String range = ''}) =>
        CalendarAddDialogue(
          dateForMap: range.isEmpty ? '2024-03-09' : '',
          dateRange: range,
          type: type,
        );

    Future<void> searchAndPick(
        WidgetTester tester, String label, String term) async {
      await tester.enterText(find.widgetWithText(TextFormField, label), term);
      await tester.pumpAndSettle();
    }

    const movieLabel = 'Name of The Movie You\'d Like to Add';
    const showLabel = 'Name of The Show You\'d Like to Add';

    testWidgets('a film search and a show search hit different endpoints',
        (tester) async {
      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');

      expect(http.countFor('/search/movie'), greaterThan(0));
      expect(http.countFor('/search/tv'), 0);
      expect(find.text('Add a Movie'), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('a show is searched on the TV endpoint', (tester) async {
      await pump(tester, dialogue(type: 'series'));
      await searchAndPick(tester, showLabel, 'breaking bad');

      expect(http.countFor('/search/tv'), greaterThan(0));
      expect(http.countFor('/search/movie'), 0);
      expect(find.text('Add a Show'), findsOneWidget);
      expect(find.text('Breaking Bad'), findsOneWidget);
    });

    testWidgets('a film is not asked which episode it was', (tester) async {
      // A film has no season, and offering the boxes anyway invites entries
      // that no screen can display.
      await pump(tester, dialogue());

      expect(find.text('Season (optional)'), findsNothing);
      expect(find.text('Episode (optional)'), findsNothing);
    });

    testWidgets('a show is asked which episode it finished', (tester) async {
      await pump(tester, dialogue(type: 'series'));

      expect(find.text("What's the last episode you finished today?"),
          findsOneWidget);
      expect(find.text('Everything before it is marked as watched.'),
          findsOneWidget);
      expect(find.text('Season (optional)'), findsOneWidget);
      expect(find.text('Episode (optional)'), findsOneWidget);
    });

    testWidgets('an episode without a season is called out', (tester) async {
      // It cannot be stored, so saying so beats dropping what was typed on
      // save with no explanation.
      await pump(tester, dialogue(type: 'series'));

      await tester.enterText(
          find.widgetWithText(TextField, 'Episode (optional)'), '4');
      await tester.pumpAndSettle();

      expect(find.text('Add a season number to record an episode.'),
          findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Season (optional)'), '2');
      await tester.pumpAndSettle();

      expect(
          find.text('Add a season number to record an episode.'), findsNothing);
    });

    testWidgets('accepting writes the entry to the day', (tester) async {
      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await accept(tester);

      final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(day, hasLength(1));
      expect(day.single['id'], '27205');
      expect(day.single['title'], 'Inception');
      expect(day.single['runtime'], 148);
      expect(day.single['rating'], 8.8);
      expect(day.single['type'], 'movie');
      expect(day.single['friends'], isEmpty);
    });

    testWidgets('a film entry carries no season or episode', (tester) async {
      // Every installed client reads these entries. An untagged one has to
      // stay byte-for-byte what older builds write.
      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await accept(tester);

      final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(day.single.containsKey('season'), isFalse);
      expect(day.single.containsKey('episode'), isFalse);
    });

    testWidgets('a season and episode are recorded when they were given',
        (tester) async {
      await pump(tester, dialogue(type: 'series'));
      await searchAndPick(tester, showLabel, 'breaking bad');
      await tester.enterText(
          find.widgetWithText(TextField, 'Season (optional)'), '2');
      await tester.enterText(
          find.widgetWithText(TextField, 'Episode (optional)'), '4');
      await tester.pumpAndSettle();
      await accept(tester);

      final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(day.single['season'], 2);
      expect(day.single['episode'], 4);
      expect(day.single['type'], 'series');
    });

    testWidgets('a whole season watched in a sitting records no episode',
        (tester) async {
      await pump(tester, dialogue(type: 'series'));
      await searchAndPick(tester, showLabel, 'breaking bad');
      await tester.enterText(
          find.widgetWithText(TextField, 'Season (optional)'), '2');
      await tester.pumpAndSettle();
      await accept(tester);

      final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(day.single['season'], 2);
      expect(day.single.containsKey('episode'), isFalse);
    });

    testWidgets('the film is marked as seen and counted as watched once',
        (tester) async {
      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await accept(tester);

      final seen = await firestore.collection('test-uid').doc('Seen').get();
      expect(seen.data()!['Movies'], ['27205']);
      expect(user.rewatchedMovies['27205'], 1);
      expect(user.seenMovies, [
        ['Movies', '27205']
      ]);
    });

    testWidgets('logging it a second time counts as a rewatch', (tester) async {
      user.rewatchedMovies = {'27205': 1};
      user.seenMovies = [
        ['Movies', '27205'],
      ];

      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await accept(tester);

      expect(user.rewatchedMovies['27205'], 2);
      expect(user.seenMovies, hasLength(1), reason: 'still seen once, listed');
    });

    testWidgets('a tagged friend gets the entry on their calendar too',
        (tester) async {
      await addFriend('friend-a', 'Ana');

      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
      await tester.pumpAndSettle();
      await accept(tester);

      final theirs = (await calendarOf('friend-a'))!['2024-03-09'] as List;
      expect(theirs.single['id'], '27205');
      expect(theirs.single['friends'], ['test-uid'],
          reason: 'their copy names the person they watched it with');

      final mine = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(mine.single['friends'], ['friend-a']);
    });

    testWidgets('a friend left unticked is not tagged', (tester) async {
      await addFriend('friend-a', 'Ana');
      await addFriend('friend-b', 'Bruno');

      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
      await tester.pumpAndSettle();
      await accept(tester);

      expect(await calendarOf('friend-b'), isNull);
      final mine = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(mine.single['friends'], ['friend-a']);
    });

    testWidgets('a range puts the entry on every day it covers',
        (tester) async {
      // Recording a holiday's worth of viewing should not need one dialogue
      // per day.
      await pump(tester, dialogue(range: '2024-03-09T00:00T2024-03-11'));
      await searchAndPick(tester, movieLabel, 'inception');
      await accept(tester);

      final calendar = (await calendarOf('test-uid'))!;
      expect(calendar.keys.toList()..sort(),
          ['2024-03-09', '2024-03-10', '2024-03-11']);
    });

    testWidgets('cancelling records nothing', (tester) async {
      await pump(tester, dialogue());
      await searchAndPick(tester, movieLabel, 'inception');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await calendarOf('test-uid'), isNull);
      expect(find.byType(CalendarAddDialogue), findsNothing);
    });

    group('what an entry does to watch progress', () {
      /// Gives Breaking Bad the seasons TMDB really reports, so the episodes
      /// before the one named can be filled in.
      void withSeasons() {
        http.on('1396-Breaking-Bad?', json: {
          'id': 1396,
          'seasons': [
            {'season_number': 0, 'episode_count': 3},
            {'season_number': 1, 'episode_count': 7},
            {'season_number': 2, 'episode_count': 13},
          ],
        });
      }

      Future<void> logEpisode(WidgetTester tester,
          {String season = '2', String episode = '4'}) async {
        await pump(tester, dialogue(type: 'series'));
        await searchAndPick(tester, showLabel, 'breaking bad');
        await tester.enterText(
            find.widgetWithText(TextField, 'Season (optional)'), season);
        if (episode.isNotEmpty) {
          await tester.enterText(
              find.widgetWithText(TextField, 'Episode (optional)'), episode);
        }
        await tester.pumpAndSettle();
        await accept(tester);
      }

      testWidgets('naming an episode puts the show in progress, not finished',
          (tester) async {
        // The bug this exists for: the entry used to mark the show seen, and
        // anything in a Seen list reads as finished, so "I finished episode 4
        // today" claimed the whole show was done.
        withSeasons();
        await logEpisode(tester);

        expect(
          await ProgressService.showState('1396'),
          WatchProgressState.inProgress,
        );
        final seen = await firestore.collection('test-uid').doc('Seen').get();
        expect(seen.data()?['TVShows'] ?? [], isEmpty);
        expect(user.seenTVShows, isEmpty);
      });

      testWidgets('ticks the episodes before the one named', (tester) async {
        withSeasons();
        await logEpisode(tester);

        expect(await ProgressService.watchedEpisodes('1396', 1),
            [1, 2, 3, 4, 5, 6, 7]);
        expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4]);
        expect(await ProgressService.watchedEpisodes('1396', 0), isEmpty,
            reason: 'specials are not tracked');
      });

      testWidgets('naming only a season watches that whole season',
          (tester) async {
        withSeasons();
        await logEpisode(tester, season: '1', episode: '');

        expect(await ProgressService.watchedEpisodes('1396', 1),
            [1, 2, 3, 4, 5, 6, 7]);
        expect(
          await ProgressService.showState('1396'),
          WatchProgressState.inProgress,
        );
      });

      testWidgets('records a show TMDB has no season data for', (tester) async {
        // The stub answers without a seasons list, which is what a show TMDB
        // knows nothing about looks like. The entry still has to be loggable.
        await logEpisode(tester);

        expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4]);
        expect(
          await ProgressService.showState('1396'),
          WatchProgressState.inProgress,
        );
      });

      testWidgets('an entry naming no part still marks the show seen',
          (tester) async {
        // Unchanged behaviour, and the reason it must stay unchanged: this is
        // the entry every installed client writes.
        await pump(tester, dialogue(type: 'series'));
        await searchAndPick(tester, showLabel, 'breaking bad');
        await accept(tester);

        final seen = await firestore.collection('test-uid').doc('Seen').get();
        expect(seen.data()!['TVShows'], ['1396']);
        expect(user.seenTVShows, [
          ['TVShows', '1396']
        ]);
        expect(
          await ProgressService.showState('1396'),
          WatchProgressState.finished,
        );
      });

      testWidgets('a show already finished stays finished', (tester) async {
        user.seenTVShows = [
          ['TVShows', '1396'],
        ];
        withSeasons();

        await logEpisode(tester);

        expect(
          await ProgressService.showState('1396'),
          WatchProgressState.finished,
        );
        expect(await ProgressService.watchedEpisodes('1396', 2), isEmpty);
        final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
        expect(day.single['episode'], 4,
            reason: 'the day is still logged, it just changes nothing');
      });

      testWidgets('a tagged friend is not told they finished the show',
          (tester) async {
        // A friend's progress cannot be written from here -- the rules allow a
        // client to write its own Progress document and nobody else's -- so
        // the entry says nothing about their state rather than overstating it.
        await addFriend('friend-a', 'Ana');
        withSeasons();

        await pump(tester, dialogue(type: 'series'));
        await searchAndPick(tester, showLabel, 'breaking bad');
        await tester.enterText(
            find.widgetWithText(TextField, 'Season (optional)'), '2');
        await tester.enterText(
            find.widgetWithText(TextField, 'Episode (optional)'), '4');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
        await tester.pumpAndSettle();
        await accept(tester);

        final seen = await firestore.collection('friend-a').doc('Seen').get();
        expect(seen.data()?['TVShows'] ?? [], isEmpty);

        final theirs = (await calendarOf('friend-a'))!['2024-03-09'] as List;
        expect(theirs.single['episode'], 4,
            reason: 'they still get the entry, and their own history with it');
      });

      testWidgets('a tagged friend is still marked seen for a whole show',
          (tester) async {
        await addFriend('friend-a', 'Ana');

        await pump(tester, dialogue(type: 'series'));
        await searchAndPick(tester, showLabel, 'breaking bad');
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
        await tester.pumpAndSettle();
        await accept(tester);

        final seen = await firestore.collection('friend-a').doc('Seen').get();
        expect(seen.data()!['TVShows'], ['1396']);
      });
    });
  });

  group('logging something from a title page', () {
    Widget dialogue({
      bool modifying = false,
      List friends = const [],
      String type = 'movie',
    }) =>
        AddToCalendar(
          media: type == 'movie'
              ? Movie(id: '27205', title: 'Inception', coverPhoto: '')
              : TVShow(id: '1396', title: 'Breaking Bad', coverPhoto: ''),
          dateForMap: '2024-03-09',
          modifying: modifying,
          friends: friends,
          type: type,
        );

    testWidgets('accepting records the title on the chosen day',
        (tester) async {
      await pump(tester, dialogue());
      await accept(tester);

      final day = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(day.single['id'], '27205');
      expect(day.single['title'], 'Inception');
      expect(day.single['rating'], 8.8);
      expect(user.rewatchedMovies['27205'], 1);
    });

    testWidgets('a film is not asked which episode it was', (tester) async {
      await pump(tester, dialogue());

      expect(find.text('Season (optional)'), findsNothing);
    });

    testWidgets('a show is asked which episode it was', (tester) async {
      await pump(tester, dialogue(type: 'series'));

      expect(find.text('Season (optional)'), findsOneWidget);
    });

    testWidgets('reopening an entry starts from the episode it recorded',
        (tester) async {
      // Reopening the dialogue to change who you watched with must not
      // silently drop the season and episode already on the entry.
      user.calendar = {
        '2024-03-09': [
          {'id': '1396', 'title': 'Breaking Bad', 'season': 2, 'episode': 4},
        ],
      };

      await pump(tester, dialogue(modifying: true, type: 'series'));

      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, 'Season (optional)'))
              .controller!
              .text,
          '2');
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, 'Episode (optional)'))
              .controller!
              .text,
          '4');
    });

    testWidgets('an entry with no episode recorded opens with empty boxes',
        (tester) async {
      user.calendar = {
        '2024-03-09': [
          {'id': '1396', 'title': 'Breaking Bad'},
        ],
      };

      await pump(tester, dialogue(modifying: true, type: 'series'));

      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, 'Season (optional)'))
              .controller!
              .text,
          isEmpty);
    });

    testWidgets('reopening an entry starts with its friends already ticked',
        (tester) async {
      await addFriend('friend-a', 'Ana');
      user.calendar = {
        '2024-03-09': [
          {
            'id': '27205',
            'title': 'Inception',
            'friends': ['friend-a']
          },
        ],
      };

      await pump(tester, dialogue(modifying: true, friends: ['friend-a']));

      final tile = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Ana'));
      expect(tile.value, isTrue);
    });

    testWidgets('a tagged friend is given the entry', (tester) async {
      await addFriend('friend-a', 'Ana');

      await pump(tester, dialogue());
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
      await tester.pumpAndSettle();
      await accept(tester);

      final theirs = (await calendarOf('friend-a'))!['2024-03-09'] as List;
      expect(theirs.single['id'], '27205');
      expect(user.seenWith['friend-a']['Movies'], ['27205']);
    });

    testWidgets('cancelling records nothing', (tester) async {
      await pump(tester, dialogue());
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await calendarOf('test-uid'), isNull);
      expect(find.byType(AddToCalendar), findsNothing);
    });

    testWidgets('untagging everyone rewrites the entry with nobody on it',
        (tester) async {
      // Editing goes through a delete, which asks whether it applies to
      // everyone. The rewritten entry is what the calendar then shows.
      await addFriend('friend-a', 'Ana');
      user.calendar = {
        '2024-03-09': [
          {
            'id': '27205',
            'title': 'Inception',
            'friends': ['friend-a'],
            'type': 'movie',
          },
        ],
      };
      await seedUserDoc(firestore, 'test-uid', 'Calendar', {
        '2024-03-09': [
          {
            'id': '27205',
            'title': 'Inception',
            'friends': ['friend-a'],
            'type': 'movie',
          },
        ],
      });

      await pump(tester, dialogue(modifying: true, friends: ['friend-a']));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Just me'));
      await tester.pumpAndSettle();

      final mine = (await calendarOf('test-uid'))!['2024-03-09'] as List;
      expect(mine, hasLength(1));
      expect(mine.single['friends'], isEmpty);
    });
  });
}
