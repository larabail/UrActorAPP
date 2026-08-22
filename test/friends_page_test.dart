import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/friends_service.dart';
import 'package:uractor/common/reorder_toggle.dart';
import 'package:uractor/friends.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart';
import 'package:uractor/watching_together_section.dart';

import 'support/harness.dart';

/// Covers how the Watching together row sits on the friends page. What the row
/// itself draws is pinned in `watching_together_section_test.dart`; this is
/// about it coexisting with the friend list, which is the part that can only
/// go wrong once the two are in the same tree.
void main() {
  late FakeFirebaseFirestore firestore;
  late HttpStub http;

  const uid = 'test-uid';

  setUp(() {
    installTestUser(uid: uid);
    firestore = installFakeFirestore();
    http = installHttpStub();
    FriendsService.clearCache();
    addTearDown(FriendsService.clearCache);
  });

  Future<void> seedSharedShow() async {
    currentUser.friends = ['ana', 'luis'];
    currentUser.seenWith = <String, dynamic>{
      'ana': <String, dynamic>{
        'Movies': <String>[],
        'TVShows': ['1399'],
      },
    };
    await seedUserDoc(firestore, uid, 'Progress', {
      'Movies': <String, dynamic>{},
      'TVShows': {
        '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      },
    });
    await seedUserDoc(firestore, 'ana', 'Settings', {
      'username': 'Ana',
      'profile_photo': '',
    });
    await seedUserDoc(firestore, 'luis', 'Settings', {
      'username': 'Luis',
      'profile_photo': '',
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
  }

  Future<void> pumpFriends(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Friends(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('the row rides above the friends without displacing them',
      (tester) async {
    usePhoneSurface(tester);
    await seedSharedShow();

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Watching together'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(WatchingTogetherSection)).dy,
      lessThan(tester.getTopLeft(find.text('Ana')).dy),
    );
  });

  testWidgets('a short window still lays the page out', (tester) async {
    // The row used to sit fixed above the friend list, where a row of posters
    // plus its captions was enough to squeeze the list off a landscape phone
    // and overflow. It scrolls with the list instead.
    usePhoneSurface(tester, size: const Size(700, 360));
    await seedSharedShow();

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Watching together'), findsOneWidget);
  });

  testWidgets('nothing shared leaves the friends page as it was',
      (tester) async {
    usePhoneSurface(tester);
    currentUser.friends = ['ana'];
    await seedUserDoc(firestore, uid, 'Progress', {
      'Movies': <String, dynamic>{},
      'TVShows': <String, dynamic>{},
    });
    await seedUserDoc(firestore, 'ana', 'Settings', {
      'username': 'Ana',
      'profile_photo': '',
    });

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Watching together'), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('reordering friends is not obstructed by the row',
      (tester) async {
    usePhoneSurface(tester);
    await seedSharedShow();

    await pumpFriends(tester);
    await tester.tap(find.byType(ReorderToggle));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    // Dragging is about the friends alone, so the row steps aside rather than
    // becoming an item the drag has to be kept away from.
    expect(find.text('Watching together'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
}
