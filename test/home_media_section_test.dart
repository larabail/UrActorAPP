import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/home_media_section.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

/// A window wide enough for the section header's own text.
///
/// Widget tests draw with a placeholder font whose glyphs are square, so a
/// heading measures roughly its character count times its point size — far
/// wider than the real font. The header row overflows a phone-width window for
/// that reason alone, which says nothing about the layout on a device. A wide
/// window keeps these tests measuring badges rather than glyph metrics.
void useWideSurface(WidgetTester tester) =>
    usePhoneSurface(tester, size: const Size(1000, 900));

/// The home page previews the watchlist, the favourites and the seen list.
///
/// A membership badge only says something when the surface it sits on is not
/// already defined by that membership. Inside the watchlist preview every tile
/// is on the watchlist, so a bookmark on each one marks all of them and
/// distinguishes none — the same reasoning the Watchlist and Favorites pages
/// already apply. The seen preview is the case that proves the rule is about
/// the section rather than a blanket suppression: a seen title may or may not
/// be a favourite, and may or may not still be on the watchlist, so both
/// badges are worth showing there.
void main() {
  late HttpStub http;

  const onBothLists = [
    ['Movies', '42'],
  ];

  final favoriteBadge = find.byKey(const ValueKey('favoriteBadge'));
  final watchlistBadge = find.byKey(const ValueKey('watchlistBadge'));

  setUp(() {
    final user = installTestUser();
    // The same title in both lists, so a missing badge can only be the
    // section's doing and never a gap in the fixture.
    user.favMovies = [
      ['Movies', '42'],
    ];
    user.watchlist = [
      ['Movies', '42'],
    ];
    installFakeFirestore();
    http = installHttpStub();
    http.on('/3/movie/42', json: {
      'id': 42,
      'title': 'A film on both lists',
      'poster_path': null,
    });
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    bool showFavoriteBadge = true,
    bool showWatchlistBadge = true,
  }) async {
    useWideSurface(tester);
    ignoreNetworkImageFailures();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: HomeMediaSection(
            title: 'Section',
            content: onBothLists,
            icon: Icons.bookmark,
            page: const SizedBox.shrink(),
            showFavoriteBadge: showFavoriteBadge,
            showWatchlistBadge: showWatchlistBadge,
          ),
        ),
      ),
    );
    // The TMDB lookup behind each tile is a future, so one pump is not enough
    // to see the finished row.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('the watchlist section drops the bookmark and keeps the heart',
      (tester) async {
    await pumpSection(tester, showWatchlistBadge: false);

    expect(tester.takeException(), isNull);
    expect(watchlistBadge, findsNothing);
    expect(favoriteBadge, findsOneWidget);
  });

  testWidgets('the favourites section drops the heart and keeps the bookmark',
      (tester) async {
    await pumpSection(tester, showFavoriteBadge: false);

    expect(tester.takeException(), isNull);
    expect(favoriteBadge, findsNothing);
    expect(watchlistBadge, findsOneWidget);
  });

  testWidgets('the seen section keeps both badges', (tester) async {
    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(favoriteBadge, findsOneWidget);
    expect(watchlistBadge, findsOneWidget);
  });

  testWidgets('a title on neither list carries no badge in any section',
      (tester) async {
    installTestUser();
    http.on('/3/movie/42', json: {
      'id': 42,
      'title': 'A film on no list',
      'poster_path': null,
    });

    await pumpSection(tester);

    expect(tester.takeException(), isNull);
    expect(favoriteBadge, findsNothing);
    expect(watchlistBadge, findsNothing);
  });

  testWidgets('an empty section says so and asks TMDB for nothing',
      (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: HomeMediaSection(
            title: 'Section',
            content: const [],            icon: Icons.bookmark,
            page: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsNothing);
    expect(http.requests, isEmpty);
  });

  testWidgets('a section previews at most ten titles however long the list is',
      (tester) async {    final many = List.generate(25, (i) => ['Movies', '$i']);
    http.on('/3/movie/', json: {
      'id': 1,
      'title': 'Any',
      'poster_path': null,
    });
    useWideSurface(tester);
    ignoreNetworkImageFailures();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: HomeMediaSection(
            title: 'Section',
            content: many,
            icon: Icons.bookmark,
            page: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // The "see all" count still reports the whole list, not the preview.
    expect(find.textContaining('25'), findsOneWidget);
    expect(http.requests.length, lessThanOrEqualTo(HomeMediaSection.previewLimit));
  });

  // The named constructors are what the home page actually calls, so these pin
  // the rule itself rather than the mechanism. Before this fix every section
  // was built the same way and all three of these would have reported both
  // badges on.
  group('the rule each home section is built with', () {

    test('the watchlist section suppresses only the bookmark', () {
      const section = HomeMediaSection.watchlist(
        title: 'x',
        content: [],
        icon: Icons.bookmark,
        page: SizedBox.shrink(),
      );
      expect(section.showWatchlistBadge, isFalse);
      expect(section.showFavoriteBadge, isTrue);
    });

    test('the favourites section suppresses only the heart', () {
      const section = HomeMediaSection.favorites(
        title: 'x',
        content: [],
        icon: Icons.bookmark,
        page: SizedBox.shrink(),
      );
      expect(section.showFavoriteBadge, isFalse);
      expect(section.showWatchlistBadge, isTrue);
    });

    test('the seen section suppresses neither', () {
      const section = HomeMediaSection.seen(
        title: 'x',
        content: [],
        icon: Icons.bookmark,
        page: SizedBox.shrink(),
      );
      expect(section.showFavoriteBadge, isTrue);
      expect(section.showWatchlistBadge, isTrue);
    });
  });
}