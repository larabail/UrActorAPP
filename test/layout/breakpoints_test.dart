/// Tests for the window size rules the responsive layout is built on.
///
/// The app was written for a phone held upright and sized its poster tiles as
/// a fraction of the window — `width * 0.28` by `height * 0.18`. That makes a
/// tile's proportions follow the window's proportions, so the tiles were only
/// ever the shape of a poster on a portrait phone. The regression at the
/// bottom of this file pins that down with the actual arithmetic, because it
/// is the defect the whole layout change exists to fix and a screenshot is a
/// poor way to notice it coming back.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/layout/breakpoints.dart';

void main() {
  group('windowSizeClassFor', () {
    test('a phone held upright is compact', () {
      expect(windowSizeClassFor(393), WindowSizeClass.compact);
    });

    test('a phone held sideways is medium', () {
      expect(windowSizeClassFor(852), WindowSizeClass.medium);
    });

    test('a tablet held sideways is expanded', () {
      expect(windowSizeClassFor(1194), WindowSizeClass.expanded);
    });

    test('a desktop window is large', () {
      expect(windowSizeClassFor(1920), WindowSizeClass.large);
    });

    test('each boundary belongs to the class it opens', () {
      expect(windowSizeClassFor(Breakpoints.medium), WindowSizeClass.medium);
      expect(
          windowSizeClassFor(Breakpoints.expanded), WindowSizeClass.expanded);
      expect(windowSizeClassFor(Breakpoints.large), WindowSizeClass.large);
    });

    test('one pixel below a boundary is still the class beneath it', () {
      expect(
          windowSizeClassFor(Breakpoints.medium - 1), WindowSizeClass.compact);
      expect(
          windowSizeClassFor(Breakpoints.expanded - 1), WindowSizeClass.medium);
      expect(
          windowSizeClassFor(Breakpoints.large - 1), WindowSizeClass.expanded);
    });

    test('a degenerate width does not throw', () {
      expect(windowSizeClassFor(0), WindowSizeClass.compact);
    });
  });

  group('navigationStyleFor', () {
    test('a phone keeps the bottom bar within thumb reach', () {
      expect(navigationStyleFor(WindowSizeClass.compact),
          NavigationStyle.bottomBar);
    });

    test('a short window trades the bottom bar for a rail', () {
      expect(navigationStyleFor(WindowSizeClass.medium), NavigationStyle.rail);
      expect(
          navigationStyleFor(WindowSizeClass.expanded), NavigationStyle.rail);
    });

    test('only the widest window can afford labels on the rail', () {
      expect(navigationStyleFor(WindowSizeClass.large),
          NavigationStyle.extendedRail);
    });
  });

  group('usesTwoPanes', () {
    test('a single pane below expanded', () {
      expect(usesTwoPanes(WindowSizeClass.compact), isFalse);
      expect(usesTwoPanes(WindowSizeClass.medium), isFalse);
    });

    test('two panes from expanded upwards', () {
      expect(usesTwoPanes(WindowSizeClass.expanded), isTrue);
      expect(usesTwoPanes(WindowSizeClass.large), isTrue);
    });
  });

  group('landscapeMeansFullScreen', () {
    // Turning a phone sideways is a deliberate act, and a phone on its side
    // has room for the video and nothing else, so the trailer player is right
    // to read it as a request to fill the window.
    test('a landscape phone is asking for the video to fill the window', () {
      expect(landscapeMeansFullScreen(WindowSizeClass.compact), isTrue);
      expect(landscapeMeansFullScreen(WindowSizeClass.medium), isTrue);
    });

    // A tablet held horizontally is not asking for anything: landscape is
    // where it lives. Reading it as a request made the trailer take over the
    // detail pane on its own the first time the window metrics changed.
    test('a window with two panes is landscape by nature, not by request', () {
      expect(landscapeMeansFullScreen(WindowSizeClass.expanded), isFalse);
      expect(landscapeMeansFullScreen(WindowSizeClass.large), isFalse);
    });

    test('it is the exact complement of having two panes', () {
      for (final size in WindowSizeClass.values) {
        expect(landscapeMeansFullScreen(size), !usesTwoPanes(size));
      }
    });
  });

  group('poster geometry', () {
    test('a poster is two by three whatever width it is given', () {
      for (final width in <double>[104, 120, 132, 144, 300]) {
        expect(
            width / posterHeightFor(width), closeTo(kPosterAspectRatio, 1e-9));
      }
    });

    test('tiles grow with the window but never as fast as the window', () {
      final compact = posterWidthFor(WindowSizeClass.compact);
      final large = posterWidthFor(WindowSizeClass.large);

      // The window roughly quintuples between a phone and a desktop. The tile
      // must not, or a desktop shows no more posters than a phone does.
      expect(large, greaterThan(compact));
      expect(large / compact, lessThan(2));
    });

    test('every class gets a usable tile width', () {
      for (final size in WindowSizeClass.values) {
        expect(posterWidthFor(size), greaterThan(0));
      }
    });
  });

  group('gridColumnsFor', () {
    test('a phone fits three posters across', () {
      expect(
        gridColumnsFor(393 - 32, targetTileWidth: 104, spacing: 8),
        3,
      );
    });

    test('a tablet in landscape fits far more than a phone', () {
      final phone = gridColumnsFor(393, targetTileWidth: 104, spacing: 8);
      final tablet = gridColumnsFor(1194, targetTileWidth: 132, spacing: 12);

      expect(tablet, greaterThan(phone));
    });

    test('the count rises as the window widens', () {
      int previous = 0;
      for (final width in <double>[400, 800, 1200, 1600]) {
        final columns =
            gridColumnsFor(width, targetTileWidth: 120, spacing: 12);
        expect(columns, greaterThanOrEqualTo(previous));
        previous = columns;
      }
    });

    test('a very narrow window still shows more than one tile', () {
      expect(
        gridColumnsFor(120, targetTileWidth: 104, spacing: 8),
        greaterThanOrEqualTo(2),
      );
    });

    test('a very wide window does not shrink tiles to thumbnails', () {
      expect(
        gridColumnsFor(5000, targetTileWidth: 104, spacing: 8, maxColumns: 12),
        12,
      );
    });

    test('a zero width falls back rather than dividing by nothing', () {
      expect(gridColumnsFor(0, targetTileWidth: 104), 2);
      expect(gridColumnsFor(400, targetTileWidth: 0), 2);
    });

    test('an unbounded width falls back rather than throwing', () {
      // A horizontally scrolling parent offers infinite width while it
      // measures its children. Rounding infinity is an unsupported operation,
      // so this crashed rather than laying anything out.
      expect(gridColumnsFor(double.infinity, targetTileWidth: 104), 2);
      expect(gridColumnsFor(400, targetTileWidth: double.infinity), 2);
    });

    test('spacing is counted between columns and not outside them', () {
      // Three 100pt tiles with 10pt gaps need 320pt, not 330pt. A formula
      // that charges for a trailing gap drops to two columns here.
      expect(
        gridColumnsFor(320, targetTileWidth: 100, spacing: 10),
        3,
      );
    });

    test('a width that nearly fits another column gets one', () {
      // The count is rounded rather than floored, because the leftover is
      // handed to the tiles. Flooring here would leave 95% of a column spare
      // and inflate three tiles to swallow it.
      expect(
        gridColumnsFor(419, targetTileWidth: 100, spacing: 0),
        4,
      );
    });
  });

  group('posterGridMetricsFor', () {
    // The width of an iPhone 15 Pro, which is what the defect was reported on.
    const double phone = 393;

    test('the columns divide the width exactly', () {
      final grid = posterGridMetricsFor(phone, targetTileWidth: 104);

      // The whole point: no dead space against the trailing edge. Every grid
      // in the app used to draw fixed-width tiles and leave the remainder —
      // here 36 logical pixels, a third of a poster — piled up on the right.
      expect(grid.cellWidth * grid.columns, moreOrLessEquals(phone));
    });

    test('a phone still shows three posters across', () {
      expect(posterGridMetricsFor(phone, targetTileWidth: 104).columns, 3);
    });

    test('the tiles grow to take up the slack rather than leaving it', () {
      final grid = posterGridMetricsFor(phone, targetTileWidth: 104);

      expect(grid.tileWidth, greaterThan(104));
    });

    test('a cell is its tile plus the margins the tile carries', () {
      final grid = posterGridMetricsFor(phone, targetTileWidth: 104);

      expect(grid.cellWidth, grid.tileWidth + kPosterTileMarginWidth);
    });

    test('a wider region gets more posters, not bigger ones', () {
      final narrow = posterGridMetricsFor(phone, targetTileWidth: 104);
      final wide = posterGridMetricsFor(840, targetTileWidth: 132);

      expect(wide.columns, greaterThan(narrow.columns));
      // A poster that kept growing with the window would be four times the
      // size of a phone's by the time it reached a desktop.
      expect(wide.tileWidth, lessThan(narrow.tileWidth * 2));
    });

    test('no tile strays far from the width it asked for', () {
      // Rounding the column count bounds how far sharing out the surplus can
      // push a tile. Flooring instead let a 320pt phone reach 145 against a
      // 104 target, half as wide again as the same poster on a 393pt one.
      for (double width = 200; width <= 1600; width += 1) {
        final grid = posterGridMetricsFor(width, targetTileWidth: 104);
        if (grid.columns <= 2 || grid.columns >= 12) continue;
        expect(grid.tileWidth, greaterThan(104 * 0.8));
        expect(grid.tileWidth, lessThan(104 * 1.25));
      }
    });

    test('the count never falls as the region widens', () {
      int previous = 0;
      for (double width = 200; width <= 2000; width += 1) {
        final columns =
            posterGridMetricsFor(width, targetTileWidth: 104).columns;
        expect(columns, greaterThanOrEqualTo(previous));
        previous = columns;
      }
    });

    test('a region being measured rather than laid out keeps the aim', () {
      // A horizontally scrolling parent offers infinite width. Sharing that
      // out gives every tile a width of NaN, which is a crash and not a
      // layout.
      expect(
        posterGridMetricsFor(double.infinity, targetTileWidth: 104).tileWidth,
        104,
      );
      expect(posterGridMetricsFor(0, targetTileWidth: 104).tileWidth, 104);
      expect(posterGridMetricsFor(-50, targetTileWidth: 104).tileWidth, 104);
    });

    test('a region narrower than the margins still yields a usable tile', () {
      // Two cells of 10pt are narrower than the 15pt of margin inside each,
      // so the arithmetic wants a negative width. Negative is a crash rather
      // than a small tile.
      final grid = posterGridMetricsFor(20, targetTileWidth: 104);

      expect(grid.tileWidth, greaterThan(0));
    });
  });

  group('gridColumnsForMaxTileWidth', () {
    // The delegate this helper replaced was
    // SliverGridDelegateWithMaxCrossAxisExtent, whose count is this same
    // division with no floor under it. Reproduced here so the tests below can
    // state the regression as a difference rather than as an assertion about
    // a number nobody can place.
    int withoutFloor(double availableWidth) =>
        (availableWidth / (kPlaylistCardMaxWidth + kPlaylistGridSpacing))
            .ceil();

    double playlistGridWidth(double windowWidth) =>
        windowWidth - kPlaylistGridPadding * 2;

    int playlistColumns(double windowWidth) => gridColumnsForMaxTileWidth(
          playlistGridWidth(windowWidth),
          maxTileWidth: kPlaylistCardMaxWidth,
          spacing: kPlaylistGridSpacing,
          minColumns: 2,
        );

    test('a phone keeps two columns of playlists', () {
      // The widths that regressed. Every one of these is a shipping phone,
      // and on every one of them the home page showed a single column of
      // cards stretched across the window.
      for (final double width in <double>[375, 384, 390]) {
        expect(
          playlistColumns(width),
          2,
          reason: 'a $width pt window should still show a grid',
        );
      }
    });

    test('the floor is what a phone needed, not the division', () {
      // States the bug in numbers: without the clamp the arithmetic really
      // does answer one, so this test fails the moment the floor is removed.
      expect(withoutFloor(playlistGridWidth(390)), 1);
      expect(playlistColumns(390), 2);
    });

    test('a card never gets wider than the ceiling once past two columns', () {
      // Above the floor the ceiling is the whole contract, so check the width
      // the columns actually work out to rather than the count.
      for (final double width in <double>[800, 1024, 1440, 1920]) {
        final int columns = playlistColumns(width);
        final double cardWidth =
            (playlistGridWidth(width) - kPlaylistGridSpacing * (columns - 1)) /
                columns;

        expect(
          cardWidth,
          lessThanOrEqualTo(kPlaylistCardMaxWidth),
          reason: 'a $width pt window stretched a card past its cap',
        );
      }
    });

    test('a wide window gains columns rather than bigger cards', () {
      expect(playlistColumns(1440), greaterThan(playlistColumns(390)));
    });

    test('the count never falls as the window widens', () {
      int previous = 0;
      for (final double width in <double>[375, 600, 900, 1200, 1600, 2400]) {
        final int columns = playlistColumns(width);
        expect(columns, greaterThanOrEqualTo(previous));
        previous = columns;
      }
    });

    test('a very wide window does not shred the grid into slivers', () {
      expect(
        gridColumnsForMaxTileWidth(20000,
            maxTileWidth: 360, spacing: 10, maxColumns: 12),
        12,
      );
    });

    test('a zero width falls back rather than dividing by nothing', () {
      expect(gridColumnsForMaxTileWidth(0, maxTileWidth: 360), 2);
      expect(gridColumnsForMaxTileWidth(400, maxTileWidth: 0), 2);
    });
  });

  group('detailPaneWidthFor', () {
    test('splits evenly in the middle of the range', () {
      expect(detailPaneWidthFor(1200), 600);
    });

    test('never leaves the detail pane too narrow to lay a media page out', () {
      expect(
        detailPaneWidthFor(Breakpoints.expanded),
        greaterThanOrEqualTo(kMinDetailPaneWidth),
      );
    });

    test('stops widening a column of text on an ultrawide monitor', () {
      expect(detailPaneWidthFor(3440), kMaxDetailPaneWidth);
    });

    test('always leaves the list pane something to work with', () {
      for (final width in <double>[1024, 1280, 1440, 1920, 2560, 3440]) {
        expect(
          width - detailPaneWidthFor(width),
          greaterThanOrEqualTo(kMinDetailPaneWidth),
          reason: 'list pane starved at $width',
        );
      }
    });
  });

  group('regression: tiles are no longer sized from the window', () {
    // The arithmetic the app used to use, kept here so the bug it caused can
    // be stated rather than described.
    double oldTileAspect(double windowWidth, double windowHeight) =>
        (windowWidth * 0.28) / (windowHeight * 0.18);

    test('the old rule only produced a poster shape on a portrait phone', () {
      expect(oldTileAspect(393, 852), closeTo(0.72, 0.02));

      // Everywhere else it was wildly wrong, which is what the redesign fixes.
      expect(oldTileAspect(834, 1194), greaterThan(1.0)); // iPad upright
      expect(oldTileAspect(1194, 834), greaterThan(2.0)); // iPad sideways
      expect(oldTileAspect(1920, 1080), greaterThan(2.5)); // desktop
    });

    test('the new rule is a poster shape at every window size', () {
      for (final size in WindowSizeClass.values) {
        final width = posterWidthFor(size);
        expect(
          width / posterHeightFor(width),
          closeTo(kPosterAspectRatio, 1e-9),
          reason: '$size produced a tile that is not poster shaped',
        );
      }
    });
  });
}
