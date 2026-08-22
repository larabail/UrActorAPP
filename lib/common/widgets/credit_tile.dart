import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import 'scrolling_line.dart';

/// The room kept under a filmography poster for the credit line.
///
/// Fixed rather than measured so every tile in a row is the same height
/// whether or not it has anything to say. A row whose tiles disagree about
/// their height centres the short ones, and the posters stop lining up.
const double kCreditLabelHeight = 20;

/// The gap between the poster and the line under it.
const double kCreditLabelGap = 4;

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
            top: kCreditLabelGap,
          ),
          child: SizedBox(
            width: tileWidth,
            child: ScrollingLine(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              height: kCreditLabelHeight,
            ),
          ),
        ),
      ],
    );
  }

  /// The wash over artwork the viewer has already seen. Darkest at the top,
  /// where the stamp sits, and clear by the bottom so the poster is still
  /// recognisable.
  Widget _dimmed() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        kPosterTileMarginLeft,
        kPosterTileMarginTop,
        kPosterTileMarginRight,
        0,
      ),
      width: tileWidth,
      height: posterHeightFor(tileWidth),
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
    );
  }

  Widget _awards() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: tileWidth * 0.28,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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

  /// The "seen" stamp, high on the artwork where the wash above is darkest.
  Widget _stamp() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
            width: tileWidth * 0.55,
            height: tileWidth * 0.26,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/seen_after.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Holds the stamp up near the top of the poster rather than in the
          // middle of it.
          SizedBox(height: posterHeightFor(tileWidth) * 0.52),
        ],
      ),
    );
  }
}
