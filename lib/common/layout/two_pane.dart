/// The two pane layout: a list on the left, whatever it points at on the
/// right.
///
/// On a phone, opening a title covers the list with it, because there is only
/// room for one thing at a time. Given a window wide enough, covering the list
/// throws away the context the user was working in — the whole reason a wide
/// window is worth having is that both can be on screen at once.
///
/// Every screen already opens detail pages with `Navigator.push`, and this is
/// built so they can keep doing so. [openDetail] decides where the page
/// actually goes: into the detail pane when there is one, and onto the root
/// navigator when there is not. The call sites do not have to know which
/// layout they are in.
library;

import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'responsive.dart';

/// Lets a subtree open a page in the detail pane, and tells it whether it is
/// already inside one.
class DetailPane extends InheritedWidget {
  const DetailPane({
    super.key,
    required this.open,
    required this.isInsidePane,
    required this.size,
    required super.child,
  });

  /// Shows [page] in the detail pane, replacing whatever is there.
  final void Function(Widget page) open;

  /// Whether the subtree being built is the pane's contents rather than the
  /// list beside it. A page opened from inside the pane stacks on top of what
  /// is already there — following a cast member from a film should keep the
  /// film behind it — whereas one opened from the list replaces it.
  final bool isInsidePane;

  /// The room this half of the layout actually has.
  ///
  /// Anything inside a pane that needs to know how big its world is should ask
  /// here rather than the window, because the pane is its world: it has its
  /// own [Navigator], and therefore its own overlay, so a layer that thinks it
  /// covers the screen is in fact drawn into this box and cropped by it.
  final Size size;

  static DetailPane? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPane>();

  @override
  bool updateShouldNotify(DetailPane oldWidget) =>
      oldWidget.open != open ||
      oldWidget.isInsidePane != isInsidePane ||
      oldWidget.size != size;
}

/// Opens [page], in the detail pane if there is one and as a full screen route
/// if there is not.
///
/// This is the one call every screen should use to open a media page, a person
/// or a playlist. A plain `Navigator.push` still works and still covers the
/// whole window, which is right for a dialogue or a form and wrong for
/// anything the list is pointing at.
Future<void> openDetail(BuildContext context, Widget page) {
  final DetailPane? pane = DetailPane.maybeOf(context);

  if (pane != null && !pane.isInsidePane) {
    pane.open(page);
    return Future<void>.value();
  }

  // Either there is no pane, or this is a page opened from within the pane and
  // should stack on top of what is already showing there. `Navigator.of` finds
  // the pane's own navigator in the second case, so the same call does both.
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => page),
  );
}

/// Lays [list] and a detail pane side by side.
///
/// The pane starts on [placeholder] and returns to it when the list replaces
/// what it was showing, so an empty pane says why it is empty rather than
/// being a blank half of the window.
class TwoPane extends StatefulWidget {
  const TwoPane({
    super.key,
    required this.list,
    required this.placeholder,
  });

  final Widget list;
  final Widget placeholder;

  @override
  State<TwoPane> createState() => _TwoPaneState();
}

/// The rule between the two panes.
const double _dividerWidth = 1;

class _TwoPaneState extends State<TwoPane> {
  final GlobalKey<NavigatorState> _detailNavigator =
      GlobalKey<NavigatorState>();

  void _open(Widget page) {
    final NavigatorState? navigator = _detailNavigator.currentState;
    if (navigator == null) return;

    // Anything the pane had stacked up belongs to the previous selection, so
    // it goes with it rather than being left underneath the new one.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => page),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The divider sits between the panes and takes its pixel out of the
        // detail half, so it comes off the top rather than being split over.
        // Left in, every width here is a pixel wider than the pane it
        // describes, which is invisible in a grid of posters and not at all
        // invisible to something sizing a video to fill the pane.
        final double total = constraints.maxWidth - _dividerWidth;
        final double detailWidth = detailPaneWidthFor(total);
        final double listWidth = total - detailWidth;
        final double height = constraints.maxHeight;

        return Row(
          children: [
            // Each pane is told its own width, so the tiles inside the list
            // size to the pane rather than to the window. Without this a list
            // in the left half of a 1920 window would lay itself out as though
            // it had all 1920.
            SizedBox(
              width: listWidth,
              child: LayoutScope.forWidth(
                width: listWidth,
                child: DetailPane(
                  open: _open,
                  isInsidePane: false,
                  size: Size(listWidth, height),
                  child: widget.list,
                ),
              ),
            ),
            const VerticalDivider(width: _dividerWidth, thickness: 1),
            Expanded(
              child: LayoutScope.forWidth(
                width: detailWidth,
                child: DetailPane(
                  open: _open,
                  isInsidePane: true,
                  size: Size(detailWidth, height),
                  child: Navigator(
                    key: _detailNavigator,
                    onGenerateRoute: (settings) => MaterialPageRoute<void>(
                      builder: (context) => widget.placeholder,
                      settings: settings,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// What the detail pane shows before anything has been chosen.
class DetailPanePlaceholder extends StatelessWidget {
  const DetailPanePlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_outlined, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
