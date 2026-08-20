import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/media_pair_membership.dart';

void main() {
  group('shouldShowFavoriteBadge', () {
    test('shows for a movie that is in favorites', () {
      expect(
        shouldShowFavoriteBadge(
          showFavoriteBadge: true,
          favoriteItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '42'],
        ),
        isTrue,
      );
    });

    test('does not show for a movie that is not in favorites', () {
      expect(
        shouldShowFavoriteBadge(
          showFavoriteBadge: true,
          favoriteItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '7'],
        ),
        isFalse,
      );
    });

    test('shows for a TV show that is in favorites', () {
      expect(
        shouldShowFavoriteBadge(
          showFavoriteBadge: true,
          favoriteItems: [
            ['TVShows', '99'],
          ],
          item: ['TVShows', '99'],
        ),
        isTrue,
      );
    });

    test('does not show when the badge flag is off', () {
      expect(
        shouldShowFavoriteBadge(
          showFavoriteBadge: false,
          favoriteItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '42'],
        ),
        isFalse,
      );
    });

    test('does not match the same id with a different type', () {
      expect(
        shouldShowFavoriteBadge(
          showFavoriteBadge: true,
          favoriteItems: [
            ['Movies', '99'],
          ],
          item: ['TVShows', '99'],
        ),
        isFalse,
      );
    });
  });

  group('shouldShowWatchlistBadge', () {
    test('shows for a movie that is on the watchlist', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: true,
          watchlistItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '42'],
        ),
        isTrue,
      );
    });

    test('does not show for a movie that is not on the watchlist', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: true,
          watchlistItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '7'],
        ),
        isFalse,
      );
    });

    test('shows for a TV show that is on the watchlist', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: true,
          watchlistItems: [
            ['TVShows', '99'],
          ],
          item: ['TVShows', '99'],
        ),
        isTrue,
      );
    });

    test('does not show when the badge flag is off', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: false,
          watchlistItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', '42'],
        ),
        isFalse,
      );
    });

    test('does not match the same id with a different type', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: true,
          watchlistItems: [
            ['Movies', '99'],
          ],
          item: ['TVShows', '99'],
        ),
        isFalse,
      );
    });

    test('matches an int id against a stored string id', () {
      expect(
        shouldShowWatchlistBadge(
          showWatchlistBadge: true,
          watchlistItems: [
            ['Movies', '42'],
          ],
          item: ['Movies', 42],
        ),
        isTrue,
      );
    });
  });

  group('mediaPairForData', () {
    test('trusts an explicit container type', () {
      expect(
        mediaPairForData({'id': 42, 'name': 'Ambiguous'},
            containerType: 'Movies'),
        ['Movies', '42'],
      );
    });

    test('refuses to identify a person tile', () {
      expect(
        mediaPairForData(
          {'id': 7, 'name': 'Someone', 'poster_path': '/p.jpg'},
          containerType: 'person',
        ),
        isNull,
      );
    });

    test('prefers the type key over the title key', () {
      // Utils.fetchMediaData copies a show's name into "title", so inferring
      // from the keys alone would call every fetched show a movie.
      expect(
        mediaPairForData({'id': 99, 'title': 'A Show', 'type': 'TVShows'}),
        ['TVShows', '99'],
      );
    });

    test('reads the media_type a search result carries', () {
      expect(
        mediaPairForData({'id': 5, 'name': 'A Show', 'media_type': 'tv'}),
        ['TVShows', '5'],
      );
      expect(
        mediaPairForData({'id': 5, 'title': 'A Film', 'media_type': 'movie'}),
        ['Movies', '5'],
      );
    });

    test('infers a movie from a title and a show from a name', () {
      expect(
        mediaPairForData({'id': 1, 'title': 'A Film'}, containerType: 'media'),
        ['Movies', '1'],
      );
      expect(
        mediaPairForData({'id': 2, 'name': 'A Show'}, containerType: 'media'),
        ['TVShows', '2'],
      );
    });

    test('returns null for anything it cannot identify', () {
      expect(mediaPairForData(null), isNull);
      expect(mediaPairForData('not a map'), isNull);
      expect(mediaPairForData({'title': 'No id'}), isNull);
      expect(mediaPairForData({'id': 3}), isNull);
    });
  });
}
