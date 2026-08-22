import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/auth_session.dart';
import 'package:uractor/common/firebase/friends_service.dart';
import 'package:uractor/common/media_sort_loader.dart';

import 'support/harness.dart';

void main() {
  group('AuthSession.signOut', () {
    late FakeFirebaseFirestore firestore;
    late HttpStub http;
    var signOutCalls = 0;

    setUp(() {
      signOutCalls = 0;
      installTestUser(uid: 'signed-in-user');
      firestore = installFakeFirestore();
      http = installHttpStub();
      AuthSession.setAuthSignOutForTest(() async {
        signOutCalls++;
      });
      addTearDown(AuthSession.resetForTest);
    });

    test('clears cached friend profiles so the next account sees fresh data',
        () async {
      await firestore.collection('friend-a').doc('Settings').set({
        'username': 'Alice from first account',
        'profile_photo': 'alice-old.png',
      });
      await FriendsService.loadProfiles(['friend-a']);
      await firestore.collection('friend-a').doc('Settings').set({
        'username': 'Alice for next account',
        'profile_photo': 'alice-new.png',
      });

      await AuthSession.signOut();
      final profiles = await FriendsService.loadProfiles(['friend-a']);

      // Friend rows are cached across screens, but they must not survive an
      // auth boundary where a different user may have different visibility.
      expect(signOutCalls, 1);
      expect(profiles.single.userName, 'Alice for next account');
      expect(profiles.single.profilePhoto, 'alice-new.png');
    });

    test('clears cached media metadata so ratings from the next account load',
        () async {
      http.on('/movie/1', json: {
        'title': 'First title',
        'release_date': '2020-01-01',
        'imdb_id': 'tt0000001',
      });
      final items = [
        ['Movies', '1']
      ];
      await MediaSortLoader.load(items);

      http.on('/movie/1', json: {
        'title': 'Second title',
        'release_date': '2021-01-01',
        'imdb_id': 'tt0000002',
      });
      await AuthSession.signOut();
      final metadata = await MediaSortLoader.load(items);

      // Media metadata includes the signed-in user's own rating, so keeping it
      // after sign-out can show account A's data while account B is active.
      expect(signOutCalls, 1);
      expect(metadata['Movies:1']!.title, 'Second title');
      expect(http.countFor('/movie/1'), 2);
    });

    test('deletes the cache the previous account left on disk', () async {
      final store = installMemoryMetadataStore();
      http.on('/movie/1', json: {'title': 'Account A title'});
      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();
      expect(store.files, contains('signed-in-user'));

      await AuthSession.signOut();

      // Clearing only the copy in memory would leave the file to be read back
      // on the next start, which is the leak this whole cache could have
      // reintroduced.
      expect(store.files, isNot(contains('signed-in-user')));
    });

    test('leaves the next account nothing of the previous one to read',
        () async {
      final store = installMemoryMetadataStore();
      http.on('/movie/1', json: {'title': 'Account A title'});
      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();

      await AuthSession.signOut();
      installTestUser(uid: 'second-account');
      http.on('/movie/1', json: {'title': 'Account B title'});
      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();

      expect(metadata['Movies:1']!.title, 'Account B title');
      expect(store.files, isNot(contains('signed-in-user')));
      expect(store.files.keys, ['second-account']);
    });

    test('keeps each account\'s cache in its own file, so one cannot be read '
        'as the other', () async {
      final store = installMemoryMetadataStore();
      http.on('/movie/1', json: {'title': 'Account A title'});
      await MediaSortLoader.load([
        ['Movies', '1'],
      ]);
      await MediaSortLoader.flushPending();
      final String accountAFile = store.files['signed-in-user']!;

      await AuthSession.signOut();
      // Put account A's file back, standing in for a delete that never
      // happened: the process was killed, or the write failed. Naming the file
      // after the account means B still cannot read it.
      store.files['signed-in-user'] = accountAFile;
      installTestUser(uid: 'second-account');
      http.on('/movie/1', json: {'title': 'Account B title'});

      final metadata = await MediaSortLoader.load([
        ['Movies', '1'],
      ]);

      expect(metadata['Movies:1']!.title, 'Account B title');
    });
  });
}
