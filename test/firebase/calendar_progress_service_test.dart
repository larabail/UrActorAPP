/// Tests for the seam between a calendar entry and the progress record.
///
/// `CalendarProgress` decides what an entry means and `ProgressService` stores
/// it; this covers the piece that reads the current state, chooses, and
/// carries the decision out — including the case the whole change exists for,
/// where logging one episode records progress instead of claiming the show was
/// finished.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/calendar_episode.dart';
import 'package:uractor/common/calendar_progress.dart';
import 'package:uractor/common/firebase/calendar_progress_service.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/firebase/settings_service.dart';

import '../support/harness.dart';

void main() {
  const seasons = [
    SeasonEpisodeCount(seasonNumber: 0, episodeCount: 3),
    SeasonEpisodeCount(seasonNumber: 1, episodeCount: 4),
    SeasonEpisodeCount(seasonNumber: 2, episodeCount: 6),
  ];

  late FakeFirebaseFirestore firestore;

  setUp(() {
    installTestUser(uid: 'calendar-user');
    firestore = installFakeFirestore();
  });

  test('an entry naming an episode puts the show in progress', () async {
    final intent = await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 2, episode: 5),
      seasons: seasons,
      date: DateTime(2026, 5, 1),
    );

    expect(intent.action, CalendarProgressAction.markWatchedThrough);
    expect(intent.marksSelfSeen, isFalse);
    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.inProgress,
    );
    expect(await ProgressService.watchedEpisodes('1396', 1), [1, 2, 3, 4]);
    expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4, 5]);
  });

  test('an entry naming the last episode still finishes the show', () async {
    await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 2, episode: 6),
      seasons: seasons,
    );

    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.finished,
    );
  });

  test('an entry naming only a season watches the whole season', () async {
    final intent = await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 1),
      seasons: seasons,
    );

    expect(intent.episode, isNull);
    expect(await ProgressService.watchedEpisodes('1396', 1), [1, 2, 3, 4]);
    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.inProgress,
    );
  });

  test('a season TMDB has no count for is recorded as in progress only',
      () async {
    await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 9),
      seasons: seasons,
    );

    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.inProgress,
    );
    expect(await ProgressService.watchedEpisodes('1396', 9), isEmpty);
  });

  test('a show already finished has its episodes ticked and stays finished',
      () async {
    await ProgressService.finishShow('1396', date: DateTime(2026, 1, 9));

    final intent = await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 2, episode: 5),
      seasons: seasons,
      date: DateTime(2026, 5, 1),
    );

    expect(intent.action, CalendarProgressAction.markWatchedThrough);
    expect(intent.keepsFinished, isTrue);
    // The season guide draws only what is ticked, so a finished show that
    // recorded no episodes showed an empty guide however often it was logged.
    expect(await ProgressService.watchedEpisodes('1396', 1), [1, 2, 3, 4]);
    expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4, 5]);
    // None of which is a claim that the user started rewatching it.
    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.finished,
    );
    final dates = await ProgressService.datesFor(progressTVShowsKey, '1396');
    expect(dates.finished, '2026-01-09');
  });

  test('a show finished only by sitting in the Seen list keeps its place',
      () async {
    // The state every show logged before episodes were recordable is in: on
    // the Seen list, with no progress entry of its own.
    final user = installTestUser(uid: 'calendar-user');
    user.seenTVShows = [
      ['TVShows', '1396'],
    ];

    await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 2, episode: 5),
      seasons: seasons,
      date: DateTime(2026, 5, 1),
    );

    expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4, 5]);
    expect(
      await ProgressService.showState('1396'),
      WatchProgressState.finished,
    );
    expect(
      user.seenTVShows,
      [
        ['TVShows', '1396']
      ],
      reason: 'the Seen list drives badges and counts and is the user to curate',
    );
  });

  test('an entry with no part recorded leaves progress alone', () async {
    final intent = await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: null,
      seasons: seasons,
    );

    expect(intent.marksSelfSeen, isTrue);
    expect(intent.marksFriendsSeen, isTrue);
    // Nothing is written: the caller still owns marking the title seen, which
    // is what an entry with no part has always meant.
    final progress = await firestore
        .collection('calendar-user')
        .doc('Progress')
        .get();
    expect(progress.exists, isFalse);
  });

  test('a film is never put in progress by a calendar entry', () async {
    final intent = await CalendarProgressService.apply(
      type: calendarMovieType,
      id: '27205',
      episode: const CalendarEpisode(season: 1, episode: 1),
      seasons: const [],
    );

    expect(intent.action, CalendarProgressAction.markSeen);
    expect(
      await ProgressService.movieState('27205'),
      WatchProgressState.notStarted,
    );
  });

  test('logging more of a show keeps what was already watched', () async {
    await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 2, episode: 5),
      seasons: seasons,
      date: DateTime(2026, 5, 1),
    );

    await CalendarProgressService.apply(
      type: 'series',
      id: '1396',
      episode: const CalendarEpisode(season: 1, episode: 1),
      seasons: seasons,
      date: DateTime(2026, 5, 4),
    );

    expect(await ProgressService.watchedEpisodes('1396', 2), [1, 2, 3, 4, 5]);
    final dates = await ProgressService.datesFor(progressTVShowsKey, '1396');
    expect(dates.started, '2026-05-01');
  });

  group('with the fill-in setting off', () {
    setUp(() {
      installTestUser(
        uid: 'calendar-user',
        settings: {'language': 'en', settingFillEpisodesBefore: false},
      );
    });

    test('records only the episode named', () async {
      // The case the setting exists for: someone who joined at season 2 has
      // not watched season 1, and claiming they had is a history invented for
      // them that they then have to go and untick.
      await CalendarProgressService.apply(
        type: 'series',
        id: '1396',
        episode: const CalendarEpisode(season: 2, episode: 5),
        seasons: seasons,
        date: DateTime(2026, 5, 1),
      );

      expect(await ProgressService.watchedEpisodes('1396', 1), isEmpty);
      expect(await ProgressService.watchedEpisodes('1396', 2), [5]);
      expect(
        await ProgressService.showState('1396'),
        WatchProgressState.inProgress,
      );
    });

    test('still records a whole season when the entry named one', () async {
      await CalendarProgressService.apply(
        type: 'series',
        id: '1396',
        episode: const CalendarEpisode(season: 2),
        seasons: seasons,
      );

      expect(await ProgressService.watchedEpisodes('1396', 1), isEmpty);
      expect(await ProgressService.watchedEpisodes('1396', 2), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('leaves what was already ticked alone', () async {
      await ProgressService.markEpisodeWatched('1396', 1, 1, seasons);

      await CalendarProgressService.apply(
        type: 'series',
        id: '1396',
        episode: const CalendarEpisode(season: 2, episode: 2),
        seasons: seasons,
      );

      expect(await ProgressService.watchedEpisodes('1396', 1), [1]);
      expect(await ProgressService.watchedEpisodes('1396', 2), [2]);
    });
  });
}
