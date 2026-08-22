import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';
import 'package:uractor/common/layout/breakpoints.dart';
import 'package:uractor/common/widgets/credit_tile.dart';
import 'package:uractor/common/widgets/scrolling_line.dart';

import '../support/harness.dart';

const double _tileWidth = 104;

/// Stands in for the artwork, which would otherwise want the network. Sized
/// and margined exactly as `getItemContainer` sizes a real one, so the
/// geometry under test is the geometry the page produces. The key is on the
/// painted box rather than the outer container, so a rect taken from it is
/// the artwork itself and not the margin around it.
const Key _posterKey = ValueKey('poster');

Widget _poster() => Container(
      margin: const EdgeInsets.fromLTRB(
        kPosterTileMarginLeft,
        kPosterTileMarginTop,
        kPosterTileMarginRight,
        0,
      ),
      width: _tileWidth,
      height: posterHeightFor(_tileWidth),
      child: const ColoredBox(key: _posterKey, color: Colors.blue),
    );

/// Never uses `pumpAndSettle`: a credit line that does not fit scrolls
/// forever, so settling never happens once one is on screen.
Future<void> _pumpTile(WidgetTester tester, String label) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: CreditTile(
            poster: _poster(),
            label: label,
            tileWidth: _tileWidth,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('the credit line sits under the poster, not over it',
      (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'Forrest Gump');

    final poster = tester.getRect(find.byKey(_posterKey));
    final line = tester.getRect(find.byType(ScrollingLine));

    // Posters carry their own title across the bottom, so a label drawn over
    // one collides with it and neither can be read.
    expect(line.top, greaterThanOrEqualTo(poster.bottom));
  });

  testWidgets('the credit line is as wide as the poster and no wider',
      (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'Forrest Gump');

    final poster = tester.getRect(find.byKey(_posterKey));
    final line = tester.getRect(find.byType(ScrollingLine));

    expect(line.left, poster.left);
    expect(line.width, poster.width);
  });

  testWidgets('a part too long for the tile scrolls itself', (tester) async {
    usePhoneSurface(tester);

    // The complaint that started this: "Narrator (voice)" is wider than a
    // poster and was simply cut off.
    await _pumpTile(tester, 'Narrator (voice) — uncredited');

    expect(find.byType(Marquee), findsOneWidget);
  });

  testWidgets('a part that fits is drawn still', (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'Zak');

    expect(find.byType(Marquee), findsNothing);
    expect(find.text('Zak'), findsOneWidget);
  });

  testWidgets('a tile with no part named is the same height as one with',
      (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'Forrest Gump');
    final named = tester.getSize(find.byType(CreditTile));

    await _pumpTile(tester, '');
    final unnamed = tester.getSize(find.byType(CreditTile));

    // A row whose tiles disagree about their height stops lining its posters
    // up with the row above.
    expect(unnamed.height, named.height);
  });

  testWidgets('the tile is no wider than the cell the poster asks for',
      (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'A part far too long to fit across one poster');

    expect(
      tester.getSize(find.byType(CreditTile)).width,
      _tileWidth + kPosterTileMarginLeft + kPosterTileMarginRight,
    );
  });

  testWidgets('a scrolling credit line keeps animating without throwing',
      (tester) async {
    usePhoneSurface(tester);

    await _pumpTile(tester, 'Narrator (voice) — uncredited');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(Marquee), findsOneWidget);
  });
}
