/// What the platform underneath can and cannot do.
///
/// Adding macOS and Windows means some of the plugins the app leans on are no
/// longer there. That is not a reason to hide a feature on every platform, nor
/// to let a screen call a plugin that will throw at runtime, so each gap is
/// named here and the screens ask before they act.
///
/// The decisions are pure functions of the platform so they can be tested for
/// every value of [TargetPlatform] rather than only the one the suite happens
/// to run on.
library;

import 'package:flutter/foundation.dart';

/// Whether a picked image can be cropped before it is uploaded.
///
/// `image_cropper` ships Android, iOS and web implementations only. On desktop
/// the picker still works, so the photo is uploaded as chosen rather than the
/// whole feature being withdrawn.
bool cropsImagesOn(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return true;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

/// Whether a trailer can be played inline.
///
/// The player is a webview underneath, and `webview_flutter` has no Windows or
/// Linux implementation. Where it cannot play, the trailer is offered as a
/// link out to YouTube instead of disappearing.
bool playsEmbeddedVideoOn(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return true;
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;
}

/// Whether this is a desktop platform, where a pointer and a keyboard are the
/// primary inputs rather than a finger.
bool isDesktopPlatform(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return false;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

/// The capabilities of the platform actually running.
abstract final class Capabilities {
  /// See [cropsImagesOn].
  static bool get cropsImages =>
      cropsImagesOn(defaultTargetPlatform, isWeb: kIsWeb);

  /// See [playsEmbeddedVideoOn].
  static bool get playsEmbeddedVideo =>
      playsEmbeddedVideoOn(defaultTargetPlatform, isWeb: kIsWeb);

  /// See [isDesktopPlatform].
  static bool get isDesktop =>
      isDesktopPlatform(defaultTargetPlatform, isWeb: kIsWeb);
}
