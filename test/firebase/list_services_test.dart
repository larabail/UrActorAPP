/// Tests for the watchlist and favorites services against an in-memory
/// Firestore.
///
/// Both services write to Firestore and then rebuild the matching in-memory
/// list on `currentUser`. The two going out of step is exactly the kind of bug
/// that shows up as an item that reappears after being removed, so both halves
/// are asserted every time.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/favorites_service.dart';
import 'package:uractor/common/firebase/watchlist_service.dart';
import 'package:uractor/main.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    installTestUser();
    firestore = installFakeFirestore();
  });

  Future<Map<String, dynamic>> readDoc(String name) async {
    final doc = await firestore.collection(currentUser.uid).doc(name).get();
    return doc.data()!;
  }

  group('WatchlistService.bookmark', () {
    setUp(() async {
      await seedUserDoc(firestore, currentUser.uid, 'Watchlist', {
        'Movies': <String>[],
        'TVShows': <String>[],
      });
    });

    test('stores the movie and reflects it in memory', () async {
      await WatchlistService.bookmark('27205', null, 'Movies');

      expect((await readDoc('Watchlist'))['Movies'], ['27205']);
      expect(currentUser.watchlist, [
        ['Movies', '27205']
      ]);
    });

    test('keeps shows in their own list', () async {
      await WatchlistService.bookmark('1399', null, 'TVShows');

      expect((await readDoc('Watchlist'))['TVShows'], ['1399']);
      expect(currentUser.watchlistTVShows, [
        ['TVShows', '1399']
      ]);
      expect(currentUser.watchlist, isEmpty);
    });

    test('does not store the same title twice', () async {
      await WatchlistService.bookmark('27205', null, 'Movies');
      await WatchlistService.bookmark('27205', null, 'Movies');

      expect((await readDoc('Watchlist'))['Movies'], ['27205']);
      expect(currentUser.watchlist, hasLength(1));
    });

    test('rebuilds the in-memory list rather than appending to it', () async {
      // The service clears and repopulates from Firestore. If it appended
      // instead, a second bookmark would duplicate everything already there.
      currentUser.watchlist = [
        ['Movies', 'stale']
      ];

      await WatchlistService.bookmark('27205', null, 'Movies');

      expect(currentUser.watchlist, [
        ['Movies', '27205']
      ]);
    });
  });

  group('WatchlistService.unbookmark', () {
    setUp(() async {
      await seedUserDoc(firestore, currentUser.uid, 'Watchlist', {
        'Movies': ['27205', '550'],
        'TVShows': ['1399'],
      });
    });

    test('removes the movie from storage and memory', () async {
      await WatchlistService.unbookmark('27205', null, 'Movies');

      expect((await readDoc('Watchlist'))['Movies'], ['550']);
      expect(currentUser.watchlist, [
        ['Movies', '550']
      ]);
    });

    test('leaves the other list untouched', () async {
      await WatchlistService.unbookmark('27205', null, 'Movies');

      expect((await readDoc('Watchlist'))['TVShows'], ['1399']);
    });

    test('does nothing for a title that is not on the list', () async {
      await WatchlistService.unbookmark('does-not-exist', null, 'Movies');

      expect((await readDoc('Watchlist'))['Movies'], ['27205', '550']);
    });

    test('empties the list when the last title is removed', () async {
      await WatchlistService.unbookmark('27205', null, 'Movies');
      await WatchlistService.unbookmark('550', null, 'Movies');

      expect((await readDoc('Watchlist'))['Movies'], isEmpty);
      expect(currentUser.watchlist, isEmpty);
    });
  });

  group('FavoritesService.favorite', () {
    setUp(() async {
      await seedUserDoc(firestore, currentUser.uid, 'Favorites', {
        'Movies': <String>[],
        'TVShows': <String>[],
      });
    });

    test('stores the movie and reflects it in memory', () async {
      await FavoritesService.favorite('27205', null, 'Movies');

      expect((await readDoc('Favorites'))['Movies'], ['27205']);
      expect(currentUser.favMovies, [
        ['Movies', '27205']
      ]);
    });

    test('keeps shows in their own list', () async {
      await FavoritesService.favorite('1399', null, 'TVShows');

      expect(currentUser.favTVShows, [
        ['TVShows', '1399']
      ]);
      expect(currentUser.favMovies, isEmpty);
    });

    test('does not store the same title twice', () async {
      await FavoritesService.favorite('27205', null, 'Movies');
      await FavoritesService.favorite('27205', null, 'Movies');

      expect((await readDoc('Favorites'))['Movies'], ['27205']);
    });
  });

  group('FavoritesService.unfavorite', () {
    setUp(() async {
      await seedUserDoc(firestore, currentUser.uid, 'Favorites', {
        'Movies': ['27205', '550'],
        'TVShows': ['1399'],
      });
    });

    test('removes the movie from storage and memory', () async {
      await FavoritesService.unfavorite('550', null, 'Movies');

      expect((await readDoc('Favorites'))['Movies'], ['27205']);
      expect(currentUser.favMovies, [
        ['Movies', '27205']
      ]);
    });

    test('removes a show without touching the movies', () async {
      await FavoritesService.unfavorite('1399', null, 'TVShows');

      expect((await readDoc('Favorites'))['TVShows'], isEmpty);
      expect((await readDoc('Favorites'))['Movies'], ['27205', '550']);
    });

    test('does nothing for a title that is not a favorite', () async {
      await FavoritesService.unfavorite('does-not-exist', null, 'Movies');

      expect((await readDoc('Favorites'))['Movies'], ['27205', '550']);
    });
  });
}
