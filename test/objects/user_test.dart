/// Tests for `AppUser.getFirebaseData`, which turns the user's Firestore
/// documents into the in-memory state the whole app reads.
///
/// It is a long chain of per-document parsing with no error handling, so a
/// change to one branch can quietly break another. These tests pin the shape
/// each branch produces.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/objects/user.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;

  setUp(() {
    user = installTestUser();
    firestore = installFakeFirestore();
    app.oscars = {};
  });

  group('getFirebaseData', () {
    test('loads the country', () async {
      await seedCompleteUser(firestore, user.uid);

      await user.getFirebaseData();

      expect(user.country, 'US');
    });

    test('splits favorites into movies and shows', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Favorites': {
          'Movies': ['27205'],
          'TVShows': ['1399', '1400'],
        }
      });

      await user.getFirebaseData();

      expect(user.favMovies, [
        ['Movies', '27205']
      ]);
      expect(user.favTVShows, [
        ['TVShows', '1399'],
        ['TVShows', '1400'],
      ]);
    });

    test('loads the watchlist into separate lists per type', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Watchlist': {
          'Movies': ['27205'],
          'TVShows': ['1399'],
        }
      });

      await user.getFirebaseData();

      expect(user.watchlist, [
        ['Movies', '27205']
      ]);
      expect(user.watchlistTVShows, [
        ['TVShows', '1399']
      ]);
    });

    test('loads seen movies and shows', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Movies': {
          'Movies': ['27205', '550']
        },
        'TVShows': {
          'TVShows': ['1399']
        },
      });

      await user.getFirebaseData();

      expect(user.seenMovies, hasLength(2));
      expect(user.seenTVShows, [
        ['TVShows', '1399']
      ]);
    });

    test('orders favourite actors by how often they appear', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'FavActors': {'Actor A': 2, 'Actor B': 9, 'Actor C': 5},
      });

      await user.getFirebaseData();

      expect(user.favActors.map((entry) => entry[1]),
          ['Actor B', 'Actor C', 'Actor A']);
      expect(user.favActors.first[0], 9);
    });

    test('inverts seen-with from title to friend', () async {
      // Firestore stores which friends saw each title; the app needs which
      // titles it shares with each friend, so the map is turned inside out.
      await seedCompleteUser(firestore, user.uid, overrides: {
        'SeenWith': {
          'Movies': {
            '27205': {
              'friends': ['friend-a', 'friend-b']
            },
            '550': {
              'friends': ['friend-a']
            },
          },
          'TVShows': {
            '1399': {
              'friends': ['friend-b']
            },
          },
        }
      });

      await user.getFirebaseData();

      expect(user.seenWith['friend-a']['Movies'], ['27205', '550']);
      expect(user.seenWith['friend-a']['TVShows'], isEmpty);
      expect(user.seenWith['friend-b']['Movies'], ['27205']);
      expect(user.seenWith['friend-b']['TVShows'], ['1399']);
    });

    test('loads settings and the calendar prompt preference', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Settings': {'language': 'es', 'dontAskCalendar': true},
      });

      await user.getFirebaseData();

      expect(user.settings['language'], 'es');
      expect(user.dontAskCalendar, isTrue);
    });

    test('loads reviews keyed by title id', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Reviews': {
          'Movies': [
            {
              '27205': {'Opinion': 'Great', 'Rating': '9'}
            }
          ],
          'TVShows': [
            {
              '1399': {'Opinion': 'Good', 'Rating': '8'}
            }
          ],
        }
      });

      await user.getFirebaseData();

      expect(user.reviews['27205']['Rating'], '9');
      expect(user.tvShowReviews['1399']['Opinion'], 'Good');
      expect(user.allReviews, hasLength(2));
    });

    test('loads the friends list', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Friends': {
          'friends': ['friend-a', 'friend-b']
        },
      });

      await user.getFirebaseData();

      expect(user.friends, ['friend-a', 'friend-b']);
    });

    test('loads rewatch counts', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Rewatched': {'27205': 3},
        'RewatchedTV': {'1399': 2},
      });

      await user.getFirebaseData();

      expect(user.rewatchedMovies['27205'], 3);
      expect(user.rewatchedTVShows['1399'], 2);
    });

    test('loads watch progress', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Progress': {
          'Movies': {
            '27205': {
              'started': '2026-01-01',
              'finished': null,
              'updated': '2026-01-01',
            }
          },
          'TVShows': {
            '1399': {
              'started': '2026-01-02',
              'finished': null,
              'updated': '2026-01-02',
              'episodes': {
                '1': [1]
              },
            }
          },
        },
      });

      await user.getFirebaseData();

      expect(user.progress['Movies']['27205']['started'], '2026-01-01');
      expect(user.progress['TVShows']['1399']['episodes']['1'], [1]);
    });

    test('picks up only the playlists the user belongs to', () async {
      await seedCompleteUser(firestore, user.uid);
      await firestore.collection('Watchlists').doc('mine').set({
        'Name': 'Mine',
        'Users': [
          {user.uid: 'owner'}
        ],
        'memberUids': [user.uid],
      });
      await firestore.collection('Watchlists').doc('someone-elses').set({
        'Name': 'Theirs',
        'Users': [
          {'other-uid': 'owner'}
        ],
        'memberUids': ['other-uid'],
      });

      await user.getFirebaseData();

      expect(user.playlists.keys, ['mine']);
      expect(user.playlists['mine']['id'], 'mine',
          reason: 'the document id is needed to write back to the playlist');
    });

    test('cannot see a playlist that has no memberUids yet', () async {
      // The reason tool/backfill_playlist_members.py exists, pinned so the
      // consequence of skipping it is visible here rather than as a user
      // reporting that their lists vanished.
      //
      // Membership lives in `Users`, a list of {uid: role} maps, which
      // Firestore cannot query: arrayContains matches a whole element and the
      // role is part of it. `memberUids` is the flat projection that makes the
      // query possible, so a document without it is invisible to this query no
      // matter who is in `Users`. syncPlaylistMembers fills it in on every
      // write; documents nobody has written since it was deployed need the
      // backfill.
      await seedCompleteUser(firestore, user.uid);
      await firestore.collection('Watchlists').doc('legacy').set({
        'Name': 'Written before memberUids existed',
        'Users': [
          {user.uid: 'owner'}
        ],
      });

      await user.getFirebaseData();

      expect(user.playlists.keys, isEmpty);
    });

    test('loads oscars keyed by tmdb id', () async {
      await seedCompleteUser(firestore, user.uid);
      await firestore
          .collection('Oscars')
          .doc('any')
          .set({'tmdb_id': 27205, 'category': 'Best Picture'});

      await user.getFirebaseData();

      expect(app.oscars['27205']['category'], 'Best Picture');
    });

    test('clears previous data so a reload cannot double up', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Movies': {
          'Movies': ['27205']
        },
      });

      await user.getFirebaseData();
      await user.getFirebaseData();

      expect(user.seenMovies, hasLength(1));
      expect(user.favActors, isEmpty);
    });
  });

  group('clearUserData', () {
    test('empties the loaded state but keeps the identity', () async {
      await seedCompleteUser(firestore, user.uid, overrides: {
        'Movies': {
          'Movies': ['27205']
        },
        'Friends': {
          'friends': ['friend-a']
        },
      });
      await user.getFirebaseData();

      user.clearUserData();

      expect(user.seenMovies, isEmpty);
      expect(user.friends, isEmpty);
      expect(user.settings, isEmpty);
      expect(user.uid, 'test-uid',
          reason: 'signing out is a separate step from clearing loaded data');
    });
  });

  group('clearUser', () {
    test('drops the identity', () {
      user.clearUser();

      expect(user.uid, '');
    });
  });
}
