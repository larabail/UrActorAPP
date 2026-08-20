import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/settings_service.dart';

import 'support/harness.dart';

void main() {
  group('SettingsService.update', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      installTestUser(
        uid: 'settings-user',
        settings: {'language': 'en'},
      );
      firestore = installFakeFirestore();
    });

    test('merges one changed setting without deleting fields not in memory',
        () async {
      await firestore.collection('settings-user').doc('Settings').set({
        'language': 'en',
        'username': 'Existing Name',
        'profile_photo': 'old.png',
      });

      await SettingsService.update('language', 'es');

      final snapshot =
          await firestore.collection('settings-user').doc('Settings').get();
      final data = snapshot.data() as Map<String, dynamic>;
      // The settings screen only has a partial in-memory map, so writes must
      // patch the changed field instead of replacing the whole document.
      expect(data['language'], 'es');
      expect(data['username'], 'Existing Name');
      expect(data['profile_photo'], 'old.png');
    });

    test('creates the Settings document when a new setting is first saved',
        () async {
      final doc = firestore.collection('settings-user').doc('Settings');
      expect((await doc.get()).exists, isFalse);

      await SettingsService.update('dontAskCalendar', true);

      expect((await doc.get()).data(), {'dontAskCalendar': true});
    });
  });
}
