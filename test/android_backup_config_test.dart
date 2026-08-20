import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firebase Auth keeps the signed-in session in shared preferences, encrypted
/// with a key that never leaves the device's Keystore. If those preferences are
/// carried into a restored or transferred install the session cannot be
/// decrypted, and the user is signed out on every cold start
/// (firebase-android-sdk#8392). These tests pin the manifest wiring that keeps
/// that state device-local, because losing it is silent: the app still builds
/// and only some users, on some devices, are affected.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final backupRules =
      File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync();
  final extractionRules =
      File('android/app/src/main/res/xml/data_extraction_rules.xml')
          .readAsStringSync();

  test('the manifest points at both sets of backup rules', () {
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('shared preferences are kept out of backups on Android 11 and below',
      () {
    expect(backupRules, contains('<full-backup-content>'));
    expect(backupRules, contains('<exclude domain="sharedpref" path="." />'));
  });

  test('shared preferences are kept out of both Android 12 extraction paths',
      () {
    for (final section in ['cloud-backup', 'device-transfer']) {
      final start = extractionRules.indexOf('<$section>');
      final end = extractionRules.indexOf('</$section>');
      expect(start, isNonNegative, reason: '$section section is missing');
      expect(
        extractionRules.substring(start, end),
        contains('<exclude domain="sharedpref" path="." />'),
        reason: '$section does not exclude shared preferences',
      );
    }
  });
}
