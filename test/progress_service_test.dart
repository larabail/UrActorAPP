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
}
