/// Tests for the adaptive navigation chrome.
///
/// The app used to put its four destinations in a bottom bar at every window
/// size, and switching between them pushed a route each time, so the stack
/// grew for as long as the user kept tapping. Both are covered here: the first
/// because a bar across the bottom of a 27 inch monitor is the most visible
/// symptom of a phone layout on a desktop, and the second because an
/// unbounded stack is invisible until someone presses back eleven times.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/navigation/app_scaffold.dart';
import 'package:uractor/common/layout/two_pane.dart';
import 'package:uractor/common/navigation/destinations.dart';
import 'package:uractor/l10n/l10n.dart';

import '../support/harness.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: child,
    );

/// Sizes the window for the current test and puts it back afterwards.
void _useWindow(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUp(() {
    installTestUser();
  });

  group('navigation chrome follows the window', () {
    testWidgets('a phone keeps the bottom bar', (tester) async {
      _useWindow(tester, const Size(400, 900));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: 0, body: SizedBox()),
      ));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a phone turned sideways trades the bar for a rail',
        (tester) async {
      _useWindow(tester, const Size(900, 400));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: 0, body: SizedBox()),
      ));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('a tablet in landscape gets a rail', (tester) async {
      _useWindow(tester, const Size(1194, 834));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: 1, body: SizedBox()),
      ));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          isFalse);
    });

    testWidgets('a desktop window labels the rail', (tester) async {
      _useWindow(tester, const Size(1920, 1080));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: 2, body: SizedBox()),
      ));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('a desktop window dragged narrow goes back to the bar',
        (tester) async {
      _useWindow(tester, const Size(1920, 1080));
      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: 0, body: SizedBox()),
      ));
      expect(find.byType(NavigationRail), findsOneWidget);

      // The layout follows the window, not the device it started on.
      _useWindow(tester, const Size(420, 900));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('a screen reached from a destination', () {
    testWidgets('still offers the destinations but highlights none',
        (tester) async {
      _useWindow(tester, const Size(1194, 834));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: -1, body: SizedBox()),
      ));

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(4));
      expect(rail.selectedIndex, isNull);
    });

    testWidgets('shows an unselected bottom bar on a phone', (tester) async {
      _useWindow(tester, const Size(400, 900));

      await tester.pumpWidget(_wrap(
        const AppScaffold(selectedIndex: -1, body: SizedBox()),
      ));

      final bar = tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bar.selectedItemColor, Colors.grey);
      // A bar has to have a valid index even when nothing is selected.
      expect(bar.currentIndex, 0);
    });
  });

  group('the body is given the room the rail leaves it', () {
    testWidgets('and not the full width of the window', (tester) async {
      _useWindow(tester, const Size(1400, 900));

      late double bodyWidth;
      await tester.pumpWidget(_wrap(
        AppScaffold(
          selectedIndex: 0,
          body: LayoutBuilder(
            builder: (context, constraints) {
              bodyWidth = constraints.maxWidth;
              return const SizedBox.expand();
            },
          ),
        ),
      ));

      // Whatever the rail costs, the body must be told about it, or a row of
      // tiles sized to the window overflows by exactly the rail's width.
      expect(bodyWidth, lessThan(1400));
      expect(bodyWidth, greaterThan(1000));
    });

    testWidgets('so a window only just wide enough does not split in two',
        (tester) async {
      // 1024 clears the two pane breakpoint, but not once the rail has taken
      // its share. Deciding from the window rather than from what is left
      // would split a space too narrow to hold either half properly.
      _useWindow(tester, const Size(1030, 900));

      await tester.pumpWidget(_wrap(
        const AppScaffold(
          selectedIndex: 0,
          body: SizedBox(),
          detailPlaceholder: DetailPanePlaceholder(message: 'nothing yet'),
        ),
      ));

      expect(find.byType(TwoPane), findsNothing);
    });

    testWidgets('and a genuinely wide window still gets both panes',
        (tester) async {
      _useWindow(tester, const Size(1600, 900));

      await tester.pumpWidget(_wrap(
        const AppScaffold(
          selectedIndex: 0,
          body: SizedBox(),
          detailPlaceholder: DetailPanePlaceholder(message: 'nothing yet'),
        ),
      ));

      expect(find.byType(TwoPane), findsOneWidget);
      expect(find.text('nothing yet'), findsOneWidget);
    });
  });

  group('moving between destinations does not grow the route stack', () {
    testWidgets('returning home unwinds to the root instead of pushing it',
        (tester) async {
      // Switching destinations used to push unconditionally, so the stack kept
      // every section the user had ever opened and the back gesture walked
      // back through all of them. Home is the root, so going there pops.
      final observer = _RouteCounter();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => goToDestination(context, 0),
                          child: const Text('home'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('deeper'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('deeper'));
      await tester.pumpAndSettle();
      expect(observer.depth, 2);

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();

      expect(observer.depth, 1, reason: 'home should pop back to the root');
      expect(observer.pushes, 2, reason: 'home must not be pushed onto itself');
    });
  });
}

/// Counts what the navigator is asked to do, so a test can assert on the shape
/// of the stack rather than on what happens to be on screen.
class _RouteCounter extends NavigatorObserver {
  int depth = 0;
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth++;
    pushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => depth--;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth--;
}
