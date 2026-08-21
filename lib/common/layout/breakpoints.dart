/// Where the app decides what shape the window is, and what follows from that.
///
/// This file is deliberately free of widgets, `BuildContext` and anything that
/// touches the network, so every rule below can be checked with a plain unit
/// test. The widgets that consume it are thin by comparison, which is the
/// point: the arithmetic that decides how many posters fit on a row is the
/// part that is easy to get wrong and hard to eyeball on a screenshot.
library;

import 'dart:math' as math;

/// The window size classes, following Material 3's definitions so the numbers
/// line up with what the framework's own adaptive widgets expect.
///
/// The names describe the *window*, not the device. A phone held sideways and
/// a tablet held upright can land in the same class, and that is correct —
/// what the layout can do depends on the space it has, not on what is holding
/// it. A desktop window dragged narrow becomes [compact] and gets the phone
/// layout, which is the honest answer rather than a broken wide one.
enum WindowSizeClass {
  /// Phone in portrait. One pane, navigation along the bottom where a thumb
  /// can reach it.
  compact,

  /// Phone in landscape, or a small tablet in portrait. Still one pane —
  /// there is width to spare but not enough for two useful columns — so the
  /// gain here is a navigation rail reclaiming the vertical space that a
  /// bottom bar costs, which is scarcest exactly when the window is short.
  medium,

  /// Tablet in landscape, or a modest desktop window. Wide enough for a list
  /// and a detail view side by side.
  expanded,

  /// A desktop window given real estate. Same two panes as [expanded], but
  /// the rail can afford to label its destinations instead of relying on
  /// icons alone.
  large,
}

/// The width, in logical pixels, at which each class begins.
///
/// These are Material 3's breakpoints rather than numbers picked to match
/// particular devices. Chasing device sizes is a losing game — they change
/// every year, and a window on a desktop is any size the user drags it to.
abstract final class Breakpoints {
  /// Below this the window is [WindowSizeClass.compact].
  static const double medium = 600;

  /// At or above this a second pane becomes worthwhile.
  static const double expanded = 1024;

  /// At or above this the navigation rail can show labels.
  static const double large = 1440;
}

