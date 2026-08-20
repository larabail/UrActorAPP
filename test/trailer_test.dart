import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/mediaitembuilder.dart';

/// The player itself is not exercised here. youtube_player_flutter 10 is backed
/// by a webview, which has no implementation in the test binding, so anything
/// that builds one has to be checked on a device. What is covered is the half
/// that decides whether a player is built at all — previously a try/catch around
/// a nested subscript, now an explicit check, and the difference matters because
/// TMDB routinely returns a title with no trailer.
void main() {
  group('getTrailer', () {
    void expectsNothing(Widget widget) {
      expect(widget, isA<SizedBox>());
      expect((widget as SizedBox).width, 0);
      expect(widget.height, 0);
    }

    test('renders nothing when the data has no trailer at all', () {
      expectsNothing(getTrailer(<String, dynamic>{}));
    });

    test('renders nothing when the trailer is null', () {
      expectsNothing(getTrailer(<String, dynamic>{'trailer': null}));
    });

    test('renders nothing when the trailer carries no key', () {
      expectsNothing(getTrailer(<String, dynamic>{'trailer': <String, dynamic>{}}));
    });

    test('renders nothing when the key is empty', () {
      expectsNothing(
        getTrailer(<String, dynamic>{
          'trailer': <String, dynamic>{'key': ''},
        }),
      );
    });

    // The old implementation reached straight into data["trailer"]["key"] and
    // relied on a catch-all to survive anything unexpected. A non-map trailer is
    // the case that would have thrown.
    test('renders nothing when the trailer is not a map', () {
      expectsNothing(getTrailer(<String, dynamic>{'trailer': 'dQw4w9WgXcQ'}));
      expectsNothing(getTrailer(<String, dynamic>{'trailer': <dynamic>[]}));
    });
  });
}
