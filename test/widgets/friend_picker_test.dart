/// Tests for the shared friend picker.
///
/// Five popups each had their own copy of this list and four of them wrapped
/// it in `SizedBox(height: 125)`. A `CheckboxListTile` is 56pt tall, so the
/// user was shown 2.23 friends at a time in a dialogue with 604pt going spare,
/// and scrolled a list that would have fitted six times over in the room
/// already on screen. What is worth pinning is that it no longer does that.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/widgets/friend_picker.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = installFakeFirestore();
    installTestUser();
  });

  /// Registers [uid] with a display name and no avatar, so the row draws from
  /// the bundled placeholder rather than reaching for a profile photo.
  Future<void> addFriend(String uid, String username) => seedUserDoc(
        firestore,
        uid,
        'Settings',
        {'username': username, 'profile_photo': ''},
      );

  final selected = <String, bool>{};

  /// Pumps the picker inside a column tall enough to hold whatever it asks
  /// for, which is what a dialogue now gives it.
  Future<void> pump(
    WidgetTester tester,
    List<String> friendIds, {
    Size size = const Size(400, 900),
  }) async {
    selected.clear();
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: FriendPicker(
                friendIds: friendIds,
                selected: selected,
                onChanged: (friendId, value) =>
                    setState(() => selected[friendId] = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a row for every friend', (tester) async {
    for (var i = 0; i < 6; i++) {
      await addFriend('friend-$i', 'Friend $i');
    }

    await pump(tester, [for (var i = 0; i < 6; i++) 'friend-$i']);

    expect(find.byType(CheckboxListTile), findsNWidgets(6));
    expect(find.text('Friend 5'), findsOneWidget);
  });

  testWidgets('grows with the list instead of stopping at a fixed height',
      (tester) async {
    // The 125pt window is the whole complaint: with six friends it showed two
    // and hid the rest behind a scroll nobody asked for.
    for (var i = 0; i < 6; i++) {
      await addFriend('friend-$i', 'Friend $i');
    }

    await pump(tester, ['friend-0', 'friend-1']);
    final twoFriends = tester.getSize(find.byType(FriendPicker)).height;

    await pump(tester, [for (var i = 0; i < 6; i++) 'friend-$i']);
    final sixFriends = tester.getSize(find.byType(FriendPicker)).height;

    expect(sixFriends, greaterThan(twoFriends));
    expect(sixFriends, greaterThan(125.0),
        reason: 'six rows do not fit in the window this used to be given');
  });

  testWidgets('leaves the scrolling to whatever is above it', (tester) async {
    // A picker that scrolls inside a dialogue that also scrolls means a drag
    // on the friend list does not move the dialogue, which is the other half
    // of "requires a lot of scrolling".
    await addFriend('friend-0', 'Ana');

    await pump(tester, ['friend-0']);

    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
  });

  testWidgets('reports the friend that was ticked', (tester) async {
    await addFriend('friend-0', 'Ana');
    await addFriend('friend-1', 'Bruno');

    await pump(tester, ['friend-0', 'friend-1']);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();

    expect(selected, {'friend-0': true});
  });

  testWidgets('reports a friend unticked again', (tester) async {
    await addFriend('friend-0', 'Ana');

    await pump(tester, ['friend-0']);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();

    expect(selected, {'friend-0': false});
  });

  testWidgets('shows a tick against a friend that is already selected',
      (tester) async {
    await addFriend('friend-0', 'Ana');

    await pump(tester, ['friend-0']);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Ana'))
          .value,
      isTrue,
    );
  });

  testWidgets('reads each profile once however often the list is rebuilt',
      (tester) async {
    // The copies this replaces built the future inside build, so ticking one
    // box refetched every row and flashed a spinner over the whole list.
    // Deleting the document after the first read is the only way to observe
    // that a second read is not happening.
    await addFriend('friend-0', 'Ana');

    await pump(tester, ['friend-0']);
    await firestore.collection('friend-0').doc('Settings').delete();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('No data found'), findsNothing);
  });

  testWidgets('says so rather than throwing when a friend has no profile',
      (tester) async {
    await pump(tester, ['ghost']);

    expect(find.text('No data found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders nothing at all when there are no friends',
      (tester) async {
    await pump(tester, const []);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(tester.getSize(find.byType(FriendPicker)).height, 0.0);
  });
}
