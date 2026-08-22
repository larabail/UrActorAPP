import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import 'scrolling_line.dart';

/// A poster from a person's filmography, with the part they played under it.
///
/// The label used to be drawn *over* the artwork, near the foot of the poster.
/// That is where posters put their own title, so the two collided and neither
/// could be read; and the space a poster has is fixed, so anything longer than
/// about a dozen characters — "Narrator (voice)", "Executive Producer" — was
/// cut off mid-word. It sat in a horizontally scrollable box, which in
/// principle let the reader drag the rest into view, but that box is inside a
/// vertically scrolling grid of them and dragging it is fiddly enough that the
/// text may as well have been clipped.
///
/// Putting the line under the poster costs one row of height per grid row and
/// buys a label that is never fighting the artwork behind it. It still cannot
/// be widened — the tile is as wide as the tile is — so a line too long to fit
/// scrolls itself instead of waiting to be dragged.
///
/// [poster] is expected to be the tile from `getItemContainer`, which carries
/// its own margin; the overlays here are placed to match it.
class CreditTile extends StatelessWidget {
  const CreditTile({
    super.key,
    required this.poster,
    required this.label,
    required this.tileWidth,
    this.watched = false,
    this.awards = 0,
  });

  /// The artwork, already sized and margined.
  final Widget poster;

  /// What the person did on this title. Empty keeps the space without
  /// drawing anything, so the grid stays square.
  final String label;

  /// The width of the artwork itself, excluding the margin around it.
  final double tileWidth;

  /// Whether the viewer has seen this title, which dims the artwork and
  /// stamps it.
  final bool watched;

  /// How many Oscars to show along the bottom of the artwork.
  final int awards;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            poster,
            if (watched) _dimmed(),
            if (awards > 0) _awards(),
            if (watched) _stamp(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: kPosterTileMarginLeft,
            right: kPosterTileMarginRight,
            top: kPosterLabelGap,
          ),
          child: SizedBox(
            width: tileWidth,
            child: ScrollingLine(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              height: kPosterLabelHeight,
            ),
          ),
        ),
      ],
    );
  }

  /// Places [child] over the artwork, aligned within it.
  ///
  /// Everything drawn on top of a poster goes through here, so the stack ends
  /// up exactly the size of the poster and a tile's width never depends on
  /// what happens to be stamped on it. An unpositioned overlay does take part
  /// in sizing the stack, which is how a wide stamp used to drag a whole tile
  /// past the column it belonged in.
  Widget _overPoster({required Alignment alignment, required Widget child}) {
    return Positioned(
      left: kPosterTileMarginLeft,
      top: kPosterTileMarginTop,
      width: tileWidth,
      height: posterHeightFor(tileWidth),
      child: Align(alignment: alignment, child: child),
    );
  }

  /// The wash over artwork the viewer has already seen. Darkest at the top,
  /// where the stamp sits, and clear by the bottom so the poster is still
  /// recognisable.
  Widget _dimmed() {
    return _overPoster(
      alignment: Alignment.center,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _awards() {
    return _overPoster(
      alignment: Alignment.bottomCenter,
      // A title with a shelf full of them would otherwise run off both sides
      // of the poster; scaling down keeps the whole row on the artwork.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            awards,
            (index) => SizedBox(
              height: tileWidth * 0.28,
              child: Image.asset('assets/oscar2.png'),
            ),
          ),
        ),
      ),
    );
  }

  /// The "seen" stamp, across the top of the artwork where the wash is
  /// darkest.
  ///
  /// Positioned over the poster's rectangle rather than laid out beside it.
  /// It used to be a column carrying a hardcoded 54pt left margin, which put
  /// it across the right half of the artwork and a few pixels past the right
  /// edge — survivable only because every poster was exactly 104pt wide. Now
  /// that a grid shares its width out among its columns, that margin could
  /// exceed the poster itself, and because the stamp was an unpositioned
  /// child it dragged the whole tile past the column it belonged in.
  ///
  /// A positioned child takes no part in sizing the stack, so a watched tile
  /// is now exactly as wide as an unwatched one whatever the poster measures.
  /// Its height along the top is unchanged; only the horizontal offset is
  /// gone, and centring is what that offset was failing to be.
  Widget _stamp() {
    return _overPoster(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: tileWidth * 0.55,
        height: tileWidth * 0.26,
        child: Image.asset(
          'assets/seen_after.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
