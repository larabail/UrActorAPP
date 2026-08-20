import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/tab_view.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

/// A tile with no poster, so nothing tries to decode an image over the network
/// and the badges are the only thing under test.
const Map<String, dynamic> _movieData = {
  'id': 42,
  'title': 'Missing poster',
  'poster_path': null,
};

const List<dynamic> _moviePair = ['Movies', '42'];

Future<void> _pumpTile(
  WidgetTester tester,
  Widget Function(BuildContext) build,
) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: Builder(builder: build)),
    ),
  );
}

Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

/// Puts the movie behind [_moviePair] in both of the user's lists, so a test
/// only has to say which badge it expects to be suppressed.
void _installUserWithBothMemberships() {
  final user = installTestUser();
  user.favMovies = [
    ['Movies', '42'],
  ];
  user.watchlist = [
    ['Movies', '42'],
  ];
}

void main() {
  testWidgets('favorite badge renders a heart with a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
              favoriteBadgeSemanticLabel: 'In your favorites',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
    expect(_semanticsLabelled('In your favorites'), findsOneWidget);
  });

  testWidgets('favorite badge is absent without a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
  });

  testWidgets('watchlist badge renders a bookmark with a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
              watchlistBadgeSemanticLabel: 'In your watchlist',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    expect(_semanticsLabelled('In your watchlist'), findsOneWidget);
  });

  testWidgets('watchlist badge is absent without a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
  });

  testWidgets('the two badges sit on opposite bottom corners', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
              favoriteBadgeSemanticLabel: 'In your favorites',
              watchlistBadgeSemanticLabel: 'In your watchlist',
            ),
          ),
        ),
      ),
    );

    final heart = tester.getCenter(find.byKey(const ValueKey('favoriteBadge')));
    final bookmark =
        tester.getCenter(find.byKey(const ValueKey('watchlistBadge')));

    expect(heart.dx, lessThan(bookmark.dx));
    expect(heart.dy, equals(bookmark.dy));
  });

  group('badges resolved from the media pair', () {
    testWidgets('shows both badges for an item in both lists', (tester) async {
      _installUserWithBothMemberships();

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          _movieData,
          'media',
          mediaPair: _moviePair,
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
      expect(_semanticsLabelled('In your favorites'), findsOneWidget);
      expect(_semanticsLabelled('In your watchlist'), findsOneWidget);
    });

    testWidgets('shows only the heart for a favourite that is not queued',
        (tester) async {
      final user = installTestUser();
      user.favMovies = [
        ['Movies', '42'],
      ];

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          _movieData,
          'media',
          mediaPair: _moviePair,
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });

    testWidgets('shows neither badge for an item in neither list',
        (tester) async {
      final user = installTestUser();
      user.favMovies = [
        ['Movies', '7'],
      ];
      user.watchlist = [
        ['Movies', '7'],
      ];

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          _movieData,
          'media',
          mediaPair: _moviePair,
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });

    testWidgets('reads the TV lists for a TV pair', (tester) async {
      final user = installTestUser();
      user.favTVShows = [
        ['TVShows', '99'],
      ];
      user.watchlistTVShows = [
        ['TVShows', '99'],
      ];

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          {'id': 99, 'name': 'Missing poster', 'poster_path': null},
          'media',
          mediaPair: const ['TVShows', '99'],
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('leaves a tile without a media pair unbadged', (tester) async {
      _installUserWithBothMemberships();

      await _pumpTile(
        tester,
        (context) => getItemContainer(context, _movieData, 'person'),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });

    testWidgets('the Favorites page suppresses only the heart', (tester) async {
      _installUserWithBothMemberships();

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          _movieData,
          'media',
          mediaPair: _moviePair,
          showFavoriteBadge: false,
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('the Watchlist page suppresses only the bookmark',
        (tester) async {
      _installUserWithBothMemberships();

      await _pumpTile(
        tester,
        (context) => getItemContainer(
          context,
          _movieData,
          'media',
          mediaPair: _moviePair,
          showWatchlistBadge: false,
        ),
      );

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });
  });

  group('badges on a media grid', () {
    /// Renders the grid the way each screen configures it, over a single movie
    /// the test user has both favourited and put on the watchlist.
    Future<void> pumpGrid(
      WidgetTester tester, {
      bool showFavoriteBadge = true,
      bool showWatchlistBadge = true,
    }) async {
      _installUserWithBothMemberships();

      final stub = HttpStub();
      stub.on('/movie/42', json: {
        'id': 42,
        'title': 'Missing poster',
        'poster_path': null,
      });
      installHttpStub(stub);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: MyTabView(
              favItems: const [
                ['Movies', '42'],
              ],
              showFavoriteBadge: showFavoriteBadge,
              showWatchlistBadge: showWatchlistBadge,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows both badges by default', (tester) async {
      await pumpGrid(tester);

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('drops the heart the way the Favorites page does',
        (tester) async {
      await pumpGrid(tester, showFavoriteBadge: false);

      expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsOneWidget);
    });

    testWidgets('drops the bookmark the way the Watchlist page does',
        (tester) async {
      await pumpGrid(tester, showWatchlistBadge: false);

      expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('watchlistBadge')), findsNothing);
    });
  });
}
