import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/watch_progress_controller.dart';
import 'package:uractor/common/watch_progress_view.dart';
import 'package:uractor/main.dart';

import 'support/harness.dart';

void main() {
  const seasons = [
    SeasonEpisodeCount(seasonNumber: 0, episodeCount: 3),
    SeasonEpisodeCount(seasonNumber: 1, episodeCount: 2),
    SeasonEpisodeCount(seasonNumber: 2, episodeCount: 2),
  ];

  setUp(() {
    installTestUser(uid: 'progress-ui-user');
    installFakeFirestore();
  });

  ShowProgressController controller({String showId = 'show-1'}) =>
      ShowProgressController(showId: showId, seasons: seasons);

  test('starts empty and reports the show as not started', () async {
    final progress = controller();
    addTearDown(progress.dispose);

    await progress.load();

    expect(progress.loading, isFalse);
    expect(progress.state, WatchProgressState.notStarted);
    expect(progress.watchedIn(1), isEmpty);
    expect(progress.seasonTickState(1), SeasonTickState.none);
  });

  test('reflects episodes already recorded before the screen opened', () async {
    await ProgressService.markEpisodeWatched(
      'show-1',
      1,
      1,
      seasons,
      date: DateTime(2026, 1, 1),
    );

    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    expect(progress.isWatched(1, 1), isTrue);
    expect(progress.isWatched(1, 2), isFalse);
    expect(progress.watchedCountOf(1), 1);
    expect(progress.seasonTickState(1), SeasonTickState.partial);
    expect(progress.state, WatchProgressState.inProgress);
  });

  test('ticking an episode records it and notifies listeners', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    var notifications = 0;
    progress.addListener(() => notifications++);

    await progress.toggleEpisode(1, 1);

    expect(progress.isWatched(1, 1), isTrue);
    expect(await ProgressService.watchedEpisodes('show-1', 1), [1]);
    expect(notifications, greaterThan(0));
  });

  test('ticking an episode again clears it', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleEpisode(1, 1);
    await progress.toggleEpisode(1, 1);

    expect(progress.isWatched(1, 1), isFalse);
    expect(await ProgressService.watchedEpisodes('show-1', 1), isEmpty);
  });

  test('ticking the last episode finishes the show', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleEpisode(1, 1);
    await progress.toggleEpisode(1, 2);
    await progress.toggleEpisode(2, 1);
    expect(progress.state, WatchProgressState.inProgress);

    await progress.toggleEpisode(2, 2);

    expect(progress.state, WatchProgressState.finished);
  });

  test('a season toggle fills the season', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleSeason(1);

    expect(progress.seasonTickState(1), SeasonTickState.all);
    expect(await ProgressService.watchedEpisodes('show-1', 1), [1, 2]);
  });

  test('a season toggle clears a season that is already complete', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleSeason(1);
    await progress.toggleSeason(1);

    expect(progress.seasonTickState(1), SeasonTickState.none);
    expect(await ProgressService.watchedEpisodes('show-1', 1), isEmpty);
  });

  test('a season toggle fills a part-watched season rather than clearing it',
      () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();
    await progress.toggleEpisode(1, 1);

    await progress.toggleSeason(1);

    expect(progress.seasonTickState(1), SeasonTickState.all);
  });

  test('refuses to tick specials, which the service would ignore', () async {
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleEpisode(0, 1);
    await progress.toggleSeason(0);

    expect(progress.watchedIn(0), isEmpty);
    expect(progress.state, WatchProgressState.notStarted);
  });

  test('does nothing for a season with no episodes yet', () async {
    final progress = ShowProgressController(
      showId: 'show-1',
      seasons: const [SeasonEpisodeCount(seasonNumber: 9, episodeCount: 0)],
    );
    addTearDown(progress.dispose);
    await progress.load();

    await progress.toggleSeason(9);

    expect(progress.seasonTickState(9), SeasonTickState.none);
    expect(progress.state, WatchProgressState.notStarted);
  });

  test('drops a second write while the first is still in flight', () async {
    // Both writes merge the episode map they read when they started, so
    // letting them overlap loses whichever tick landed first.
    final progress = controller();
    addTearDown(progress.dispose);
    await progress.load();

    final first = progress.toggleEpisode(1, 1);
    final second = progress.toggleEpisode(1, 2);
    await Future.wait([first, second]);

    expect(await ProgressService.watchedEpisodes('show-1', 1), [1]);
  });

  test('picks the episode count up from its season metadata', () async {
    final progress = controller();
    addTearDown(progress.dispose);

    expect(progress.episodeCountOf(1), 2);
    expect(progress.episodeCountOf(42), 0);
  });

  test('survives a notification arriving after disposal', () async {
    final progress = controller();
    final load = progress.load();
    progress.dispose();

    await load;

    expect(currentUser.uid, 'progress-ui-user');
  });
}
