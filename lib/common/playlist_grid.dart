/// The grid the home page arranges its playlist cards in.
///
/// Only the shell lives here — how many columns to draw and how wide a card
/// may be — with the cards themselves still built by the home page. That split
/// is the point: the column count is the part that has now gone wrong twice,
/// and the home page cannot be pumped in a test without Firestore, TMDB and a
/// signed in user behind it, so the arithmetic has to be reachable on its own.
///
/// Both failures were the same mistake in different clothes: deciding from a
/// number that was not the width of the box the grid was actually given.
library;

import 'package:flutter/material.dart';

import 'layout/breakpoints.dart';
import 'layout/responsive.dart';

/// A grid of playlist cards that fits its columns to the space it is given.
class PlaylistGrid extends StatelessWidget {
  const PlaylistGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// How many columns [availableWidth] logical pixels of grid should hold.
  ///
  /// Exposed so a test can state the answer for a window and for a pane
  /// without going through a rendered frame.
  static int columnsFor(double availableWidth) => gridColumnsForMaxTileWidth(
        availableWidth - kPlaylistGridPadding * 2,
        maxTileWidth: kPlaylistCardMaxWidth,
        spacing: kPlaylistGridSpacing,
        minColumns: 2,
      );

  @override
  Widget build(BuildContext context) {
    // ResponsiveRegion measures the box this grid occupies. Reading the width
    // from an enclosing LayoutScope instead is not the same thing and was the
    // iPad bug: the home page holds the context of the screen, which sits
    // above the scope the two pane layout publishes, so the lookup missed it
    // and fell back to the whole window. The grid then counted columns for a
    // 1210pt window and drew them into a 565pt pane, and the cards overflowed
    // by the difference.
    return ResponsiveRegion(
      builder: (context, _) {
        final int columns = columnsFor(LayoutScope.widthOf(context));

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: kPlaylistCardAspectRatio,
            crossAxisSpacing: kPlaylistGridSpacing,
            mainAxisSpacing: kPlaylistGridSpacing,
          ),
          padding: const EdgeInsets.all(kPlaylistGridPadding),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
