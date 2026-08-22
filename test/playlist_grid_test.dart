/// Tests for the home page's playlist grid.
///
/// The column count here has been wrong twice, in opposite directions, and
/// both times because it was decided from the wrong number:
///
///   * capping a card's width with no minimum column count collapsed a phone
///     to a single full-bleed card at twice the intended height;
///   * then reading the width from an enclosing scope instead of measuring the
///     box counted columns for the whole window and drew them into the list
///     pane of a two pane layout, so the cards overflowed.
///
/// The grid is a widget of its own so both can be stated as tests. The home
/// page itself needs Firestore, TMDB and a signed in user before it draws
/// anything, which is why this was never covered from there.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/playlist_grid.dart';

void main() {
  /// Pumps the grid into a [boxWidth]-wide box inside a [windowWidth]-wide
  /// window, which is what a two pane layout does to it.
  Future<void> pumpInPane(
    WidgetTester tester, {
    required double windowWidth,
    required double boxWidth,
    int itemCount = 6,
  }) async {
    tester.view.physicalSize = Size(windowWidth, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: boxWidth,
                  child: PlaylistGrid(
                    itemCount: itemCount,
                    itemBuilder: (context, index) =>
                        ColoredBox(color: Colors.grey, child: Text('$index')),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int renderedColumns(WidgetTester tester) {
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    return delegate.crossAxisCount;
  }

  group('columns come from the box, not the window', () {
    testWidgets('a narrow pane in a wide window does not overflow',
        (tester) async {
      // An iPad Pro 11 in landscape: the rail takes its share and the rest is
      // split, leaving the home page about 565 of the 1210 points. Counting
      // from the window gives four columns, which is what overflowed.
      await pumpInPane(tester, windowWidth: 1210, boxWidth: 565);

      expect(renderedColumns(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the window alone would have answered differently',
        (tester) async {
      // States the bug as a difference: the two numbers really do disagree,
      // so this fails the moment the grid goes back to reading the window.
      expect(PlaylistGrid.columnsFor(1210), 4);
      expect(PlaylistGrid.columnsFor(565), 2);

      await pumpInPane(tester, windowWidth: 1210, boxWidth: 565);
      expect(renderedColumns(tester), PlaylistGrid.columnsFor(565));
    });

    testWidgets('a pane with room for more columns gets them', (tester) async {
      // The floor must not become a ceiling: a wide pane still gains columns.
      await pumpInPane(tester, windowWidth: 2560, boxWidth: 1600);

      expect(renderedColumns(tester), greaterThan(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('a phone keeps a grid', () {
    testWidgets('a full width phone window draws two columns', (tester) async {
      // The first bug: at 390 the card cap divided to exactly one column.
      await pumpInPane(tester, windowWidth: 390, boxWidth: 390);

      expect(renderedColumns(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the narrowest shipping phone still draws two columns',
        (tester) async {
      await pumpInPane(tester, windowWidth: 375, boxWidth: 375);

      expect(renderedColumns(tester), 2);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('fewer playlists than columns still lays out', (tester) async {
    await pumpInPane(tester, windowWidth: 390, boxWidth: 390, itemCount: 1);

    expect(renderedColumns(tester), 2);
    expect(tester.takeException(), isNull);
  });
}
