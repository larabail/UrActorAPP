// The scaffold every screen is built on, and the one place that decides where
// navigation goes.
//
// A phone puts its destinations along the bottom, within reach of a thumb. A
// window wider than that has the room for a rail down the leading edge, and
// wants it: a bottom bar spends vertical space, which is scarcest exactly when
// a window is short and wide, and it pins navigation to the far corner of a
// large display rather than beside the content.
import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../layout/responsive.dart';
import '../layout/two_pane.dart';
import 'destinations.dart';

/// A [Scaffold] whose navigation adapts to the width of the window.
///
/// [selectedIndex] is the destination this screen belongs to, or -1 for a
/// screen reached from within one — a media page, a season guide — which
/// highlights nothing but still offers the destinations, exactly as the bottom
/// bar always has.
///
/// [detailPlaceholder] opts a list screen into the two pane layout: given a
/// window wide enough, whatever the list opens appears beside it rather than
/// on top of it, and this is what the pane shows until something is chosen.
/// A screen that is not a list of things to open leaves it null.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.detailPlaceholder,
  });

  final int selectedIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final Widget? detailPlaceholder;

  @override
  Widget build(BuildContext context) {
    // A screen rendered inside a detail pane is a passenger in someone else's
    // layout: it must not draw a second set of destinations, and it certainly
    // must not open a pane of its own.
    final DetailPane? pane = DetailPane.maybeOf(context);
    if (pane != null && pane.isInsidePane) {
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }

    final WindowSizeClass size =
        windowSizeClassFor(MediaQuery.sizeOf(context).width);
    final NavigationStyle style = navigationStyleFor(size);
    final Widget? placeholder = detailPlaceholder;

    if (style == NavigationStyle.bottomBar) {
      // A bottom bar only happens at compact, which never has room for two
      // panes, so the body is the whole story here.
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: _BottomDestinations(selectedIndex: selectedIndex),
      );
    }

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          _DestinationRail(
            selectedIndex: selectedIndex,
            extended: style == NavigationStyle.extendedRail,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // The body is told how much room it actually has, so that tiles and
          // grids inside it size to the remaining space rather than to the
          // whole window. Without this the rail's width is unaccounted for and
          // a full width row of tiles overflows by exactly that much.
          Expanded(
            child: ResponsiveRegion(
              builder: (context, available) {
                // Whether there is room for two panes is decided from what is
                // left after the rail, not from the window. A 1024 window is
                // wide enough by the breakpoints, but not once the rail has
                // taken its share -- deciding from the window would split a
                // space too narrow to hold either half properly.
                if (placeholder != null && usesTwoPanes(available)) {
                  return TwoPane(list: body, placeholder: placeholder);
                }
                return body;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomDestinations extends StatelessWidget {
  const _BottomDestinations({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      selectedItemColor: selectedIndex >= 0
          ? const Color.fromARGB(250, 224, 190, 78)
          : Colors.grey,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex >= 0 ? selectedIndex : 0,
      onTap: (index) =>
          goToDestination(context, index, currentIndex: selectedIndex),
      items: [
        for (int i = 0; i < kAppDestinations.length; i++)
          BottomNavigationBarItem(
            icon: destinationIcon(i),
            label: kAppDestinations[i].label(context),
          ),
      ],
    );
  }
}

class _DestinationRail extends StatelessWidget {
  const _DestinationRail({required this.selectedIndex, required this.extended});

  final int selectedIndex;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    const Color selected = Color.fromARGB(250, 224, 190, 78);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // A rail taller than the space it is given -- a phone turned
          // sideways is only a few hundred pixels tall -- scrolls rather than
          // overflowing.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                extended: extended,
                backgroundColor: const Color(0xFF121212),
                selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
                indicatorColor: selected.withValues(alpha: 0.15),
                selectedIconTheme: const IconThemeData(color: selected),
                unselectedIconTheme: const IconThemeData(color: Colors.grey),
                selectedLabelTextStyle: const TextStyle(
                  color: selected,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
                // An extended rail writes its labels beside the icons, so
                // asking for them underneath as well is a contradiction the
                // framework asserts on.
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                onDestinationSelected: (index) => goToDestination(
                  context,
                  index,
                  currentIndex: selectedIndex,
                ),
                destinations: [
                  for (int i = 0; i < kAppDestinations.length; i++)
                    NavigationRailDestination(
                      icon: destinationIcon(i, size: 24),
                      label: Text(kAppDestinations[i].label(context)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
