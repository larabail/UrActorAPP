import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/constants.dart';

/// Every TMDB endpoint that carries an api_key parameter.
const List<String> keyedEndpoints = [
  API_KEY,
  CREDITS_LINK,
  VIDEOS_LINK,
  EXTERNAL_IDS_LINK,
  WATCH_PROVIDERS_LINK,
  MOVIE_CREDITS_LINK,
  TV_SHOW_CREDITS_LINK,
  SEARCH_BY_NAME_MOVIE_LINK,
  SEARCH_BY_NAME_TV_SHOW_LINK,
  SEARCH_BY_NAME_MULTI_LINK,
  GENRES_LINK,
  COUNTRIES_LINK,
  WATCH_PROVIDERS_BY_REGION_LINK,
];

void main() {
  group('assertTmdbApiKey', () {
    test('throws when the key is empty', () {
      expect(() => assertTmdbApiKey(''), throwsStateError);
    });

    test('passes when a key is supplied', () {
      expect(() => assertTmdbApiKey('a-key'), returnsNormally);
    });
  });

  group('TMDB endpoints', () {
    test('API_KEY is built from the TMDB_API_KEY define', () {
      expect(API_KEY, equals('?api_key=$TMDB_API_KEY'));
    });

    test('every endpoint carries an api_key parameter', () {
      for (final link in keyedEndpoints) {
        expect(link, contains('api_key='), reason: link);
      }
    });

    test('no endpoint hardcodes a key instead of using the define', () {
      // Each api_key value must be exactly whatever TMDB_API_KEY resolved to.
      // With no --dart-define that is the empty string, so a committed literal
      // fails here; with a define set, a stale literal still fails because it
      // will not match the supplied value.
      final keyParameter = RegExp(r'api_key=([^&]*)');
      for (final link in keyedEndpoints) {
        for (final match in keyParameter.allMatches(link)) {
          expect(match.group(1), equals(TMDB_API_KEY), reason: link);
        }
      }
    });
  });
}
