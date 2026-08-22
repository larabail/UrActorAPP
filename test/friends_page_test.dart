import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';
import 'package:uractor/common/api/tmdb_titles.dart';
import 'package:uractor/common/firebase/friends_service.dart';
import 'package:uractor/common/reorder_toggle.dart';
import 'package:uractor/common/widgets/scrolling_line.dart';
import 'package:uractor/friends.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart';

import 'support/harness.dart';

/// Covers the "Watching together" line under each friend on the friends list.
///
/// Never uses `pumpAndSettle`: a line long enough to scroll animates forever,
/// so settling never happens on this page.
void main() {
  late FakeFirebaseFirestore firestore;
  late HttpStub http;

  const uid = 'test-uid';

  setUp(() {
    installTestUser(uid: uid);
    firestore = installFakeFirestore();
    http = installHttpStub();
    // Both caches live for the session, so a name or profile seeded by one
    // test would otherwise show up in the next one.
    FriendsService.clearCache();
    TmdbTitles.clearCache();
    addTearDown(FriendsService.clearCache);
    addTearDown(TmdbTitles.clearCache);
  });

  Future<void> seedFriend(String friendUid, String userName) {
    return seedUserDoc(firestore, friendUid, 'Settings', {
      'username': userName,
      'profile_photo': '',
    });
  }

  Future<void> seedProgress(Map<String, dynamic> shows) {
    return seedUserDoc(firestore, uid, 'Progress', {
      'Movies': <String, dynamic>{},
      'TVShows': shows,
    });
  }

  void seedSeenWith(Map<String, List<String>> showsByFriend) {
    currentUser.friends = showsByFriend.keys.toList();
    currentUser.seenWith = <String, dynamic>{
      for (final entry in showsByFriend.entries)
        entry.key: <String, dynamic>{
          'Movies': <String>[],
          'TVShows': entry.value,
        },
    };
  }

  Future<void> pumpFriends(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Friends(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a friend gets a line naming what is running with them',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Watching together: Severance'), findsOneWidget);
    // No posters on this screen: the line is the whole of it.
    expect(find.byType(ScrollingLine), findsOneWidget);
  });

  testWidgets('several shared shows are joined onto the one line',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399', '66732'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      '66732': {'started': '2026-01-01', 'updated': '2026-03-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
    http.on('/3/tv/66732', json: {'id': 66732, 'name': 'Stranger Things'});

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    // Newest activity first, the order progress already sorts them into.
    expect(
      find.text('Watching together: Stranger Things • Severance'),
      findsOneWidget,
    );
  });

  testWidgets('each friend gets their own line', (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
      'luis': ['66732'],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
      '66732': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
    http.on('/3/tv/66732', json: {'id': 66732, 'name': 'Stranger Things'});

    await pumpFriends(tester);

    expect(find.text('Watching together: Severance'), findsOneWidget);
    expect(find.text('Watching together: Stranger Things'), findsOneWidget);
  });

  testWidgets('a show shared with two friends is named under both',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
      'luis': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester);

    expect(find.text('Watching together: Severance'), findsNWidgets(2));
    // Named twice, fetched once.
    expect(http.countFor('/3/tv/1399'), 1);
  });

  testWidgets('a friend with nothing running keeps a bare name',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
      'luis': <String>[],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester);

    expect(find.text('Luis'), findsOneWidget);
    expect(find.byType(ScrollingLine), findsOneWidget);
  });

  testWidgets('a show already finished together leaves no line',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {
        'started': '2026-01-01',
        'finished': '2026-01-05',
        'updated': '2026-01-05',
      },
    });

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byType(ScrollingLine), findsNothing);
    // Nothing to name, so nothing is asked of TMDB.
    expect(http.requests, isEmpty);
  });

  testWidgets('an id TMDB will not resolve is left off rather than named',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['404'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '404': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/404', status: 404, body: '');

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
    // "Unknown" scrolling past between real titles says nothing worth saying.
    expect(find.byType(ScrollingLine), findsNothing);
  });

  testWidgets('a long line scrolls itself instead of being clipped',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1', '2', '3'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      for (final id in ['1', '2', '3'])
        id: {'started': '2026-01-01', 'updated': '2026-01-0$id'},
    });
    http.on('/3/tv/1', json: {'id': 1, 'name': 'A Show With A Long Name One'});
    http.on('/3/tv/2', json: {'id': 2, 'name': 'A Show With A Long Name Two'});
    http.on('/3/tv/3', json: {
      'id': 3,
      'name': 'A Show With A Long Name Three',
    });

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Marquee), findsOneWidget);
  });

  testWidgets('a short line sits still rather than scrolling', (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Hi'});

    await pumpFriends(tester);

    // A marquee that scrolls when it does not need to is a distraction.
    expect(find.byType(Marquee), findsNothing);
    expect(find.text('Watching together: Hi'), findsOneWidget);
  });

  testWidgets('the friends still lay out on a short window', (tester) async {
    usePhoneSurface(tester, size: const Size(700, 360));
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('reordering keeps the lines and the drag handles',
      (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
      'luis': <String>[],
    });
    await seedFriend('ana', 'Ana');
    await seedFriend('luis', 'Luis');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester);
    await tester.tap(find.byType(ReorderToggle));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    // The line belongs to the friend, not to the mode, so it stays put while
    // the list is being rearranged.
    expect(find.text('Watching together: Severance'), findsOneWidget);
  });

  testWidgets('the line reads in Spanish too', (tester) async {
    usePhoneSurface(tester);
    seedSeenWith({
      'ana': ['1399'],
    });
    await seedFriend('ana', 'Ana');
    await seedProgress({
      '1399': {'started': '2026-01-01', 'updated': '2026-01-02'},
    });
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await pumpFriends(tester, locale: const Locale('es'));

    expect(find.text('Viendo juntos: Severance'), findsOneWidget);
  });
}
