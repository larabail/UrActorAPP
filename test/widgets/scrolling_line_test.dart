import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';
import 'package:uractor/common/widgets/scrolling_line.dart';

import '../support/harness.dart';

/// Never uses `pumpAndSettle`: a scrolling line animates forever, so settling
/// never happens once one is on screen.
void main() {
  Future<void> pumpLine(
    WidgetTester tester,
    String text, {
    double width = 200,
    double height = 18,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ScrollingLine(
                text: text,
                style: const TextStyle(fontSize: 12),
                height: height,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('text that fits is drawn still', (tester) async {
    usePhoneSurface(tester);

    await pumpLine(tester, 'Short');

    // A marquee that scrolls when it does not need to is a distraction, and a
    // static line can be read at a glance rather than waited for.
    expect(find.byType(Marquee), findsNothing);
    expect(find.text('Short'), findsOneWidget);
  });

  testWidgets('text too long for the space scrolls itself', (tester) async {
    usePhoneSurface(tester);

    await pumpLine(
      tester,
      'A line far longer than two hundred logical pixels could ever hold',
    );

    // Clipping would tell the reader there is more and then refuse to show it.
    expect(find.byType(Marquee), findsOneWidget);
  });

  testWidgets('both cases occupy the same height', (tester) async {
    usePhoneSurface(tester);

    await pumpLine(tester, 'Short');
    final short = tester.getSize(find.byType(ScrollingLine));

    await pumpLine(
      tester,
      'A line far longer than two hundred logical pixels could ever hold',
    );
    final long = tester.getSize(find.byType(ScrollingLine));

    // The row must not change height when a title resolves, or the list shoves
    // itself around under the reader's finger.
    expect(short.height, 18);
    expect(long.height, 18);
  });

  testWidgets('a scrolling line keeps animating without throwing',
      (tester) async {
    usePhoneSurface(tester);

    await pumpLine(
      tester,
      'A line far longer than two hundred logical pixels could ever hold',
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(Marquee), findsOneWidget);
  });

  testWidgets('an empty line is harmless', (tester) async {
    usePhoneSurface(tester);

    await pumpLine(tester, '');

    expect(tester.takeException(), isNull);
    expect(find.byType(Marquee), findsNothing);
  });
}
