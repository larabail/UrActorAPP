import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/media_result_widgets.dart';
import 'package:uractor/common/watch_progress_controller.dart';
import 'package:uractor/common/watch_progress_widgets.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

void main() {
  const seasons = [
    SeasonEpisodeCount(seasonNumber: 0, episodeCount: 3),
    SeasonEpisodeCount(seasonNumber: 1, episodeCount: 2),
    SeasonEpisodeCount(seasonNumber: 2, episodeCount: 2),
  ];

  setUp(() {
    installTestUser(uid: 'progress-widget-user');
    installFakeFirestore();
  });

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<ShowProgressController> loadedController({
    String showId = 'show-1',
  }) async {
    final controller = ShowProgressController(
      showId: showId,
      seasons: seasons,
    );
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  Finder iconIn(Key key, IconData icon) => find.descendant(
    of: find.byKey(key),
    matching: find.byIcon(icon),
  );

  group('SeasonWatchToggle', () {
    testWidgets('marks a whole season when tapped', (tester) async {
      final controller = await loadedController();
      await pumpApp(
        tester,
        SeasonWatchToggle(controller: controller, seasonNumber: 1),
      );

      expect(
        iconIn(const ValueKey('seasonWatchToggle-1'), Icons.radio_button_unchecked),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('seasonWatchToggle-1')));
      await tester.pumpAndSettle();

      expect(
        iconIn(const ValueKey('seasonWatchToggle-1'), Icons.check_circle),
        findsOneWidget,
      );
      expect(await ProgressService.watchedEpisodes('show-1', 1), [1, 2]);
    });

    testWidgets('clears a season that is already complete', (tester) async {
      await ProgressService.markSeasonWatched('show-1', 1, 2, seasons);
      final controller = await loadedController();
      await pumpApp(
        tester,
        SeasonWatchToggle(controller: controller, seasonNumber: 1),
      );

      await tester.tap(find.byKey(const ValueKey('seasonWatchToggle-1')));
      await tester.pumpAndSettle();

      expect(await ProgressService.watchedEpisodes('show-1', 1), isEmpty);
    });

    testWidgets('shows a part-watched season as partial', (tester) async {
      await ProgressService.markEpisodeWatched('show-1', 1, 1, seasons);
      final controller = await loadedController();
      await pumpApp(
        tester,
        SeasonWatchToggle(controller: controller, seasonNumber: 1),
      );

      expect(
        iconIn(const ValueKey('seasonWatchToggle-1'), Icons.adjust),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing for specials', (tester) async {
      final controller = await loadedController();
      await pumpApp(
        tester,
        SeasonWatchToggle(controller: controller, seasonNumber: 0),
      );

      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('EpisodeWatchToggle', () {
    testWidgets('marks and unmarks a single episode', (tester) async {
      final controller = await loadedController();
      await pumpApp(
        tester,
        EpisodeWatchToggle(
          controller: controller,
          seasonNumber: 1,
          episodeNumber: 2,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('episodeWatchToggle-1-2')));
      await tester.pumpAndSettle();

      expect(
        iconIn(const ValueKey('episodeWatchToggle-1-2'), Icons.check_circle),
        findsOneWidget,
      );
      expect(await ProgressService.watchedEpisodes('show-1', 1), [2]);

      await tester.tap(find.byKey(const ValueKey('episodeWatchToggle-1-2')));
      await tester.pumpAndSettle();

      expect(await ProgressService.watchedEpisodes('show-1', 1), isEmpty);
    });

    testWidgets('renders nothing for a special', (tester) async {
      final controller = await loadedController();
      await pumpApp(
        tester,
        EpisodeWatchToggle(
          controller: controller,
          seasonNumber: 0,
          episodeNumber: 1,
        ),
      );

      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('MediaProgressControl', () {
    testWidgets('starts a movie that has not been started', (tester) async {
      var changed = 0;
      await pumpApp(
        tester,
        MediaProgressControl(
          id: 'm1',
          type: progressMoviesKey,
          onChanged: () => changed++,
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('watchProgressControl')));
      await tester.pumpAndSettle();
      expect(find.text('Not started'), findsOneWidget);

      await tester.tap(find.text('Start watching'));
      await tester.pumpAndSettle();

      expect(
        await ProgressService.movieState('m1'),
        WatchProgressState.inProgress,
      );
      expect(find.byIcon(Icons.play_circle), findsOneWidget);
      expect(changed, 1);
    });

    testWidgets('finishes a movie that is in progress', (tester) async {
      await ProgressService.startMovie('m1', date: DateTime(2026, 3, 4));
      await pumpApp(
        tester,
        const MediaProgressControl(id: 'm1', type: progressMoviesKey),
      );

      await tester.tap(find.byKey(const ValueKey('watchProgressControl')));
      await tester.pumpAndSettle();
      expect(find.text('Watching since 2026-03-04'), findsOneWidget);

      await tester.tap(find.text('Mark as finished'));
      await tester.pumpAndSettle();

      expect(
        await ProgressService.movieState('m1'),
        WatchProgressState.finished,
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('never offers to reopen a finished movie', (tester) async {
      await ProgressService.finishMovie('m1', date: DateTime(2026, 3, 5));
      await pumpApp(
        tester,
        const MediaProgressControl(id: 'm1', type: progressMoviesKey),
      );

      await tester.tap(find.byKey(const ValueKey('watchProgressControl')));
      await tester.pumpAndSettle();

      expect(find.text('Finished on 2026-03-05'), findsOneWidget);
      expect(find.text('Watch again'), findsNothing);
      expect(find.text('Start watching'), findsNothing);
      expect(find.text('Mark as finished'), findsNothing);
    });

    testWidgets('reopens a finished show', (tester) async {
      await ProgressService.finishShow('s1', date: DateTime(2026, 3, 6));
      await pumpApp(
        tester,
        const MediaProgressControl(id: 's1', type: progressTVShowsKey),
      );

      await tester.tap(find.byKey(const ValueKey('watchProgressControl')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch again'));
      await tester.pumpAndSettle();

      expect(
        await ProgressService.showState('s1'),
        WatchProgressState.inProgress,
      );
    });

    testWidgets('rereads its state when the refresh token changes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const Scaffold(
            body: MediaProgressControl(
              id: 'm2',
              type: progressMoviesKey,
              refreshToken: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

      // Stands in for the seen icon beside it being tapped, which finishes the
      // movie without the control ever hearing about it.
      await ProgressService.finishMovie('m2', date: DateTime(2026, 3, 7));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const Scaffold(
            body: MediaProgressControl(
              id: 'm2',
              type: progressMoviesKey,
              refreshToken: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('MediaStatusIconsRow', () {
    testWidgets('appends a trailing control without a row of its own',
        (tester) async {
      await pumpApp(
        tester,
        MediaStatusIconsRow(
          seenImage: 'assets/seen_before.png',
          watchlistImage: 'assets/watchlist_before.png',
          favImage: 'assets/fav_before.png',
          listImage: 'assets/playlists_before.png',
          onIconTap: (_) {},
          trailing: const Icon(Icons.play_circle_outline),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MediaStatusIconsRow),
          matching: find.byIcon(Icons.play_circle_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders without a trailing control', (tester) async {
      await pumpApp(
        tester,
        MediaStatusIconsRow(
          seenImage: 'assets/seen_before.png',
          watchlistImage: 'assets/watchlist_before.png',
          favImage: 'assets/fav_before.png',
          listImage: 'assets/playlists_before.png',
          onIconTap: (_) {},
        ),
      );

      expect(find.byType(Image), findsNWidgets(4));
    });
  });
}
