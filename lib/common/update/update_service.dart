/// Asking the downloads site whether there is a newer version.
///
/// The decision rules are in `update_check.dart` and are pure. This is the
/// part that touches the network and the stored settings, kept separate so
/// the rules can be tested without either.
library;

import 'package:flutter/foundation.dart';

import '../api/http_client.dart';
import '../firebase/settings_service.dart';
import '../platform/capabilities.dart';
import 'update_check.dart';

/// Where the newest published version is advertised.
///
/// A small JSON file rather than the GitHub releases API: it has no rate
/// limit, needs no token, and can be pointed somewhere else without shipping
/// a new build. The installers themselves live on GitHub releases, which the
/// manifest links to.
const String kUpdateManifestUrl = 'https://downloads.uractor.com/version.json';

/// The settings key holding the last version the user waved away.
const String kDismissedUpdateSettingsKey = 'dismissedUpdateVersion';

/// Checks whether a newer version has been published, and whether to say so.
///
/// Returns null when there is nothing to show, which is the answer in the
/// overwhelming majority of launches and in every failure case. A user who
/// cannot reach the downloads site is a user who cannot download an update
/// either, so an error here is not worth reporting to them.
class UpdateService {
  /// The version currently running, as `MAJOR.MINOR.PATCH`.
  ///
  /// Supplied by the caller rather than read here, so this stays testable
  /// without a plugin.
  static Future<UpdateManifest?> check({
    required String currentVersion,
    String manifestUrl = kUpdateManifestUrl,
  }) async {
    // Android and iOS are updated by their stores, which do this better than
    // the app can and do not need telling. Checking there would be noise at
    // best and a second, contradictory update prompt at worst.
    if (!Capabilities.isDesktop) return null;

    final current = AppVersion.tryParse(currentVersion);
    if (current == null) return null;

    final UpdateManifest? manifest = await _fetch(manifestUrl);
    if (manifest == null) return null;

    if (!shouldShowUpdateBanner(
      current: current,
      manifest: manifest,
      dismissedVersion:
          SettingsService.read<dynamic>(kDismissedUpdateSettingsKey, null)
              ?.toString(),
    )) {
      return null;
    }

    return manifest;
  }

  static Future<UpdateManifest?> _fetch(String url) async {
    try {
      final response = await AppHttp.client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return UpdateManifest.tryParse(response.body);
    } catch (error) {
      // Offline, DNS failure, timeout, a proxy serving an error page. None of
      // these are the user's problem and none should reach them.
      debugPrint('Update check failed: $error');
      return null;
    }
  }

  /// Remembers that the user does not want to hear about [version] again.
  ///
  /// The next version after it will still be offered — see
  /// `shouldShowUpdateBanner`.
  static Future<void> dismiss(AppVersion version) =>
      SettingsService.update(kDismissedUpdateSettingsKey, version.toString());
}
