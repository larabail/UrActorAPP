/// Tests for the desktop update check.
///
/// The desktop builds are not delivered by a store, so this is the only thing
/// that tells a user a new version exists. It is also the only code in the app
/// that reads a file written by whoever last ran a release, so it has to treat
/// that file as hostile: a truncated download, an error page served instead of
/// JSON, or a hand-edit that dropped a quote must all end in silence rather
/// than a crash or a false alarm.
///
/// The comparisons matter most for versions nobody has shipped yet — 3.9.0 to
/// 3.10.0 is the classic one, where a string comparison says the update is
/// older than what is running and the notice never appears.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/update/update_check.dart';

UpdateManifest manifestFor(String version) => UpdateManifest(
      version: AppVersion.tryParse(version)!,
      downloadUrl: 'https://downloads.uractor.com/',
    );

void main() {
  group('AppVersion.tryParse', () {
    test('reads a plain version', () {
      expect(AppVersion.tryParse('3.15.0'), const AppVersion(3, 15, 0));
    });

    test('discards the build suffix, which belongs to Play', () {
      // Two desktop builds of the same version can carry different build
      // numbers, and comparing them would advertise an update that is the
      // same software.
      expect(AppVersion.tryParse('3.15.0+74'), const AppVersion(3, 15, 0));
      expect(AppVersion.tryParse('3.15.0+74'), AppVersion.tryParse('3.15.0'));
    });

    test('tolerates a leading v, which git tags carry', () {
      expect(AppVersion.tryParse('v3.15.0'), const AppVersion(3, 15, 0));
    });

    test('treats a two part version as a patch of zero', () {
      expect(AppVersion.tryParse('3.15'), const AppVersion(3, 15, 0));
    });

    test('tolerates surrounding whitespace', () {
      expect(AppVersion.tryParse('  3.15.0 \n'), const AppVersion(3, 15, 0));
    });

    test('refuses what is not a version rather than guessing', () {
      for (final bad in <String?>[
        null,
        '',
        '   ',
        'latest',
        '3.x.0',
        '3..0',
        '-1.0.0',
        '1.2.3.4',
        'v',
      ]) {
        expect(AppVersion.tryParse(bad), isNull, reason: 'accepted "$bad"');
      }
    });
  });

  group('comparison', () {
    test('orders by major, then minor, then patch', () {
      expect(const AppVersion(4, 0, 0) > const AppVersion(3, 99, 99), isTrue);
      expect(const AppVersion(3, 16, 0) > const AppVersion(3, 15, 9), isTrue);
      expect(const AppVersion(3, 15, 1) > const AppVersion(3, 15, 0), isTrue);
    });

    test('compares numerically, not as text', () {
      // The case that a string comparison gets backwards: "3.9.0" sorts after
      // "3.10.0" alphabetically, so a lazy check would never offer the update.
      expect(const AppVersion(3, 10, 0) > const AppVersion(3, 9, 0), isTrue);
      expect(const AppVersion(3, 9, 0) > const AppVersion(3, 10, 0), isFalse);
    });

    test('equal versions are not greater than each other', () {
      expect(const AppVersion(3, 15, 0) > const AppVersion(3, 15, 0), isFalse);
    });
  });

  group('UpdateManifest.tryParse', () {
    test('reads a well formed manifest', () {
      final manifest = UpdateManifest.tryParse(jsonEncode({
        'version': '3.16.0',
        'downloadUrl': 'https://downloads.uractor.com/',
        'notes': 'Playlists can be reordered.',
      }));

      expect(manifest, isNotNull);
      expect(manifest!.version, const AppVersion(3, 16, 0));
      expect(manifest.downloadUrl, 'https://downloads.uractor.com/');
      expect(manifest.notes, 'Playlists can be reordered.');
    });

    test('notes are optional', () {
      final manifest = UpdateManifest.tryParse(jsonEncode({
        'version': '3.16.0',
        'downloadUrl': 'https://downloads.uractor.com/',
      }));

      expect(manifest?.notes, isNull);
    });

    test('blank notes read as absent rather than an empty banner line', () {
      final manifest = UpdateManifest.tryParse(jsonEncode({
        'version': '3.16.0',
        'downloadUrl': 'https://downloads.uractor.com/',
        'notes': '   ',
      }));

      expect(manifest?.notes, isNull);
    });

    test('a version given as a number still parses', () {
      final manifest = UpdateManifest.tryParse(
          '{"version": 3.16, "downloadUrl": "https://downloads.uractor.com/"}');

      expect(manifest?.version, const AppVersion(3, 16, 0));
    });

    test('anything malformed is silence, not a crash', () {
      for (final bad in <String>[
        '',
        'not json at all',
        '<html>404 Not Found</html>',
        '[]',
        'null',
        '{"downloadUrl": "https://downloads.uractor.com/"}', // no version
        '{"version": "3.16.0"}', // no url
        '{"version": "3.16.0", "downloadUrl": ""}',
        '{"version": "latest", "downloadUrl": "https://x.example/"}',
        '{"version": "3.16.0", "downloadUrl": 42}',
      ]) {
        expect(UpdateManifest.tryParse(bad), isNull,
            reason: 'accepted ${bad.isEmpty ? "(empty)" : bad}');
      }
    });

    test('only an https link is ever handed to the browser', () {
      // The manifest is fetched over https, but the URL inside it is opened by
      // the operating system, so a smuggled scheme would be launched as given.
      for (final url in <String>[
        'file:///etc/passwd',
        'http://downloads.uractor.com/',
        'javascript:alert(1)',
        'ftp://example.com/x.dmg',
      ]) {
        final manifest = UpdateManifest.tryParse(
            jsonEncode({'version': '3.16.0', 'downloadUrl': url}));
        expect(manifest, isNull, reason: 'accepted $url');
      }
    });
  });

  group('isUpdateAvailable', () {
    test('offers a newer version', () {
      expect(
        isUpdateAvailable(
            current: const AppVersion(3, 15, 0),
            manifest: manifestFor('3.16.0')),
        isTrue,
      );
    });

    test('says nothing when the versions match', () {
      expect(
        isUpdateAvailable(
            current: const AppVersion(3, 15, 0),
            manifest: manifestFor('3.15.0')),
        isFalse,
      );
    });

    test('says nothing when the running build is ahead', () {
      // The normal state on a development machine, and the one person who can
      // least act on a download prompt.
      expect(
        isUpdateAvailable(
            current: const AppVersion(3, 16, 0),
            manifest: manifestFor('3.15.0')),
        isFalse,
      );
    });

    test('says nothing when either side is unknown', () {
      expect(isUpdateAvailable(current: null, manifest: manifestFor('3.16.0')),
          isFalse);
      expect(
          isUpdateAvailable(
              current: const AppVersion(3, 15, 0), manifest: null),
          isFalse);
    });
  });

  group('shouldShowUpdateBanner', () {
    test('shows when nothing has been dismissed', () {
      expect(
        shouldShowUpdateBanner(
          current: const AppVersion(3, 15, 0),
          manifest: manifestFor('3.16.0'),
        ),
        isTrue,
      );
    });

    test('stays quiet about the version that was waved away', () {
      expect(
        shouldShowUpdateBanner(
          current: const AppVersion(3, 15, 0),
          manifest: manifestFor('3.16.0'),
          dismissedVersion: '3.16.0',
        ),
        isFalse,
      );
    });

    test('comes back for the next version after a dismissal', () {
      // A notice that stays silenced forever is a bug nobody reports.
      expect(
        shouldShowUpdateBanner(
          current: const AppVersion(3, 15, 0),
          manifest: manifestFor('3.17.0'),
          dismissedVersion: '3.16.0',
        ),
        isTrue,
      );
    });

    test('a dismissal also covers anything older it might roll back to', () {
      expect(
        shouldShowUpdateBanner(
          current: const AppVersion(3, 15, 0),
          manifest: manifestFor('3.16.0'),
          dismissedVersion: '3.17.0',
        ),
        isFalse,
      );
    });

    test('a corrupt dismissal record does not suppress the banner', () {
      expect(
        shouldShowUpdateBanner(
          current: const AppVersion(3, 15, 0),
          manifest: manifestFor('3.16.0'),
          dismissedVersion: 'garbage',
        ),
        isTrue,
      );
    });
  });

  group('the manifest the release actually publishes', () {
    test('is one this parser accepts', () {
      // Byte for byte the shape `tool/build_downloads_site.py` writes. The two
      // are generated and parsed by different languages in different repos'
      // worth of tooling, so the contract between them is pinned on both
      // sides: `tool/test_build_downloads_site.py` asserts the shape going
      // out, and this asserts it coming in.
      const published = '''
{
  "version": "3.16.0",
  "downloadUrl": "https://downloads.uractor.com/",
  "published": "2026-08-21",
  "assets": {
    "macos": "https://github.com/larabail/UrActorAPP/releases/download/v3.16.0/UrActor-3.16.0-macos.dmg",
    "windows": "https://github.com/larabail/UrActorAPP/releases/download/v3.16.0/UrActor-3.16.0-windows-setup.exe"
  },
  "notes": "Desktop builds for macOS and Windows."
}
''';

      final manifest = UpdateManifest.tryParse(published);

      expect(manifest, isNotNull);
      expect(manifest!.version, const AppVersion(3, 16, 0));
      expect(manifest.downloadUrl, 'https://downloads.uractor.com/');
      expect(manifest.notes, 'Desktop builds for macOS and Windows.');
    });

    test('unknown fields are ignored rather than refused', () {
      // The manifest will grow fields the running app has never heard of --
      // an older install must keep working when it does.
      final manifest = UpdateManifest.tryParse(
        '{"version":"3.16.0","downloadUrl":"https://downloads.uractor.com/",'
        '"somethingAddedLater":{"nested":true}}',
      );

      expect(manifest?.version, const AppVersion(3, 16, 0));
    });
  });
}
