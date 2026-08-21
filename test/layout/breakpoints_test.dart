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

    test('spacing is counted between columns and not outside them', () {
      // Three 100pt tiles with 10pt gaps need 320pt, not 330pt. A formula
      // that charges for a trailing gap drops to two columns here.
      expect(
        gridColumnsFor(320, targetTileWidth: 100, spacing: 10),
        3,
      );
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
