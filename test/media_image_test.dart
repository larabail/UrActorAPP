import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/common/media_image.dart';

/// One of the Firebase Storage URLs the placeholders used to be served from.
/// It answers 403 now, and copies of it are still sitting in notification
/// documents that were written while it worked.
const String _retiredCoverUrl =
    'https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/UNKNOWN_cover.png?alt=media&token=4a9b8c89-67b4-4859-91c1-166383ab1586';
const String _retiredPersonUrl =
    'https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/UNKNOWN_actor.png?alt=media&token=054473a7-ed7a-4bc7-9ff9-7b7f37b5ae84';

const String _realPoster = 'https://image.tmdb.org/t/p/w500/inception.jpg';

void main() {
  group('the placeholder constants', () {
    test('name bundled assets rather than a remote host', () {
      for (final placeholder in [UNKNOWN_COVER, UNKNOWN_PERSON]) {
        expect(placeholder, isNot(startsWith('http')));
        expect(isBundledImage(placeholder), isTrue);
      }
    });

    testWidgets('are actually shipped in the bundle', (tester) async {
      for (final placeholder in [UNKNOWN_COVER, UNKNOWN_PERSON]) {
        final bytes = await rootBundle.load(placeholder);
        expect(bytes.lengthInBytes, greaterThan(0),
            reason: '$placeholder is declared but empty');
      }
    });
  });

  group('resolveMediaImagePath', () {
    test('falls back when the reference names no image', () {
      expect(resolveMediaImagePath(null), UNKNOWN_COVER);
      expect(resolveMediaImagePath(''), UNKNOWN_COVER);
      expect(resolveMediaImagePath('   '), UNKNOWN_COVER);
    });

    test('uses the fallback it was given', () {
      expect(resolveMediaImagePath(null, fallback: UNKNOWN_PERSON),
          UNKNOWN_PERSON);
    });

    test('swaps the retired Firebase URLs for their bundled equivalents', () {
      expect(resolveMediaImagePath(_retiredCoverUrl), UNKNOWN_COVER);
      expect(resolveMediaImagePath(_retiredPersonUrl), UNKNOWN_PERSON);
    });

    test('leaves a real image alone', () {
      expect(resolveMediaImagePath(_realPoster), _realPoster);
    });
  });

  group('mediaImageProvider', () {
    test('reads a placeholder from the bundle', () {
      for (final placeholder in [UNKNOWN_COVER, UNKNOWN_PERSON]) {
        final provider = mediaImageProvider(placeholder);
        expect(provider, isA<AssetImage>());
        expect((provider as AssetImage).assetName, placeholder);
      }
    });

    test('keeps a retired URL off the network', () {
      for (final url in [_retiredCoverUrl, _retiredPersonUrl]) {
        expect(mediaImageProvider(url), isA<AssetImage>());
      }
    });

    test('never turns a missing reference into a request', () {
      expect(mediaImageProvider(null), isA<AssetImage>());
      expect(mediaImageProvider(''), isA<AssetImage>());
    });

    test('still caches a real image over the network', () {
      final provider = mediaImageProvider(_realPoster);
      expect(provider, isA<CachedNetworkImageProvider>());
      expect((provider as CachedNetworkImageProvider).url, _realPoster);
    });
  });
}
