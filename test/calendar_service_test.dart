import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/calendar_service.dart';

import 'support/harness.dart';

void main() {
  group('CalendarService.removeCurrentUserFromFriendsSeenWith', () {
    test(
      'removes only the current user from friends reciprocal seen-with lists',
      () async {
        final firestore = installFakeFirestore();
        installTestUser(uid: 'me');

        await seedUserDoc(firestore, 'friend-a', 'SeenWith', {
          'Movies': {
            'movie-1': {
              'friends': ['me', 'friend-b', 'friend-c'],
            },
            'movie-2': {
              'friends': ['me'],
            },
          },
          'TVShows': {
            'movie-1': {
              'friends': ['me'],
            },
          },
        });
        await seedUserDoc(firestore, 'friend-b', 'SeenWith', {
          'Movies': {
            'movie-1': {
              'friends': ['friend-a', 'me'],
            },
          },
        });

        await CalendarService.removeCurrentUserFromFriendsSeenWith(
          'movie-1',
          'Movies',
          ['friend-a', 'friend-b'],
        );

        final friendA =
            (await firestore.collection('friend-a').doc('SeenWith').get())
                .data()!;
        final friendB =
            (await firestore.collection('friend-b').doc('SeenWith').get())
                .data()!;

        // A just-me calendar delete should only retract my participation from
        // the matching shared viewing, not erase the friend's own history or the
        // other people they watched it with.
        expect(
          friendA['Movies']['movie-1']['friends'],
          equals(['friend-b', 'friend-c']),
        );
        expect(friendB['Movies']['movie-1']['friends'], equals(['friend-a']));
        expect(friendA['Movies']['movie-2']['friends'], equals(['me']));
        expect(friendA['TVShows']['movie-1']['friends'], equals(['me']));
      },
    );

    test('skips missing and malformed reciprocal seen-with records', () async {
      final firestore = installFakeFirestore();
      installTestUser(uid: 'me');

      await seedUserDoc(firestore, 'friend-b', 'SeenWith', {
        'Movies': {
          'movie-1': {'friends': 'not-a-list'},
          'movie-2': 'not-a-map',
        },
        'TVShows': [],
      });

      await CalendarService.removeCurrentUserFromFriendsSeenWith(
        'movie-1',
        'Movies',
        ['friend-a', 'friend-b'],
      );

      final missingSnapshot = await firestore
          .collection('friend-a')
          .doc('SeenWith')
          .get();
      final malformedData =
          (await firestore.collection('friend-b').doc('SeenWith').get())
              .data()!;

      // Old data can be absent or corrupt because friends may delete entries
      // independently. The cleanup must be best-effort instead of failing the
      // user's calendar delete.
      expect(missingSnapshot.exists, isFalse);
      expect(
        malformedData['Movies']['movie-1']['friends'],
        equals('not-a-list'),
      );
      expect(malformedData['Movies']['movie-2'], equals('not-a-map'));
      expect(malformedData['TVShows'], isEmpty);
    });
  });
}
