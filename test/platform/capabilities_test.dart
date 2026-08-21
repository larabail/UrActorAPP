/// Tests for the platform capability checks.
///
/// Adding macOS and Windows means some plugins are no longer present, and the
/// screens that use them have to ask first. These assert the answer for every
/// platform rather than only the one the suite happens to run on, because the
/// whole point of the module is the platforms the developer is not looking at.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/platform/capabilities.dart';

void main() {
  group('cropsImagesOn', () {
    test('the phones, where image_cropper has an implementation', () {
      expect(cropsImagesOn(TargetPlatform.android), isTrue);
      expect(cropsImagesOn(TargetPlatform.iOS), isTrue);
    });

    test('not on desktop, where it has none', () {
      expect(cropsImagesOn(TargetPlatform.macOS), isFalse);
      expect(cropsImagesOn(TargetPlatform.windows), isFalse);
      expect(cropsImagesOn(TargetPlatform.linux), isFalse);
    });

    test('on the web, which image_cropper does support', () {
      // The platform reported under a web build is whatever the browser is
      // running on, so the web flag has to win over it.
      expect(cropsImagesOn(TargetPlatform.macOS, isWeb: true), isTrue);
    });
  });

  group('playsEmbeddedVideoOn', () {
    test('wherever webview_flutter has an implementation', () {
      expect(playsEmbeddedVideoOn(TargetPlatform.android), isTrue);
      expect(playsEmbeddedVideoOn(TargetPlatform.iOS), isTrue);
      expect(playsEmbeddedVideoOn(TargetPlatform.macOS), isTrue);
    });

    test('not on Windows or Linux, which have no webview', () {
      expect(playsEmbeddedVideoOn(TargetPlatform.windows), isFalse);
      expect(playsEmbeddedVideoOn(TargetPlatform.linux), isFalse);
    });

    test('on the web, where the player is an iframe', () {
      expect(playsEmbeddedVideoOn(TargetPlatform.windows, isWeb: true), isTrue);
    });
  });

  group('isDesktopPlatform', () {
    test('the three desktops', () {
      expect(isDesktopPlatform(TargetPlatform.macOS), isTrue);
      expect(isDesktopPlatform(TargetPlatform.windows), isTrue);
      expect(isDesktopPlatform(TargetPlatform.linux), isTrue);
    });

    test('not the phones', () {
      expect(isDesktopPlatform(TargetPlatform.android), isFalse);
      expect(isDesktopPlatform(TargetPlatform.iOS), isFalse);
    });

    test('a browser is not a desktop, whatever it is running on', () {
      // The distinction is about which plugins exist and how the user points
      // at things, and a web build is its own answer to both.
      expect(isDesktopPlatform(TargetPlatform.macOS, isWeb: true), isFalse);
    });
  });

  group('every platform gets an answer', () {
    test('no capability check throws on any target', () {
      for (final platform in TargetPlatform.values) {
        expect(() => cropsImagesOn(platform), returnsNormally);
        expect(() => playsEmbeddedVideoOn(platform), returnsNormally);
        expect(() => isDesktopPlatform(platform), returnsNormally);
      }
    });
  });
}
