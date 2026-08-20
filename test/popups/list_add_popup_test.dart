/// Tests for the create-a-playlist dialogue.
///
/// A playlist is created in one write, and that write has to carry both the
/// owner entry and the flat `memberUids` projection the security rules query
/// on. A list created with one but not the other is visible to nobody.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/list_add_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  late HttpStub http;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser();
    http = installHttpStub();
    http.on('/search/movie', json: {
      'results': [
        {'id': 27205, 'title': 'Inception', 'backdrop_path': '/inception.jpg'},
        {'id': 603, 'title': 'The Matrix', 'backdrop_path': '/matrix.jpg'},
      ]
    });
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ListAddDialogue(),
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

  Future<Map<String, dynamic>?> theOneList() async {
    final snapshot = await firestore.collection('Watchlists').get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.single.data();
  }

  /// Fills the form in the order a person would, which is what puts a cover on
  /// the list: the first search result is taken unless another is tapped.
  Future<void> fillForm(WidgetTester tester,
      {String name = 'Film club', String code = 'sesame'}) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'List Name'), name);
    await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Name of The Movie You\'d Like as Cover'),
        'inception');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Access Code For Other People'),
        code);
    await tester.pumpAndSettle();
  }

  testWidgets('offers a name, a cover search and an access code',
      (tester) async {
    await openDialog(tester);

    expect(find.text('Create a New List'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'List Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Access Code For Other People'),
        findsOneWidget);
  });

  testWidgets('searches for a cover only once something has been typed',
      (tester) async {
    await openDialog(tester);

    expect(http.countFor('/search/movie'), 0);

    await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Name of The Movie You\'d Like as Cover'),
        'inception');
    await tester.pumpAndSettle();

    expect(http.countFor('/search/movie'), greaterThan(0));
    expect(find.text('Inception'), findsWidgets);
  });

  testWidgets('creates the list with the owner recorded both ways',
      (tester) async {
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final list = (await theOneList())!;
    expect(list['Name'], 'Film club');
    expect(list['AccessCode'], 'sesame');
    expect(list['Users'], [
      {'test-uid': 'Owner'}
    ]);
    expect(list['memberUids'], ['test-uid']);
  });

  testWidgets('the new list starts empty', (tester) async {
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final list = (await theOneList())!;
    expect(list['Movies'], isEmpty);
    expect(list['TV Shows'], isEmpty);
  });

  testWidgets('the first search result becomes the cover', (tester) async {
    // Nothing forces a choice, so whatever is highlighted when Add is pressed
    // is what gets saved, and that is the first result until one is tapped.
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect((await theOneList())!['CoverPhoto'],
        'https://image.tmdb.org/t/p/w500//inception.jpg');
  });

  testWidgets('picking a different result changes the cover', (tester) async {
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('The Matrix'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect((await theOneList())!['CoverPhoto'],
        'https://image.tmdb.org/t/p/w500//matrix.jpg');
  });

  testWidgets('the list shows up without reloading the account',
      (tester) async {
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(user.playlists, hasLength(1));
    expect(user.playlists.values.single['Name'], 'Film club');
    expect(find.byType(ListAddDialogue), findsNothing);
  });

  testWidgets('cancelling creates nothing', (tester) async {
    await openDialog(tester);
    await fillForm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await theOneList(), isNull);
    expect(find.byType(ListAddDialogue), findsNothing);
  });

  testWidgets('each list gets its own id', (tester) async {
    // Ids used to be random seven-digit numbers checked for collisions by
    // downloading the whole collection. Two lists created in a row must still
    // be two documents.
    await openDialog(tester);
    await fillForm(tester, name: 'First');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await fillForm(tester, name: 'Second');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final snapshot = await firestore.collection('Watchlists').get();
    expect(snapshot.docs, hasLength(2));
    expect(snapshot.docs.map((doc) => doc.data()['Name']),
        containsAll(['First', 'Second']));
  });
}
