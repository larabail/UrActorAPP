import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/main.dart';

import 'support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  const seasons = [
    SeasonEpisodeCount(seasonNumber: 0, episodeCount: 4),
    SeasonEpisodeCount(seasonNumber: 1, episodeCount: 2),
    SeasonEpisodeCount(seasonNumber: 2, episodeCount: 2),
  ];

  setUp(() {
    installTestUser(uid: 'progress-user');
    firestore = installFakeFirestore();
  });

  Future<Map<String, dynamic>> progressDoc() async {
    final snapshot = await firestore
        .collection(currentUser.uid)
        .doc('Progress')
        .get();
    return snapshot.data() as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> seenDoc() async {
    final snapshot = await firestore
        .collection(currentUser.uid)
        .doc('Seen')
        .get();
    return snapshot.data() as Map<String, dynamic>;
  }

  group('watch states', () {
    test('reports all three movie states', () async {
      expect(
        await ProgressService.movieState('m1'),
        WatchProgressState.notStarted,
      );

      await ProgressService.startMovie('m1', date: DateTime(2026, 1, 1));
      expect(
        await ProgressService.movieState('m1'),
        WatchProgressState.inProgress,
      );

      await ProgressService.finishMovie('m1', date: DateTime(2026, 1, 2));
      expect(
        await ProgressService.movieState('m1'),
        WatchProgressState.finished,
      );
    });

    test('reports all three show states', () async {
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.notStarted,
      );

      await ProgressService.startShow('s1', date: DateTime(2026, 1, 1));
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.inProgress,
      );

      await ProgressService.finishShow('s1', date: DateTime(2026, 1, 2));
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.finished,
      );
    });

    test(
      'treats seen items with no progress record as finished but not in progress',
      () async {
        currentUser.seenMovies = [
          ['Movies', 'm-seen'],
        ];
        currentUser.seenTVShows = [
          ['TVShows', 's-seen'],
        ];

        expect(
          await ProgressService.movieState('m-seen'),
          WatchProgressState.finished,
        );
        expect(
          await ProgressService.showState('s-seen'),
          WatchProgressState.finished,
        );
        expect(await ProgressService.inProgressItems(), isEmpty);
      },
    );
  });

  group('movies', () {
    test(
      'stores start and finish dates and adds finished movies to Seen',
      () async {
        await ProgressService.startMovie('m1', date: DateTime(2026, 2, 3));
        await ProgressService.finishMovie('m1', date: DateTime(2026, 2, 4));

        final progress = await progressDoc();
        expect(progress['Movies']['m1']['started'], '2026-02-03');
        expect(progress['Movies']['m1']['finished'], '2026-02-04');
        expect((await seenDoc())['Movies'], ['m1']);
        expect(currentUser.seenMovies, [
          ['Movies', 'm1'],
        ]);
      },
    );

    test('refuses to reopen a seen movie', () async {
      currentUser.seenMovies = [
        ['Movies', 'm1'],
      ];

      expect(
        () => ProgressService.startMovie('m1', date: DateTime(2026, 1, 1)),
        throwsStateError,
      );
      expect(() => ProgressService.reopenMovie('m1'), throwsStateError);
    });
  });

  group('episodes and seasons', () {
    test('marks and unmarks a single episode', () async {
      await ProgressService.markEpisodeWatched(
        's1',
        1,
        2,
        seasons,
        date: DateTime(2026, 3, 1),
      );
      expect(await ProgressService.watchedEpisodes('s1', 1), [2]);

      await ProgressService.unmarkEpisodeWatched(
        's1',
        1,
        2,
        date: DateTime(2026, 3, 2),
      );
      expect(await ProgressService.watchedEpisodes('s1', 1), isEmpty);
    });

    test('marks and unmarks an entire season in one stored array', () async {
      await ProgressService.markSeasonWatched(
        's1',
        1,
        3,
        seasons,
        date: DateTime(2026, 3, 1),
      );
      expect(await ProgressService.watchedEpisodes('s1', 1), [1, 2, 3]);

      await ProgressService.unmarkSeasonWatched(
        's1',
        1,
        date: DateTime(2026, 3, 2),
      );
      expect(await ProgressService.watchedEpisodes('s1', 1), isEmpty);
    });

    test(
      'auto-finishes a show when the last non-special episode is watched',
      () async {
        await ProgressService.markSeasonWatched(
          's1',
          1,
          2,
          seasons,
          date: DateTime(2026, 4, 1),
        );
        expect(
          await ProgressService.showState('s1'),
          WatchProgressState.inProgress,
        );

        await ProgressService.markSeasonWatched(
          's1',
          2,
          2,
          seasons,
          date: DateTime(2026, 4, 2),
        );

        expect(
          await ProgressService.showState('s1'),
          WatchProgressState.finished,
        );
        expect((await seenDoc())['TVShows'], ['s1']);
        final progress = await progressDoc();
        expect(progress['TVShows']['s1']['finished'], '2026-04-02');
      },
    );

    test('ignores specials for storage and completion', () async {
      await ProgressService.markEpisodeWatched(
        's1',
        0,
        1,
        seasons,
        date: DateTime(2026, 4, 1),
      );
      expect(await ProgressService.watchedEpisodes('s1', 0), isEmpty);

      await ProgressService.markSeasonWatched(
        's1',
        1,
        2,
        seasons,
        date: DateTime(2026, 4, 2),
      );
      await ProgressService.markSeasonWatched(
        's1',
        2,
        2,
        seasons,
        date: DateTime(2026, 4, 3),
      );

      final progress = await progressDoc();
      expect(progress['TVShows']['s1']['episodes'].containsKey('0'), isFalse);
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.finished,
      );
    });

    test(
      'finds the next unwatched episode and rolls to the next season',
      () async {
        await ProgressService.markSeasonWatched(
          's1',
          1,
          2,
          seasons,
          date: DateTime(2026, 5, 1),
        );
        expect(
          await ProgressService.nextUnwatchedEpisode('s1', seasons),
          const WatchProgressEpisode(seasonNumber: 2, episodeNumber: 1),
        );

        await ProgressService.markEpisodeWatched(
          's1',
          2,
          1,
          seasons,
          date: DateTime(2026, 5, 2),
        );
        expect(
          await ProgressService.nextUnwatchedEpisode('s1', seasons),
          const WatchProgressEpisode(seasonNumber: 2, episodeNumber: 2),
        );
      },
    );
  });

  group('reconciliation with Seen', () {
    test(
      'reopens a show by removing it from Seen and making it in progress',
      () async {
        await seedUserDoc(firestore, currentUser.uid, 'TVShows', {
          'Seen': ['s1'],
        });
        await seedUserDoc(firestore, currentUser.uid, 'Seen', {
          'TVShows': ['s1'],
        });
        currentUser.seenTVShows = [
          ['TVShows', 's1'],
        ];
        currentUser.seen = [
          ['TVShows', 's1'],
        ];

        await ProgressService.reopenShow('s1', date: DateTime(2026, 6, 1));

        expect(
          await ProgressService.showState('s1'),
          WatchProgressState.inProgress,
        );
        final seen = await seenDoc();
        expect(seen['TVShows'], isEmpty);
        expect(currentUser.seenTVShows, isEmpty);
      },
    );

    test('preserves unrelated Progress fields when writing one item', () async {
      await seedUserDoc(firestore, currentUser.uid, 'Progress', {
        'Movies': {
          'existing-movie': {
            'started': '2026-01-01',
            'finished': null,
            'updated': '2026-01-01',
          },
        },
        'TVShows': {
          'existing-show': {
            'started': '2026-01-02',
            'finished': null,
            'updated': '2026-01-02',
            'episodes': {
              '1': [1],
            },
          },
        },
        'metadata': {'keep': true},
      });

      await ProgressService.startMovie('new-movie', date: DateTime(2026, 7, 1));

      final progress = await progressDoc();
      expect(progress['Movies'].containsKey('existing-movie'), isTrue);
      expect(progress['Movies'].containsKey('new-movie'), isTrue);
      expect(progress['TVShows'].containsKey('existing-show'), isTrue);
      expect(progress['metadata'], {'keep': true});
    });

    test('orders in-progress items by most recent activity', () async {
      await ProgressService.startMovie('older', date: DateTime(2026, 1, 1));
      await ProgressService.startShow('newer', date: DateTime(2026, 1, 3));
      await ProgressService.finishMovie('finished', date: DateTime(2026, 1, 4));

      final items = await ProgressService.inProgressItems();

      expect(items.map((item) => [item.type, item.id]), [
        ['TVShows', 'newer'],
        ['Movies', 'older'],
      ]);
    });
  });

  group('reading progress back', () {
    test('returns every season in one read', () async {
      await ProgressService.markEpisodeWatched('s1', 1, 2, seasons);
      await ProgressService.markEpisodeWatched('s1', 2, 1, seasons);

      expect(await ProgressService.watchedEpisodesBySeason('s1'), {
        '1': [2],
        '2': [1],
      }.map((season, episodes) => MapEntry(int.parse(season), episodes)));
    });

    test('returns nothing for a show with no record', () async {
      expect(await ProgressService.watchedEpisodesBySeason('unknown'), isEmpty);
    });

    test('agrees with the single-season read', () async {
      await ProgressService.markSeasonWatched('s1', 1, 2, seasons);

      final bySeason = await ProgressService.watchedEpisodesBySeason('s1');
      expect(bySeason[1], await ProgressService.watchedEpisodes('s1', 1));
    });

    test('reports the recorded dates for an item in progress', () async {
      await ProgressService.startMovie('m1', date: DateTime(2026, 2, 3));

      final dates = await ProgressService.datesFor(progressMoviesKey, 'm1');

      expect(dates.started, '2026-02-03');
      expect(dates.finished, isNull);
    });

    test('reports both dates once an item is finished', () async {
      await ProgressService.startMovie('m1', date: DateTime(2026, 2, 3));
      await ProgressService.finishMovie('m1', date: DateTime(2026, 2, 5));

      final dates = await ProgressService.datesFor(progressMoviesKey, 'm1');

      expect(dates.started, '2026-02-03');
      expect(dates.finished, '2026-02-05');
    });

    test('reports no dates for an item with no record', () async {
      final dates = await ProgressService.datesFor(progressMoviesKey, 'nope');

      expect(dates.started, isNull);
      expect(dates.finished, isNull);
    });
  });

  group('markEpisodesWatched', () {
    test('ticks every episode it is given and starts the show', () async {
      await ProgressService.markEpisodesWatched('s1', {
        1: [1, 2],
        2: [1],
      }, seasons, date: DateTime(2026, 5, 1));

      expect(await ProgressService.watchedEpisodes('s1', 1), [1, 2]);
      expect(await ProgressService.watchedEpisodes('s1', 2), [1]);
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.inProgress,
      );
      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.started, '2026-05-01');
      expect(dates.finished, isNull);
    });

    test('adds to what is already recorded rather than replacing it', () async {
      // Logging "I finished S1E1 today" must not wipe a season 2 already
      // watched, which is the whole reason this is additive.
      await ProgressService.markSeasonWatched('s1', 2, 2, seasons);

      await ProgressService.markEpisodesWatched('s1', {
        1: [1],
      }, seasons);

      expect(await ProgressService.watchedEpisodes('s1', 1), [1]);
      expect(await ProgressService.watchedEpisodes('s1', 2), [1, 2]);
    });

    test('does not drop an episode already ticked in the same season',
        () async {
      await ProgressService.markEpisodeWatched('s1', 1, 2, seasons);

      await ProgressService.markEpisodesWatched('s1', {
        1: [1],
      }, seasons);

      expect(await ProgressService.watchedEpisodes('s1', 1), [1, 2]);
    });

    test('finishes the show when it completes every non-special episode',
        () async {
      await ProgressService.markEpisodesWatched('s1', {
        1: [1, 2],
        2: [1, 2],
      }, seasons, date: DateTime(2026, 5, 2));

      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.finished,
      );
      final seen = await seenDoc();
      expect(seen[progressTVShowsKey], contains('s1'));
    });

    test('leaves the show in progress when specials are the only gap',
        () async {
      await ProgressService.markEpisodesWatched('s1', {
        1: [1, 2],
        2: [1, 2],
      }, seasons);

      // Season 0 has four episodes and none of them were ticked; a show is
      // still finished without them.
      expect(await ProgressService.watchedEpisodes('s1', 0), isEmpty);
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.finished,
      );
    });

    test('ignores specials it is asked to tick', () async {
      await ProgressService.markEpisodesWatched('s1', {
        0: [1],
        1: [1],
      }, seasons);

      expect(await ProgressService.watchedEpisodes('s1', 0), isEmpty);
      expect(await ProgressService.watchedEpisodes('s1', 1), [1]);
    });

    test('starts the show even with nothing to tick', () async {
      // What a calendar entry naming a season TMDB has no episode count for
      // amounts to: the show is being watched, and that is all that is known.
      await ProgressService.markEpisodesWatched(
        's1',
        const <int, List<int>>{},
        seasons,
        date: DateTime(2026, 5, 3),
      );

      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.inProgress,
      );
      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.started, '2026-05-03');
    });

    test('keeps the original start date when more is watched later', () async {
      await ProgressService.markEpisodesWatched('s1', {
        1: [1],
      }, seasons, date: DateTime(2026, 5, 1));

      await ProgressService.markEpisodesWatched('s1', {
        1: [2],
      }, seasons, date: DateTime(2026, 5, 4));

      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.started, '2026-05-01');
    });
  });

  group('markEpisodesWatched on a show already finished', () {
    test('records the ticks without unfinishing it', () async {
      await ProgressService.finishShow('s1', date: DateTime(2026, 1, 9));

      await ProgressService.markEpisodesWatched(
        's1',
        {
          1: [1, 2],
        },
        seasons,
        date: DateTime(2026, 5, 1),
        keepFinished: true,
      );

      expect(await ProgressService.watchedEpisodes('s1', 1), [1, 2]);
      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.finished,
      );
      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.finished, '2026-01-09',
          reason: 'the day it was finished is not the day it was logged');
      final seen = await seenDoc();
      expect(seen[progressTVShowsKey], contains('s1'));
    });

    test('invents a finish date for a show that only sat in the Seen list',
        () async {
      // Every show logged before episodes were recordable is in this state:
      // on the Seen list with no progress entry of its own. Without a finish
      // date the entry would read as in progress the moment anything took the
      // title off that list.
      currentUser.seenTVShows = [
        [progressTVShowsKey, 's1'],
      ];

      await ProgressService.markEpisodesWatched(
        's1',
        {
          1: [1],
        },
        seasons,
        date: DateTime(2026, 5, 1),
        keepFinished: true,
      );

      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.finished, '2026-05-01');
      expect(await ProgressService.watchedEpisodes('s1', 1), [1]);
    });

    test('does not tick a show into a second finish', () async {
      await ProgressService.finishShow('s1', date: DateTime(2026, 1, 9));

      await ProgressService.markEpisodesWatched(
        's1',
        {
          1: [1, 2],
          2: [1, 2],
        },
        seasons,
        date: DateTime(2026, 5, 1),
        keepFinished: true,
      );

      final dates = await ProgressService.datesFor(progressTVShowsKey, 's1');
      expect(dates.finished, '2026-01-09');
    });
  });
}
