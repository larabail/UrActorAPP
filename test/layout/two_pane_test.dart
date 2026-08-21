/// Tests for the two pane layout.
///
/// On a phone, opening a title covers the list with it, because there is only
/// room for one thing. Given a wide window, covering the list throws away the
/// context the user was working in. These cover the routing decision — which
/// pane a page lands in — since that is the part that has to keep working
/// unchanged on a phone while behaving differently on a desktop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/layout/two_pane.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void _useWindow(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// A list with one button that opens [page] through [openDetail].
Widget _listOpening(Widget page) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => openDetail(context, page),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  group('with a pane present', () {
    testWidgets('the list stays on screen and the page opens beside it',
        (tester) async {
      _useWindow(tester, const Size(1400, 900));

      await tester.pumpWidget(_app(TwoPane(
        list: _listOpening(const Text('the detail')),
        placeholder: const DetailPanePlaceholder(message: 'nothing yet'),
      )));

      expect(find.text('nothing yet'), findsOneWidget);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('the detail'), findsOneWidget);
      // The point of the whole layout: the list is still there.
      expect(find.text('open'), findsOneWidget);
      expect(find.text('nothing yet'), findsNothing);
    });

    testWidgets('choosing again replaces rather than stacks', (tester) async {
      _useWindow(tester, const Size(1400, 900));

      late void Function(Widget) open;
      await tester.pumpWidget(_app(TwoPane(
        list: Builder(
          builder: (context) {
            open = DetailPane.maybeOf(context)!.open;
            return const SizedBox();
          },
        ),
        placeholder: const DetailPanePlaceholder(message: 'nothing yet'),
      )));

      open(const Text('first'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);

      open(const Text('second'));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
      // Anything stacked up belonged to the previous selection and goes with
      // it, rather than being left underneath the new one.
      expect(find.text('first'), findsNothing);
    });

    testWidgets('a page opened from inside the pane stacks on top',
        (tester) async {
      _useWindow(tester, const Size(1400, 900));

      // Following a cast member from a film should keep the film behind it.
      final inner = _listOpening(const Text('the person'));

      late void Function(Widget) open;
      await tester.pumpWidget(_app(TwoPane(
        list: Builder(
          builder: (context) {
            open = DetailPane.maybeOf(context)!.open;
            return const SizedBox();
          },
        ),
        placeholder: const DetailPanePlaceholder(message: 'nothing yet'),
      )));

      open(inner);
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('the person'), findsOneWidget);
    });
  });

  group('with no pane', () {
    testWidgets('openDetail covers the window, as it always did',
        (tester) async {
      _useWindow(tester, const Size(400, 900));

      await tester.pumpWidget(_app(_listOpening(const Text('the detail'))));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('the detail'), findsOneWidget);
      // A phone has room for one thing at a time, so the list is covered.
      expect(find.text('open'), findsNothing);
    });
  });

  group('each pane is told its own width', () {
    testWidgets('so tiles size to the pane and not to the window',
        (tester) async {
      _useWindow(tester, const Size(1600, 900));

      late double listWidth;
      await tester.pumpWidget(_app(TwoPane(
        list: LayoutBuilder(
          builder: (context, constraints) {
            listWidth = constraints.maxWidth;
            return const SizedBox.expand();
          },
        ),
        placeholder: const DetailPanePlaceholder(message: 'nothing yet'),
      )));

      // A list given half a 1600pt window must not lay itself out as though
      // it had all 1600, or its rows run off the edge of the pane.
      expect(listWidth, lessThan(1600));
      expect(listWidth, greaterThan(0));
    });
  });
}
