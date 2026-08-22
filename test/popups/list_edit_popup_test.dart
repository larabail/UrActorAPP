/// Tests for the edit-a-playlist dialogue.
///
/// The dialogue finds the document to change by matching the name and access
/// code it was opened with, rather than by id, so a list that shares a name
/// with someone else's is the case that decides whether it is safe.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/list_result.dart' as list_result;
import 'package:uractor/objects/playlist.dart';
import 'package:uractor/popups/list_edit_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = installFakeFirestore();
    installTestUser();
    installHttpStub();
    // The dialogue edits through these module-level fields rather than its
    // own state, and they are what the playlist screen fills in before it
    // opens the dialogue.
    list_result.originalListName = 'Film club';
    list_result.originalAccessCode = 'sesame';
    list_result.listName = 'Film club';
    list_result.accessCode = 'sesame';
    list_result.cover = 'https://image.tmdb.org/t/p/w500//old.jpg';

    await firestore.collection('Watchlists').doc('list-1').set({
      'Name': 'Film club',
      'AccessCode': 'sesame',
      'CoverPhoto': 'https://image.tmdb.org/t/p/w500//old.jpg',
      'Movies': ['27205'],
      'TV Shows': [],
      'Users': [
        {'test-uid': 'Owner'}
      ],
      'memberUids': ['test-uid'],
    });
  });

  tearDown(() {
    list_result.originalListName = '';
    list_result.originalAccessCode = '';
    list_result.listName = '';
    list_result.accessCode = '';
    list_result.cover = '';
  });

  Playlist playlist() => Playlist(
        id: 'list-1',
        name: 'Film club',
        movies: ['27205'],
        tvshows: [],
        backdrop: 'https://image.tmdb.org/t/p/w500//old.jpg',
        accesscode: 'sesame',
        users: [
          {'test-uid': 'Owner'}
        ],
      );

  Future<void> openDialog(WidgetTester tester, Playlist list) async {
    // Wider than a phone on purpose. At 400pt the Cancel/Accept row overflows
    // by ~47px, which is a real layout problem in the dialogue but not what
    // these tests are about, and it would mask every assertion below.
    usePhoneSurface(tester, size: const Size(560, 900));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ListEditDialogue(list_result: list),
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

  Future<Map<String, dynamic>> storedList([String id = 'list-1']) async {
    final doc = await firestore.collection('Watchlists').doc(id).get();
    return doc.data()!;
  }

  testWidgets('opens on the list being modified, prefilled', (tester) async {
    await openDialog(tester, playlist());

    expect(find.text('Modify "Film club"'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Film club'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'sesame'), findsOneWidget);
  });

  testWidgets('accepting saves the new name and access code', (tester) async {
    await openDialog(tester, playlist());

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Film club'), 'Book club');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'sesame'), 'open');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    final stored = await storedList();
    expect(stored['Name'], 'Book club');
    expect(stored['AccessCode'], 'open');
  });

  testWidgets('what the list already holds survives the edit', (tester) async {
    // The save merges three fields into the document; writing the whole
    // document instead would take the titles on the list with it.
    await openDialog(tester, playlist());

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Film club'), 'Book club');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    final stored = await storedList();
    expect(stored['Movies'], ['27205']);
    expect(stored['memberUids'], ['test-uid']);
  });

  testWidgets('the list the caller holds is updated too', (tester) async {
    final list = playlist();
    await openDialog(tester, list);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Film club'), 'Book club');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(list.name, 'Book club');
    expect(list.accesscode, 'sesame');
    expect(find.byType(ListEditDialogue), findsNothing);
  });

  testWidgets('another list with the same name but a different code is left '
      'alone', (tester) async {
    // Two people can call a list "Film club". The access code is the only
    // thing separating them here, so it has to be part of the match.
    await firestore.collection('Watchlists').doc('list-2').set({
      'Name': 'Film club',
      'AccessCode': 'different',
      'CoverPhoto': '',
      'Movies': [],
      'TV Shows': [],
      'Users': [
        {'someone-else': 'Owner'}
      ],
      'memberUids': ['someone-else'],
    });

    await openDialog(tester, playlist());
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Film club'), 'Book club');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect((await storedList())['Name'], 'Book club');
    expect((await storedList('list-2'))['Name'], 'Film club');
  });

  testWidgets('cancelling changes nothing', (tester) async {
    await openDialog(tester, playlist());

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Film club'), 'Book club');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await storedList())['Name'], 'Film club');
    expect(find.byType(ListEditDialogue), findsNothing);
  });

  testWidgets('picking a new cover saves it against the list', (tester) async {
    final http = installHttpStub();
    http.on('/search/movie', json: {
      'results': [
        {'id': 603, 'title': 'The Matrix', 'backdrop_path': '/matrix.jpg'},
      ]
    });

    await openDialog(tester, playlist());
    await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Name of The Movie You\'d Like as Cover'),
        'matrix');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect((await storedList())['CoverPhoto'],
        'https://image.tmdb.org/t/p/w500//matrix.jpg');
  });
}
