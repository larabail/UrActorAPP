/// Tests for the two dialogues that add a title to a playlist.
///
/// They are near-identical twins that write to different fields of the same
/// document, so they are tested side by side: the mistake worth catching is
/// one of them writing where the other should.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/playlist.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/movie_add_popup.dart';
import 'package:uractor/popups/tv_add_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  late HttpStub http;

  setUp(() async {
    firestore = installFakeFirestore();
    user = installTestUser();
    http = installHttpStub();
    http.on('/search/movie', json: {
      'results': [
        {'id': 27205, 'title': 'Inception', 'poster_path': null},
      ]
    });
    http.on('/search/tv', json: {
      'results': [
        {'id': 1396, 'name': 'Breaking Bad', 'poster_path': null},
      ]
    });
    await firestore.collection('Watchlists').doc('list-1').set({
      'Name': 'Film club',
      'AccessCode': 'sesame',
      'CoverPhoto': '',
      'Movies': [],
      'TV Shows': [],
      'Users': [
        {'test-uid': 'Owner'}
      ],
      'memberUids': ['test-uid'],
    });
  });

  Playlist playlist() => Playlist(
        id: 'list-1',
        name: 'Film club',
        movies: [],
        tvshows: [],
        backdrop: '',
        accesscode: 'sesame',
        users: [
          {'test-uid': 'Owner'}
        ],
      );

  Future<void> openDialog(WidgetTester tester, Widget dialog) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String label, String term) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), term);
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> storedList() async {
    final doc = await firestore.collection('Watchlists').doc('list-1').get();
    return doc.data()!;
  }

  group('adding a film', () {
    const label = 'Name of The Movie You\'d Like to Add';

    testWidgets('names the list it is adding to', (tester) async {
      await openDialog(tester, MovieAddDialogue(list_result: playlist()));

      expect(find.text('Add a movie to "Film club"'), findsOneWidget);
    });

    testWidgets('does not search until something is typed', (tester) async {
      await openDialog(tester, MovieAddDialogue(list_result: playlist()));

      expect(http.countFor('/search/movie'), 0);

      await search(tester, label, 'inception');

      expect(http.countFor('/search/movie'), greaterThan(0));
      expect(find.byType(GridTile), findsOneWidget);
    });

    testWidgets('tapping a result puts its id on the list', (tester) async {
      await openDialog(tester, MovieAddDialogue(list_result: playlist()));
      await search(tester, label, 'inception');
      await tester.tap(find.byType(GridTile).first);
      await tester.pumpAndSettle();

      expect((await storedList())['Movies'], ['27205']);
      expect((await storedList())['TV Shows'], isEmpty,
          reason: 'a film must not land in the show list');
    });

    testWidgets('the list the caller holds is updated too', (tester) async {
      // The playlist screen renders from this object, so leaving it stale
      // makes the add look like it did nothing until the page is reopened.
      final list = playlist();
      await openDialog(tester, MovieAddDialogue(list_result: list));
      await search(tester, label, 'inception');
      await tester.tap(find.byType(GridTile).first);
      await tester.pumpAndSettle();

      expect(list.movies, ['27205']);
      expect(user.playlists['list-1']['Movies'], ['27205']);
      expect(find.byType(MovieAddDialogue), findsNothing);
    });

    testWidgets('a film already on the list is not added twice',
        (tester) async {
      await firestore.collection('Watchlists').doc('list-1').update({
        'Movies': ['27205'],
      });

      await openDialog(tester, MovieAddDialogue(list_result: playlist()));
      await search(tester, label, 'inception');
      await tester.tap(find.byType(GridTile).first);
      await tester.pumpAndSettle();

      expect((await storedList())['Movies'], ['27205']);
    });

    testWidgets('cancelling adds nothing', (tester) async {
      await openDialog(tester, MovieAddDialogue(list_result: playlist()));
      await search(tester, label, 'inception');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect((await storedList())['Movies'], isEmpty);
      expect(find.byType(MovieAddDialogue), findsNothing);
    });
  });

  group('adding a show', () {
    const label = 'Name of The TV Show You\'d Like to Add';

    testWidgets('names the list it is adding to', (tester) async {
      await openDialog(tester, TvAddDialogue(list_result: playlist()));

      expect(find.text('Add a TV Show to "Film club"'), findsOneWidget);
    });

    testWidgets('tapping a result puts its id under the shows', (tester) async {
      final list = playlist();
      await openDialog(tester, TvAddDialogue(list_result: list));
      await search(tester, label, 'breaking');
      await tester.tap(find.byType(GridTile).first);
      await tester.pumpAndSettle();

      expect((await storedList())['TV Shows'], ['1396']);
      expect((await storedList())['Movies'], isEmpty,
          reason: 'a show must not land in the film list');
      expect(list.tvshows, ['1396']);
    });

    testWidgets('searches the show endpoint, not the film one', (tester) async {
      await openDialog(tester, TvAddDialogue(list_result: playlist()));
      await search(tester, label, 'breaking');

      expect(http.countFor('/search/tv'), greaterThan(0));
      expect(http.countFor('/search/movie'), 0);
    });

    testWidgets('cancelling adds nothing', (tester) async {
      await openDialog(tester, TvAddDialogue(list_result: playlist()));
      await search(tester, label, 'breaking');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect((await storedList())['TV Shows'], isEmpty);
      expect(find.byType(TvAddDialogue), findsNothing);
    });
  });
}
