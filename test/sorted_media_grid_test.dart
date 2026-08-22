import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/layout/breakpoints.dart';
import 'package:uractor/common/sorted_media_grid.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

/// The grid every list of posters is built from — Seen, Watchlist, Favorites
/// and a playlist all render one.
///
/// It used to pick a column count and then draw tiles at a fixed width, so
/// whatever the division left over piled up as dead space against the trailing
/// edge. On a phone that was three posters hugging the left and a visible gap
/// on the right, which is what these tests are here to stop coming back.
void main() {
  late HttpStub http;

  /// Nine titles, so a phone gets three full rows and no partial one to
  /// confuse a measurement of where the last column ends.
  final List<dynamic> nineMovies = [
    for (int id = 1; id <= 9; id++) ['Movies', '$id'],
  ];

  setUp(() {
    installTestUser();
    installFakeFirestore();
    http = installHttpStub();
    for (int id = 1; id <= 9; id++) {
      http.on('/3/movie/$id', json: {
        'id': id,
        'title': 'Film $id',
        // No poster keeps the network out of it; the tile still takes up
        // exactly the room a poster would.
        'poster_path': null,
      });
    }
  });

  Future<void> pumpGrid(WidgetTester tester, {required double width}) async {
    usePhoneSurface(tester, size: Size(width, 1200));
    ignoreNetworkImageFailures();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SortedMediaGrid(items: nineMovies)),
      ),
    );
    // Each tile's TMDB lookup is a future, so one pump is not enough to see a
    // finished row.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// The rectangles of the tiles making up the first row, in order.
  List<Rect> firstRowTiles(WidgetTester tester, int columns) {
    final rects = tester
        .widgetList<ItemCard>(find.byType(ItemCard))
        .map((card) => tester.getRect(find.byWidget(card)))
        .toList();
    return rects.take(columns).toList();
  }

  testWidgets('a row of posters reaches the trailing edge', (tester) async {
    const double width = 393;
    await pumpGrid(tester, width: width);

    final grid = posterGridMetricsFor(width, targetTileWidth: 104);
    final row = firstRowTiles(tester, grid.columns);

    expect(row, hasLength(3));
    // The defect: the last tile used to stop 36 logical pixels short, a third
    // of a poster of dead space with nothing to explain it.
    expect(row.last.right, moreOrLessEquals(width, epsilon: 0.5));
  });

  testWidgets('a row starts at the leading edge', (tester) async {
    await pumpGrid(tester, width: 393);

    final row = firstRowTiles(tester, 3);

    expect(row.first.left, 0);
  });

  testWidgets('the tiles in a row are all the same width', (tester) async {
    await pumpGrid(tester, width: 393);

    final row = firstRowTiles(tester, 3);

    for (final tile in row) {
      expect(tile.width, moreOrLessEquals(row.first.width, epsilon: 0.5));
    }
  });

  testWidgets('the columns of one row sit under the columns of the next',
      (tester) async {
    await pumpGrid(tester, width: 393);

    final rects = tester
        .widgetList<ItemCard>(find.byType(ItemCard))
        .map((card) => tester.getRect(find.byWidget(card)))
        .toList();

    expect(rects.length, greaterThanOrEqualTo(6));
    for (int column = 0; column < 3; column++) {
      expect(
        rects[column + 3].left,
        moreOrLessEquals(rects[column].left, epsilon: 0.5),
        reason: 'column $column drifted between the first and second row',
      );
    }
  });

  testWidgets('a wider window fills its rows too', (tester) async {
    const double width = 900;
    await pumpGrid(tester, width: width);

    final grid = posterGridMetricsFor(width, targetTileWidth: 120);
    final row = firstRowTiles(tester, grid.columns);

    expect(grid.columns, greaterThan(3));
    expect(row.last.right, moreOrLessEquals(width, epsilon: 0.5));
  });
}
