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
}
