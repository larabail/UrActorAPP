import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'constants.dart';

/// The Firebase Storage objects the placeholders used to be served from.
///
/// They now answer 403, but the URLs outlived them: `Share` copies a media
/// item's `coverPhoto` into the recipient's notification document, so friends'
/// Firestore data is full of these strings and will be for as long as those
/// notifications are kept. Recognising them here is what stops an old
/// notification from failing to draw.
const List<String> _deadRemoteCover = [
  "UNKNOWN_cover.png",
];
const List<String> _deadRemotePerson = [
  "UNKNOWN_actor.png",
];

/// Resolves a stored image reference to one that can actually be drawn.
///
/// Returns [fallback] for a reference that names no image at all -- null, or
/// the empty string several screens use when TMDB gave them no path -- and
/// swaps the retired Firebase placeholder URLs for their bundled equivalents.
/// Anything else is a real image and is returned untouched.
///
/// [fallback] chooses which placeholder stands in: [UNKNOWN_PERSON] for a
/// cast member, [UNKNOWN_COVER] for everything else.
String resolveMediaImagePath(String? path, {String fallback = UNKNOWN_COVER}) {
  if (path == null || path.trim().isEmpty) return fallback;
  if (_deadRemoteCover.any(path.contains)) return UNKNOWN_COVER;
  if (_deadRemotePerson.any(path.contains)) return UNKNOWN_PERSON;
  return path;
}

/// Whether [path] names an asset shipped in the bundle rather than a URL.
bool isBundledImage(String path) => path.startsWith("assets/");

/// The provider for a stored image reference, resolved by
/// [resolveMediaImagePath].
///
/// A bundled placeholder is read from the bundle; only a real remote image
/// goes through the network cache. Passing an asset path to
/// `CachedNetworkImageProvider` would throw, so this is the only safe way to
/// turn one of these references into an image.
ImageProvider mediaImageProvider(String? path,
    {String fallback = UNKNOWN_COVER}) {
  final String resolved = resolveMediaImagePath(path, fallback: fallback);
  return isBundledImage(resolved)
      ? AssetImage(resolved)
      : CachedNetworkImageProvider(resolved);
}
