import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/watch_progress_controller.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/season_guide.dart';

import 'support/harness.dart';

/// Seasons with no artwork, so the tiles fall back to the bundled placeholder
/// and nothing reaches for the network. What is under test is the layout, not
/// the images.
const List<Map<String, dynamic>> _seasons = [
  {
    'name': 'Season 1',
    'season_number': 1,
    'episode_count': 2,
    'poster_path': null,
  },
  {
    'name': 'Season 2',
    'season_number': 2,
    'episode_count': 3,
    'poster_path': null,
  },
];

const Map<String, dynamic> _seasonOne = {
  'name': 'Season 1',
  'season_number': 1,
  'episode_count': 2,
  'poster_path': null,
};

TVShow _show() => TVShow(id: '77', title: 'A show', coverPhoto: '');

ShowProgressController _controller() {
  final controller = ShowProgressController(
    showId: '77',
    seasons: const [
      SeasonEpisodeCount(seasonNumber: 1, episodeCount: 2),
      SeasonEpisodeCount(seasonNumber: 2, episodeCount: 3),
    ],
  );
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    installTestUser(uid: 'season-guide-user');
    installFakeFirestore();
  });

  testWidgets('a season row lays out and shows its name and episode count',
      (tester) async {
    usePhoneSurface(tester);
    final controller = _controller();
    await controller.load();

    await _pump(
      tester,
      Seasons(items: _seasons, show: _show(), progress: controller),
    );

    expect(tester.takeException(), isNull);
    // The name also appears over the placeholder poster, so the episode count
    // is what identifies the caption of each card.
    expect(find.text('Season 1'), findsWidgets);
    expect(find.text('2 episodes'), findsOneWidget);
    expect(find.text('3 episodes'), findsOneWidget);
  });

  testWidgets('a season row stays inside the width the list gives it',
      (tester) async {
    usePhoneSurface(tester);
    final controller = _controller();
    await controller.load();

    await _pump(
      tester,
      Seasons(items: _seasons, show: _show(), progress: controller),
    );

    final double listWidth = tester.getSize(find.byType(Seasons)).width;
    for (final card in tester.widgetList(find.byType(ItemCard))) {
      expect(
        tester.getSize(find.byWidget(card)).width,
        lessThanOrEqualTo(listWidth),
      );
    }
  });

  testWidgets('an episode row lays out and shows its number and title',
      (tester) async {
    usePhoneSurface(tester);
    final http = installHttpStub();
    http.on('/season/1/episode/1', json: {
      'episode_number': 1,
      'name': 'Pilot',
      'still_path': null,
    });
    http.on('/season/1/episode/2', json: {
      'episode_number': 2,
      'name': 'The second one',
      'still_path': null,
    });
    http.on('/credits', json: {'cast': [], 'crew': [], 'guest_stars': []});

    final controller = _controller();
    await controller.load();

    await _pump(
      tester,
      Episodes(seasonData: _seasonOne, show: _show(), progress: controller),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pilot'), findsOneWidget);
    expect(find.text('The second one'), findsOneWidget);
  });
}
