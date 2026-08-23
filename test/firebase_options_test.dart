/// Tests for which Firebase registration each platform is given.
///
/// A desktop build cannot prove who it is. It sends no HTTP referrer, no
/// Android package name and signing certificate, and no iOS bundle
/// identifier, so an API key restricted by any of those three refuses it with
/// 403 before a password is ever looked at. Every account then fails, on every
/// attempt, with a correct password.
///
/// Both desktop platforms had been given exactly that. Windows borrowed the
/// web key and was refused with `API_KEY_HTTP_REFERRER_BLOCKED`; macOS
/// borrowed the iOS key and was refused with `API_KEY_IOS_APP_BLOCKED`. The
/// failure is invisible from inside the app on Windows, where the C++ SDK
/// reports it as a bare `unknown-error` reading "An internal error has
/// occurred." and discards the reason token that names the cause — so nothing
/// at runtime will catch a regression here. These tests are the guard.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions', () {
    test('no desktop platform borrows an application-restricted key', () {
      final restricted = <String, String>{
        'web (restricted by HTTP referrer)': DefaultFirebaseOptions.web.apiKey,
        'android (restricted by package and certificate)':
            DefaultFirebaseOptions.android.apiKey,
        'ios (restricted by bundle identifier)':
            DefaultFirebaseOptions.ios.apiKey,
      };

      for (final entry in restricted.entries) {
        expect(
          DefaultFirebaseOptions.windows.apiKey,
          isNot(entry.value),
          reason: 'Windows cannot use the ${entry.key} key',
        );
        expect(
          DefaultFirebaseOptions.macos.apiKey,
          isNot(entry.value),
          reason: 'macOS cannot use the ${entry.key} key',
        );
      }
    });

    test('the two desktop platforms share one key', () {
      // They are refused by the same rule and satisfied by the same exemption,
      // so a second unrestricted key would be a second thing to rotate for no
      // gain — and a second chance to fix one platform and forget the other.
      expect(
        DefaultFirebaseOptions.windows.apiKey,
        DefaultFirebaseOptions.macos.apiKey,
      );
    });

    test('Windows is given the windows entry, not the web one', () {
      // The switch used to fall through to `web`, which is how Windows came to
      // hold a referrer-restricted key. Asserting the key rather than identity
      // keeps this honest if the entry is ever rebuilt by `flutterfire
      // configure`.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        DefaultFirebaseOptions.currentPlatform.apiKey,
        DefaultFirebaseOptions.windows.apiKey,
      );
    });

    test('macOS is given the macos entry', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        DefaultFirebaseOptions.currentPlatform.apiKey,
        DefaultFirebaseOptions.macos.apiKey,
      );
    });

    test('every platform still addresses the one project', () {
      // Giving desktop its own key must not turn into giving it its own
      // project: the account, lists and friends all have to be the same ones
      // the phone sees.
      for (final options in <FirebaseOptions>[
        DefaultFirebaseOptions.web,
        DefaultFirebaseOptions.android,
        DefaultFirebaseOptions.ios,
        DefaultFirebaseOptions.macos,
        DefaultFirebaseOptions.windows,
      ]) {
        expect(options.projectId, 'actordb-cf981');
        expect(options.storageBucket, 'actordb-cf981.appspot.com');
        expect(options.messagingSenderId, '805906181872');
      }
    });

    test('Linux says why it is unsupported rather than failing later', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsUnsupportedError,
      );
    });
  });
}
