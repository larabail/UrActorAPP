/// Tests for the profile sections dialogue.
///
/// It reorders and toggles the blocks the profile page is built from, and it
/// used to do that inside a `Container(height: 450)` regardless of the screen
/// -- 416pt of waste on a tall phone and a clip on a short one. The list now
/// shrink-wraps and lets the shell scroll, which is a combination worth
/// pinning: a reorderable list that does not scroll itself is easy to get
/// subtly wrong.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/profile_sections_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  var closed = false;

  setUp(() {
    firestore = installFakeFirestore();
    closed = false;
    user = installTestUser(settings: {
      'language': 'en',
      'profileSections': {
        'Favorites': {'show': true, 'weight': 0},
        'MostSeenMovies': {'show': true, 'weight': 1},
        'MostSeenTVShows': {'show': false, 'weight': 2},
      },
    });
  });

  Future<void> openDialog(WidgetTester tester,
      {Size size = const Size(400, 900)}) async {
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProfileSectionsDialogue(
                    onDialogClosed: () => closed = true),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>?> settingsDoc() async {
    final doc = await firestore.collection('test-uid').doc('Settings').get();
    return doc.data();
  }

  testWidgets('lists every section in weight order', (tester) async {
    await openDialog(tester);

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Most Seen Movies'), findsOneWidget);
    expect(find.text('Most Seen TV Shows'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Favorites')).dy,
      lessThan(tester.getTopLeft(find.text('Most Seen Movies')).dy),
    );
  });

  testWidgets('takes only the height its sections need', (tester) async {
    // Three rows in a 900pt window used to render a 450pt panel with half of
    // it empty.
    await openDialog(tester);

    final panel = tester.getSize(find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first);

    expect(panel.height, lessThan(450.0));
  });

  testWidgets('a section switched off is saved as hidden', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(user.settings['profileSections']['Favorites']['show'], isFalse);
    final stored = (await settingsDoc())!['profileSections'] as Map;
    expect(stored['Favorites']['show'], isFalse);
  });

  testWidgets('dragging a section to the top rewrites the weights',
      (tester) async {
    // The weights are what the profile page orders by, so a reorder that does
    // not renumber them looks like it did nothing once the dialogue closes.
    //
    // The drag distance is measured from the rows themselves rather than
    // written as a constant: a fixed offset silently stops crossing the row it
    // was tuned to cross as soon as anything above the list changes height.
    // The rows have no drag listener of their own, so the reorder starts with
    // a long press.
    await openDialog(tester);

    final from = tester.getCenter(find.text('Most Seen TV Shows'));
    final to = tester.getCenter(find.text('Favorites'));

    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    // In steps rather than one jump. A reorderable list decides where the row
    // lands from the drop target under the pointer as it travels, so a single
    // moveTo skips every target between the two ends and settles one slot up
    // instead of at the top.
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, (to.dy - 20 - from.dy) / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final sections = user.settings['profileSections'] as Map;
    expect(sections['MostSeenTVShows']['weight'], 0);
    expect(sections['Favorites']['weight'], 1);
    expect(sections['MostSeenMovies']['weight'], 2);
  });

  testWidgets('saving tells the page that opened it to redraw', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.byType(ProfileSectionsDialogue), findsNothing);
  });
}
