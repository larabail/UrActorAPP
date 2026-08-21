/// The widget side of the responsive layout: how a subtree finds out how much
/// room it actually has.
///
/// The rules themselves live in `breakpoints.dart`, which knows nothing about
/// widgets so it can be unit tested. This file is the thin part that reads a
/// width and hands it down.
library;

import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Publishes the size class of the space a subtree has been given.
///
/// Without this, everything would read the window width from `MediaQuery` and
/// get the wrong answer inside a two pane layout: the window is [large], but
/// the list pane occupying half of it has no more room than a tablet. Tiles
/// sized from the window would then overflow the pane they are drawn in.
///
/// [LayoutScope.of] falls back to the window when no scope is present, so a
/// screen that has not been adapted yet still behaves sensibly.
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.sizeClass,
    required this.width,
    required super.child,
  });

  /// The class of the space available to this subtree.
  final WindowSizeClass sizeClass;

  /// That space's width in logical pixels.
  final double width;

  /// The size class in force for [context].
  static WindowSizeClass of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutScope>()?.sizeClass ??
      windowSizeClassFor(MediaQuery.sizeOf(context).width);

  /// The width available to [context], in logical pixels.
  static double widthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutScope>()?.width ??
      MediaQuery.sizeOf(context).width;

  /// Wraps [child] in a scope describing a region [width] wide.
  static Widget forWidth({required double width, required Widget child}) =>
      LayoutScope(
        sizeClass: windowSizeClassFor(width),
        width: width,
        child: child,
      );

  @override
  bool updateShouldNotify(LayoutScope oldWidget) =>
      oldWidget.sizeClass != sizeClass || oldWidget.width != width;
}

/// Shorthands for the questions widgets actually ask.
extension ResponsiveContext on BuildContext {
  /// The size class of the space this widget has.
  WindowSizeClass get sizeClass => LayoutScope.of(this);

  /// Whether this space is a phone held upright.
  bool get isCompact => sizeClass == WindowSizeClass.compact;

  /// Whether this space is wide enough to carry a list and a detail view side
  /// by side.
  bool get hasTwoPanes => usesTwoPanes(sizeClass);

  /// The width a poster tile should aim for here.
  double get posterWidth => posterWidthFor(sizeClass);

  /// The gap to leave between tiles here.
  double get tileSpacing => tileSpacingFor(sizeClass);
}

/// Centres [child] and stops it growing past [maxWidth].
///
/// Prose and form fields set across a full desktop window are hard to read,
/// and a login form stretched to 2560 pixels looks broken rather than
/// spacious. Everything that is a column of text rather than a grid of
/// artwork should be wrapped in one of these.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = kMaxReadableWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Rebuilds [builder] with the size class of the box it is given, and
/// publishes that class to everything beneath it.
///
/// Use this where a region is narrower than the window — a pane, a dialogue,
/// a card — so the contents adapt to the region rather than to the screen.
class ResponsiveRegion extends StatelessWidget {
  const ResponsiveRegion({super.key, required this.builder});

  final Widget Function(BuildContext context, WindowSizeClass size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded width means the parent is measuring rather than laying
        // out — a horizontal scroll view, say. Falling back to the window is
        // better than treating infinity as a very large window.
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return LayoutScope.forWidth(
          width: width,
          child: Builder(
            builder: (context) => builder(context, windowSizeClassFor(width)),
          ),
        );
      },
    );
  }
}

/// The height a horizontally scrolling row of poster tiles needs here.
double posterRowHeight(BuildContext context, {double scale = 1.0}) =>
    posterRowHeightFor(context.posterWidth * scale);

/// A box exactly the size of a poster tile, for the moment before one has
/// loaded and for the case where it never will.
///
/// Every screen that shows tiles used to spell this out with the same pair of
/// window fractions the tile itself used, so a placeholder and the tile that
/// replaced it were the same wrong shape together. Sharing one widget means
/// they stay the same shape now that it is the right one, and that a future
/// change to tile sizing does not have to be repeated twenty times.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key, this.child, this.scale = 1.0});

  /// Shown centred in the reserved space — a spinner, or a message saying the
  /// details could not be loaded.
  final Widget? child;

  /// Matches the [scale] given to the tile this stands in for.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double width = context.posterWidth * scale;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        kPosterTileMarginLeft,
        kPosterTileMarginTop,
        kPosterTileMarginRight,
        0,
      ),
      width: width,
      height: posterHeightFor(width),
      child: child == null ? null : Center(child: child),
    );
  }
}
