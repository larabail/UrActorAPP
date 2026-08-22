/// Deciding whether a newer version has been published.
///
/// The desktop builds are not delivered by a store, so nothing tells a user
/// that a new version exists. The app asks, by fetching a small manifest from
/// the downloads site and comparing what it advertises against the running
/// version.
///
/// Everything here is pure: parsing a version, parsing a manifest, and
/// deciding whether one is newer than another. The fetching and the banner
/// live elsewhere, so the part that is easy to get wrong — and impossible to
/// eyeball, since it only misbehaves on version numbers nobody has shipped
/// yet — can be tested directly.
library;

import 'dart:convert';

/// A `MAJOR.MINOR.PATCH` version, with any `+build` suffix discarded.
///
/// The build number is deliberately not compared. It belongs to Play, which
/// assigns it at release time, so it is not a number the desktop builds
/// participate in and two desktop builds of the same version can carry
/// different ones. Comparing it would advertise an update that is the same
/// software.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses `3.15.0`, `3.15.0+74`, or `v3.15.0`.
  ///
  /// Returns null rather than throwing on anything it does not understand.
  /// A manifest is a file on a web server: it can be truncated, replaced by
  /// an error page, or edited by hand into nonsense, and none of those should
  /// take the app down or — worse — be read as "an update is available".
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;

    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }
    // Drop the build suffix and any pre-release tail; neither participates.
    text = text.split('+').first.split('-').first.trim();
    if (text.isEmpty) return null;

    final parts = text.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      // A negative or non-numeric component means this is not a version.
      if (value == null || value < 0) return null;
      numbers.add(value);
    }
    // A two part version is a real thing people write; treat `3.15` as
    // `3.15.0` rather than refusing it.
    while (numbers.length < 3) {
      numbers.add(0);
    }

    return AppVersion(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// What the downloads site says the newest version is.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.downloadUrl,
    this.notes,
  });

  final AppVersion version;

  /// Where to send someone who wants it. The page rather than the file, so a
  /// user reads the install notes — which on Windows explain the SmartScreen
  /// warning an unsigned build produces.
  final String downloadUrl;

  /// A short human description of what changed, if the manifest carries one.
  final String? notes;

  /// Parses the manifest published at `downloads.uractor.com/version.json`.
  ///
  /// Returns null for anything malformed. A manifest that cannot be read must
  /// leave the app exactly as it was: silence is the correct outcome of a
  /// failed update check, and is much better than an error a user can do
  /// nothing about.
  static UpdateManifest? tryParse(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    // Accepts a number as well as a string, since a hand-edited manifest is
    // as likely to say `"version": 3.16` as `"version": "3.16.0"`.
    final version = AppVersion.tryParse(decoded['version']?.toString());
    if (version == null) return null;

    final url = decoded['downloadUrl'];
    if (url is! String || url.isEmpty) return null;
    // Only ever hand a https link to the browser. The manifest is fetched
    // over https, but a file:// or custom-scheme URL smuggled into it would
    // be opened by the OS, so the scheme is checked rather than assumed.
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.scheme != 'https') return null;

    final notes = decoded['notes'];

    return UpdateManifest(
      version: version,
      downloadUrl: url,
      notes: notes is String && notes.trim().isNotEmpty ? notes.trim() : null,
    );
  }
}

/// Whether [manifest] describes something newer than [current].
///
/// False when they match, and false when the running build is *ahead* of the
/// manifest — which is the normal state of affairs on a development machine,
/// and where a naive "not equal" check would nag the one person who can least
/// act on it.
bool isUpdateAvailable({
  required AppVersion? current,
  required UpdateManifest? manifest,
}) {
  if (current == null || manifest == null) return false;
  return manifest.version > current;
}

/// Whether to actually show the banner for [manifest].
///
/// [dismissedVersion] is the version the user last waved away. Dismissing
/// 3.16.0 hides 3.16.0 and nothing else: when 3.17.0 arrives the banner comes
/// back. An update notice that cannot be silenced is an irritation, and one
/// that stays silenced forever is a bug that never gets reported.
bool shouldShowUpdateBanner({
  required AppVersion? current,
  required UpdateManifest? manifest,
  String? dismissedVersion,
}) {
  if (!isUpdateAvailable(current: current, manifest: manifest)) return false;

  final dismissed = AppVersion.tryParse(dismissedVersion);
  if (dismissed == null) return true;

  // Compared rather than string-matched, so a dismissal also covers anything
  // older that a manifest rollback might briefly advertise.
  return manifest!.version > dismissed;
}