/// The class [width] logical pixels falls into.
WindowSizeClass windowSizeClassFor(double width) {
  if (width >= Breakpoints.large) return WindowSizeClass.large;
  if (width >= Breakpoints.expanded) return WindowSizeClass.expanded;
  if (width >= Breakpoints.medium) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// How navigation between the four top level destinations is presented.
enum NavigationStyle {
  /// A bar across the bottom of the window.
  bottomBar,

  /// A vertical rail of icons down the leading edge.
  rail,

  /// The same rail, with each destination labelled.
  extendedRail,
}

/// The navigation presentation for [size].
NavigationStyle navigationStyleFor(WindowSizeClass size) {
  switch (size) {
    case WindowSizeClass.compact:
      return NavigationStyle.bottomBar;
    case WindowSizeClass.medium:
    case WindowSizeClass.expanded:
      return NavigationStyle.rail;
    case WindowSizeClass.large:
      return NavigationStyle.extendedRail;
  }
}

/// Whether [size] has room to show a list and a detail view at once.
bool usesTwoPanes(WindowSizeClass size) =>
    size == WindowSizeClass.expanded || size == WindowSizeClass.large;

/// The aspect ratio of a poster, as width divided by height.
///
/// TMDB serves posters at 500x750, so this is the shape the artwork actually
/// is. Sizing a tile to anything else either letterboxes it or crops it, and
/// the app used to do the latter severely: tiles were sized as a fraction of
/// the window, which made a tile's proportions follow the *window's*
/// proportions. That happens to be about right on a phone held upright and is
/// wrong everywhere else — on a 1920x1080 window the same arithmetic produced
/// a tile over four times wider than a poster is.
const double kPosterAspectRatio = 2 / 3;

/// The height a poster [width] logical pixels wide should be.
double posterHeightFor(double width) => width / kPosterAspectRatio;

/// The aspect ratio of an episode still or a backdrop, as width over height.
///
/// TMDB serves these at 16:9, which is nothing like a poster. Sizing a still
/// with the poster rules crops the sides off it.
const double kStillAspectRatio = 16 / 9;

/// The height a still [width] logical pixels wide should be.
double stillHeightFor(double width) => width / kStillAspectRatio;

/// The width a poster tile aims for in a horizontally scrolling row.
///
/// Tiles grow with the window, but far more slowly than the window does. A
/// bigger screen should mostly mean *more* posters visible rather than bigger
/// ones — past a point a larger poster carries no more information, it just
/// pushes its neighbours off the edge.
double posterWidthFor(WindowSizeClass size) {
  switch (size) {
    case WindowSizeClass.compact:
      return 104;
    case WindowSizeClass.medium:
      return 120;
    case WindowSizeClass.expanded:
      return 132;
    case WindowSizeClass.large:
      return 144;
  }
}

/// The gap between tiles in a grid or row, for [size].
double tileSpacingFor(WindowSizeClass size) =>
    size == WindowSizeClass.compact ? 8 : 12;

/// How many columns of [targetTileWidth]-wide tiles fit into [availableWidth].
///
/// The count is what adapts; the tiles then share the width out evenly, so a
/// grid always reaches both edges instead of leaving a ragged margin. The
/// result is clamped so a very narrow window still shows more than one tile
/// and a very wide one does not shrink them to thumbnails.
///
/// [spacing] is counted between columns only, not outside them, which is why
/// the arithmetic adds one spacing before dividing.
int gridColumnsFor(
  double availableWidth, {
  required double targetTileWidth,
  double spacing = 12,
  int minColumns = 2,
  int maxColumns = 12,
}) {
  if (availableWidth <= 0 || targetTileWidth <= 0) return minColumns;
  final int fitted =
      ((availableWidth + spacing) / (targetTileWidth + spacing)).floor();
  return fitted.clamp(minColumns, maxColumns);
}

/// The margin a poster tile carries, kept here rather than inside the tile so
/// that a row or a placeholder can reserve exactly the space a tile will take
/// without having to guess at it.
const double kPosterTileMarginLeft = 5;
const double kPosterTileMarginTop = 10;
const double kPosterTileMarginRight = 10;

/// The height a horizontally scrolling row of [tileWidth]-wide posters needs.
///
/// Rows used to be given a fraction of the window height, which is the same
/// mistake the tiles themselves made: on a short window the row clipped its
/// tiles, and on a tall one it left a band of dead space under them.
double posterRowHeightFor(double tileWidth) =>
    posterHeightFor(tileWidth) + kPosterTileMarginTop;

/// The widest a column of prose or form fields should be allowed to get.
///
/// Text set across a full desktop window is genuinely hard to read — the eye
/// loses the line it was on during the return sweep. Roughly 90 characters is
/// the usual upper bound, which at this app's body size lands near here.
const double kMaxReadableWidth = 840;

/// The widest a column of form fields should get.
///
/// Narrower than prose, because a text field's width implies how much is
/// expected in it. An email box stretched across a desktop monitor reads as a
/// mistake, and the sign in form did exactly that: its column stretches its
/// children, so with nothing to stop it every field was as wide as the screen.
const double kMaxFormWidth = 420;

/// The widest a detail pane should get before the list pane keeps the rest.
const double kMaxDetailPaneWidth = 840;

/// The narrowest a detail pane can be squeezed to and still be worth showing.
const double kMinDetailPaneWidth = 420;

/// How wide the detail half of a two pane layout should be, given the
/// [totalWidth] the two panes share.
///
/// An even split is right in the middle of the range and wrong at both ends:
/// at 1024 it leaves the detail pane too narrow to lay out a media page, and
/// on an ultrawide monitor it would stretch a column of text across half a
/// metre. Clamping at both ends means the list pane absorbs the surplus on a
/// very wide window, which is where extra posters are useful anyway.
double detailPaneWidthFor(double totalWidth) {
  final double half = totalWidth / 2;
  final double clamped =
      half.clamp(kMinDetailPaneWidth, kMaxDetailPaneWidth).toDouble();
  // Never take so much that the list pane is left unusable. Below this the
  // caller should not have been showing two panes at all.
  return math.min(clamped, totalWidth - kMinDetailPaneWidth);
}
