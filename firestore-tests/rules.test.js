'use strict';

const { readFileSync } = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
} = require('firebase/firestore');

let testEnv;

// Uids used throughout. Names double as their uid for readability.
const ALICE = 'alice';
const BOB = 'bob';
const CAROL = 'carol';
const DAVE = 'dave';

before(async function () {
  this.timeout(60000);
  testEnv = await initializeTestEnvironment({
    projectId: 'uractor-rules-test',
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// Seeds data bypassing security rules entirely.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

function ctxFor(uid) {
  return uid ? testEnv.authenticatedContext(uid) : testEnv.unauthenticatedContext();
}

describe('A. Unauthenticated access', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Settings`), { username: 'alice' });
      await setDoc(doc(db, 'Oscars/2024'), { winner: 'x' });
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
      await setDoc(doc(db, 'usernames/u1'), { username: 'alice', uid: ALICE });
    });
  });

  it('cannot read a stranger\'s Settings document (public profile) while unauthenticated', async () => {
    const anon = ctxFor(null);
    await assertFails(getDoc(doc(anon.firestore(), `${ALICE}/Settings`)));
  });

  it('cannot read Oscars while unauthenticated', async () => {
    const anon = ctxFor(null);
    await assertFails(getDoc(doc(anon.firestore(), 'Oscars/2024')));
  });

  it('cannot read Watchlists while unauthenticated', async () => {
    const anon = ctxFor(null);
    await assertFails(getDoc(doc(anon.firestore(), 'Watchlists/list1')));
  });

  it('cannot read or write any user document while unauthenticated', async () => {
    const db = ctxFor(null).firestore();
    await assertFails(getDoc(doc(db, `${ALICE}/Calendar`)));
    await assertFails(setDoc(doc(db, `${ALICE}/Calendar`), { entries: [] }));
  });

  it('cannot read usernames while unauthenticated', async () => {
    const anon = ctxFor(null);
    await assertFails(getDoc(doc(anon.firestore(), 'usernames/u1')));
  });
});

describe('B. Own data', () => {
  it('lets a user create, read, update and delete every document in their own collection', async () => {
    const alice = ctxFor(ALICE).firestore();
    const docs = ['Country', 'Calendar', 'FavActors', 'FavDirectors', 'FavWriters', 'Favorites',
      'Movies', 'TVShows', 'Watchlist', 'Seen', 'SeenWith', 'Settings', 'Reviews', 'Rewatched',
      'RewatchedTV', 'Notifications', 'Recommendations'];
    for (const docId of docs) {
      const ref = doc(alice, `${ALICE}/${docId}`);
      await assertSucceeds(setDoc(ref, { seed: true }));
      await assertSucceeds(getDoc(ref));
      await assertSucceeds(updateDoc(ref, { seed: false }));
      await assertSucceeds(deleteDoc(ref));
    }
  });

  it('lets a user list their own whole collection', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Movies`), {});
      await setDoc(doc(db, `${ALICE}/Calendar`), {});
    });
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(getDocs(collection(alice, ALICE)));
  });
});

describe('C. Settings as public profile', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Settings`), { username: 'alice' });
      await setDoc(doc(db, `${ALICE}/Calendar`), { entries: [] });
      await setDoc(doc(db, `${ALICE}/Movies`), {});
      await setDoc(doc(db, `${ALICE}/Reviews`), {});
    });
  });

  it('lets a total stranger get another user\'s Settings document', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(getDoc(doc(carol, `${ALICE}/Settings`)));
  });

  it('does not let a stranger get another user\'s Calendar, Movies or Reviews document', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(getDoc(doc(carol, `${ALICE}/Calendar`)));
    await assertFails(getDoc(doc(carol, `${ALICE}/Movies`)));
    await assertFails(getDoc(doc(carol, `${ALICE}/Reviews`)));
  });

  it('does not let a stranger list a stranger\'s whole collection', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(getDocs(collection(carol, ALICE)));
  });
});

describe('D. Friends', () => {
  const movieEntry = { id: 'm1', title: 'Movie', runtime: 90, rating: 7.5, friends: [BOB], type: 'movie' };
  const notification0 = {
    type: 'movie', id: 'm0', title: 'Old', coverPhoto: '/old.jpg',
    sender: { username: 'bob', uid: BOB }, read: false, timestamp: new Date('2026-01-01T00:00:00Z'),
  };
  const notification1 = {
    type: 'movie', id: 'm1', title: 'New', coverPhoto: '/new.jpg',
    sender: { username: 'bob', uid: BOB }, read: false, timestamp: new Date('2026-01-02T00:00:00Z'),
  };

  beforeEach(async () => {
    await seed(async (db) => {
      // Alice's Friends document contains Bob, so Bob is Alice's friend.
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [BOB] });
      await setDoc(doc(db, `${ALICE}/Calendar`), { '2026-01-01': [movieEntry] });
      await setDoc(doc(db, `${ALICE}/FavActors`), { list: [] });
      await setDoc(doc(db, `${ALICE}/Rewatched`), { m0: 1 });
      await setDoc(doc(db, `${ALICE}/Movies`), { Seen: ['m0'] });
      await setDoc(doc(db, `${ALICE}/TVShows`), { Seen: ['t0'] });
      await setDoc(doc(db, `${ALICE}/Seen`), { Movies: ['m0'], TVShows: ['t0'] });
      await setDoc(doc(db, `${ALICE}/SeenWith`), {
        Movies: { m0: { friends: [ALICE, BOB] } },
        TVShows: { t0: { friends: [ALICE, BOB] } },
      });
      await setDoc(doc(db, `${ALICE}/RewatchedTV`), { t0: 1 });
      await setDoc(doc(db, `${ALICE}/Notifications`), { 0: notification0 });
      await setDoc(doc(db, `${ALICE}/Reviews`), {});
      await setDoc(doc(db, `${ALICE}/Favorites`), {});
      await setDoc(doc(db, `${ALICE}/Watchlist`), {});
      await setDoc(doc(db, `${ALICE}/Settings`), { username: 'alice' });
      await setDoc(doc(db, `${ALICE}/Country`), {});
      await setDoc(doc(db, `${ALICE}/Recommendations`), {});
    });
  });

  it('lets a friend get Calendar, FavActors and Rewatched documents', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(getDoc(doc(bob, `${ALICE}/Calendar`)));
    await assertSucceeds(getDoc(doc(bob, `${ALICE}/FavActors`)));
    await assertSucceeds(getDoc(doc(bob, `${ALICE}/Rewatched`)));
  });

  it('lets a friend list the whole collection', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(getDocs(collection(bob, ALICE)));
  });

  it('lets a friend make the current installed-client writes to the eight friend-writable documents', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: ['m0', 'm1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/TVShows`), { Seen: ['t0', 't1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Seen`), { Movies: ['m0', 'm1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/SeenWith`), {
      Movies: {
        m0: { friends: [ALICE, BOB] },
        m1: { friends: [ALICE, BOB] },
      },
    }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [movieEntry],
    }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Rewatched`), { m1: 1 }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/RewatchedTV`), { t1: 1 }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Notifications`), {
      0: notification0,
      1: notification1,
    }));
  });

  it('does not let a friend rewrite watched-list documents beyond the app append shape', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertFails(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: [] }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: ['m0'], hacked: true }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Seen`), {
      Movies: ['m0', 'm1'],
      TVShows: ['t0', 't1'],
    }, { merge: true }));
  });

  it('does not let a friend rewrite SeenWith, Calendar or rewatch documents wholesale', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertFails(setDoc(doc(bob, `${ALICE}/SeenWith`), {
      Movies: {
        m0: { friends: [BOB] },
        m1: { friends: [BOB] },
      },
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [movieEntry],
      '2026-01-03': [movieEntry],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Rewatched`), { m1: 1, m2: 1 }, { merge: true }));
  });

  it('does not let a friend remove or change existing notifications', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertFails(setDoc(doc(bob, `${ALICE}/Notifications`), { 1: notification1 }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Notifications`), {
      0: { ...notification0, read: true },
      1: notification1,
    }));
  });

  it('does not let a friend update Reviews, Favorites, Watchlist, Settings, Country or Recommendations', async () => {
    const bob = ctxFor(BOB).firestore();
    const notWritable = ['Reviews', 'Favorites', 'Watchlist', 'Settings', 'Country', 'Recommendations'];
    for (const docId of notWritable) {
      await assertFails(updateDoc(doc(bob, `${ALICE}/${docId}`), { touched: true }));
    }
  });

  it('does not let a friend delete a document, or create a document with an arbitrary name', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(deleteDoc(doc(bob, `${ALICE}/Movies`)));
    await assertFails(setDoc(doc(bob, `${ALICE}/NewDoc`), { x: 1 }));
  });

  it('does not let a stranger do any of the friend-only operations', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(getDoc(doc(carol, `${ALICE}/Calendar`)));
    await assertFails(getDocs(collection(carol, ALICE)));
    await assertFails(setDoc(doc(carol, `${ALICE}/Movies`), { Seen: ['m0', 'm1'] }, { merge: true }));
  });

  it('does not grant access to Alice\'s collection when a stranger writes themselves into their OWN Friends document', async () => {
    const carol = ctxFor(CAROL).firestore();
    // Carol tries the privilege-escalation trick: claim she's Alice's friend
    // by writing herself into her OWN Friends doc, which friendOf(uid) never
    // reads (it always reads the TARGET's list).
    await seed(async (db) => {
      await setDoc(doc(db, `${CAROL}/Friends`), { friends: [ALICE] });
    });
    await assertFails(getDoc(doc(carol, `${ALICE}/Calendar`)));
    await assertFails(getDocs(collection(carol, ALICE)));
    await assertFails(setDoc(doc(carol, `${ALICE}/Movies`), { Seen: ['m0', 'm1'] }, { merge: true }));
  });
});

describe('D2. Friend writes lazily create missing per-user documents', () => {
  const movieEntry = { id: 'm1', title: 'Movie', runtime: 90, rating: 7.5, friends: [BOB], type: 'movie' };

  // Regression coverage for a real crash: FirestoreCore.updateDocument uses a
  // merging set(), which performs a CREATE rather than an UPDATE when the
  // document does not exist yet. Friends can still create the documents the app
  // creates lazily, but only with the same one-field shape the app sends.
  beforeEach(async () => {
    await seed(async (db) => {
      // Alice's Friends document contains Bob, so Bob is Alice's friend. None
      // of Alice's other documents are seeded here: that absence is the point.
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [BOB] });
    });
  });

  it('lets a friend create missing friend-writable documents with the app write shape', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: ['m1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/TVShows`), { Seen: ['t1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Seen`), { Movies: ['m1'] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/SeenWith`), {
      Movies: { m1: { friends: [ALICE, BOB] } },
    }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), { '2026-01-02': [movieEntry] }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Rewatched`), { m1: 1 }, { merge: true }));
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/RewatchedTV`), { t1: 1 }, { merge: true }));
  });

  it('does not let a friend create missing documents with oversized or arbitrary payloads', async () => {
    const bob = ctxFor(BOB).firestore();

    await assertFails(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: ['m1', 'm2'] }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Movies`), { Seen: ['m1'], hacked: true }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Seen`), { Movies: ['m1'], TVShows: ['t1'] }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/SeenWith`), {
      Movies: { m1: { friends: [BOB] } },
      TVShows: { t1: { friends: [BOB] } },
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [movieEntry],
      '2026-01-03': [movieEntry],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Rewatched`), { m1: 1, m2: 1 }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Notifications`), { 0: { type: 'movie' } }));
  });

  it('does not let a friend create a Reviews, Favorites, Watchlist, Settings or Country document that does not exist yet', async () => {
    const bob = ctxFor(BOB).firestore();
    const notCreatable = ['Reviews', 'Favorites', 'Watchlist', 'Settings', 'Country'];
    for (const docId of notCreatable) {
      await assertFails(setDoc(doc(bob, `${ALICE}/${docId}`), { touched: true }, { merge: true }));
    }
  });

  it('does not let a friend create a document with an arbitrary name in the target\'s collection', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Hacked`), { touched: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/SomethingElse`), { touched: true }));
  });

  it('still does not let a friend delete any document, missing or not', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(deleteDoc(doc(bob, `${ALICE}/Calendar`)));
  });

  it('does not let a stranger create any of the friend-writable documents, missing or not', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(setDoc(doc(carol, `${ALICE}/Calendar`), { '2026-01-02': [movieEntry] }, { merge: true }));
    await assertFails(setDoc(doc(carol, `${ALICE}/Seen`), { Movies: ['m1'] }, { merge: true }));
    await assertFails(setDoc(doc(carol, `${ALICE}/Notifications`), { 0: { type: 'movie' } }));
    await assertFails(deleteDoc(doc(carol, `${ALICE}/Calendar`)));
  });
});

describe('D2b. Calendar entries may record a season and an episode', () => {
  // The entry shape every installed client already sends. A rules deploy
  // reaches every phone at once with no staged rollout, so this shape has to
  // keep being accepted for as long as those builds are out there -- which is
  // what most of this block exists to prove.
  const oldShapeEntry = {
    id: 't1', title: 'Show', runtime: 50, rating: 8.1, friends: [BOB], type: 'series',
  };
  // The same entry once the user records which part of the show it was. Both
  // fields are optional and only a show entry ever carries them.
  const newShapeEntry = { ...oldShapeEntry, season: 2, episode: 9 };
  // Watching a whole season in a sitting records the season and nothing else.
  const seasonOnlyEntry = { ...oldShapeEntry, season: 2 };

  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [BOB] });
    });
  });

  async function seedCalendar() {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Calendar`), { '2026-01-01': [oldShapeEntry] });
    });
  }

  it('lets a friend create a calendar with the entry shape installed clients send', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [oldShapeEntry],
    }, { merge: true }));
  });

  it('lets a friend add the installed-client entry shape to an existing calendar', async () => {
    await seedCalendar();
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [oldShapeEntry],
    }, { merge: true }));
  });

  it('lets a friend create a calendar with an entry recording a season and episode', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [newShapeEntry],
    }, { merge: true }));
  });

  it('lets a friend add an entry recording a season and episode to an existing calendar', async () => {
    await seedCalendar();
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [newShapeEntry],
    }, { merge: true }));
  });

  it('lets a friend record a season with no episode', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [seasonOnlyEntry],
    }, { merge: true }));
  });

  it('does not let a friend create an entry whose season is not a part number', async () => {
    const bob = ctxFor(BOB).firestore();
    // Season 0 is TMDB's specials bucket, which nothing in the app tracks.
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: 0 }],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: -1 }],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: '2' }],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: { n: 2 } }],
    }, { merge: true }));
  });

  it('does not let a friend create an entry whose episode is not a part number', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: 2, episode: 0 }],
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, season: 2, episode: 'nine' }],
    }, { merge: true }));
  });

  it('does not let a friend create an entry recording an episode with no season', async () => {
    // The client drops one, because "E9" of an unnamed season is not something
    // any screen can show.
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [{ ...oldShapeEntry, episode: 9 }],
    }, { merge: true }));
  });

  it('does not let a friend put anything but a list of entries on a day', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': 'hacked',
    }, { merge: true }));
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': { hacked: true },
    }, { merge: true }));
  });

  it('still refuses a friend touching two days at once, in either entry shape', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [newShapeEntry],
      '2026-01-03': [newShapeEntry],
    }, { merge: true }));

    await seedCalendar();
    await assertFails(setDoc(doc(bob, `${ALICE}/Calendar`), {
      '2026-01-02': [newShapeEntry],
      '2026-01-03': [oldShapeEntry],
    }, { merge: true }));
  });

  it('lets the owner write their own calendar wholesale, in either entry shape', async () => {
    // Owner writes never went through the friend validators and must not start
    // now: the app rewrites the whole document when an entry is deleted.
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, `${ALICE}/Calendar`), {
      '2026-01-01': [oldShapeEntry],
      '2026-01-02': [newShapeEntry, seasonOnlyEntry],
    }));
  });
});

describe('D3. Progress is owner-only', () => {
  const progress = {
    Movies: { m1: { started: '2026-01-01', finished: null, updated: '2026-01-01' } },
    TVShows: { s1: { started: '2026-01-02', finished: null, updated: '2026-01-02', episodes: { 1: [1, 2] } } },
  };

  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [BOB] });
      await setDoc(doc(db, `${ALICE}/Progress`), progress);
    });
  });

  it('lets the owner write their own Progress document', async () => {
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, `${ALICE}/Progress`), progress, { merge: true }));
  });

  it('does not let a friend read or write Progress', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(getDoc(doc(bob, `${ALICE}/Progress`)));
    await assertFails(setDoc(doc(bob, `${ALICE}/Progress`), progress, { merge: true }));
  });

  it('does not let a stranger read or write Progress', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(getDoc(doc(carol, `${ALICE}/Progress`)));
    await assertFails(setDoc(doc(carol, `${ALICE}/Progress`), progress, { merge: true }));
  });

  it('does not let a friend create a missing Progress document', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${DAVE}/Friends`), { friends: [BOB] });
    });
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${DAVE}/Progress`), progress, { merge: true }));
  });
});

describe('E. The Friends document self-toggle rule', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [CAROL] });
    });
  });

  it('lets a user add their own uid to another user\'s friends array', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(updateDoc(doc(bob, `${ALICE}/Friends`), { friends: [CAROL, BOB] }));
  });

  it('lets a user remove their own uid from another user\'s friends array', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(updateDoc(doc(carol, `${ALICE}/Friends`), { friends: [] }));
  });

  it('does not let a user add a third party\'s uid to another user\'s friends array', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(updateDoc(doc(bob, `${ALICE}/Friends`), { friends: [CAROL, DAVE] }));
  });

  it('does not let a user remove a third party from another user\'s friends array', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [CAROL, DAVE] });
    });
    const bob = ctxFor(BOB).firestore();
    await assertFails(updateDoc(doc(bob, `${ALICE}/Friends`), { friends: [CAROL] }));
  });

  it('does not let a user clear or replace the whole friends array', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends`), { friends: [CAROL, DAVE] });
    });
    const bob = ctxFor(BOB).firestore();
    await assertFails(updateDoc(doc(bob, `${ALICE}/Friends`), { friends: [BOB] }));
  });

  it('does not let a user change any other field while toggling themselves', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(updateDoc(doc(bob, `${ALICE}/Friends`), { friends: [CAROL, BOB], note: 'hacked' }));
  });
});

describe('E2. Accepting the first friend request someone ever receives (Friends document does not exist yet)', () => {
  // If Alice has never had a Friends document, Bob accepting a request from
  // her (or her accepting his) performs a CREATE on Alice's Friends document
  // rather than an update, so onlyTogglesSelfInFriends() (which diffs against
  // resource.data) cannot run: there is no resource.data yet. This exercises
  // createsOnlySelfInFriends() instead.
  it('lets a user create another user\'s missing Friends document containing only their own uid', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, `${ALICE}/Friends`), { friends: [BOB] }));
  });

  it('does not let a user create another user\'s missing Friends document containing a third party\'s uid', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Friends`), { friends: [DAVE] }));
  });

  it('does not let a user create another user\'s missing Friends document with an empty friends array', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Friends`), { friends: [] }));
  });

  it('does not let a user create another user\'s missing Friends document with themselves plus a third party', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Friends`), { friends: [BOB, DAVE] }));
  });

  it('does not let a user create another user\'s missing Friends document with an extra field', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `${ALICE}/Friends`), { friends: [BOB], note: 'hacked' }));
  });

  it('does not let an unauthenticated client create a Friends document at all', async () => {
    const anon = ctxFor(null).firestore();
    await assertFails(setDoc(doc(anon, `${ALICE}/Friends`), { friends: [BOB] }));
  });
});

describe('F. Friend requests subcollection', () => {
  it('lets a stranger create a request at the target\'s path with their own uid as the document id', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(
      setDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${CAROL}`), { senderUID: CAROL, status: 'pending' })
    );
  });

  it('does not let a stranger create a request whose document id is someone else\'s uid', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(
      setDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${DAVE}`), { senderUID: CAROL, status: 'pending' })
    );
  });

  it('does not let a stranger create a request whose senderUID does not match their own uid', async () => {
    const carol = ctxFor(CAROL).firestore();
    await assertFails(
      setDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${CAROL}`), { senderUID: DAVE, status: 'pending' })
    );
  });

  it('lets the recipient read and update (accept/reject) a request', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends/FriendRequests/${CAROL}`), { senderUID: CAROL, status: 'pending' });
    });
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(getDoc(doc(alice, `${ALICE}/Friends/FriendRequests/${CAROL}`)));
    await assertSucceeds(updateDoc(doc(alice, `${ALICE}/Friends/FriendRequests/${CAROL}`), { status: 'accepted' }));
  });

  it('lets the sender read and delete their own request, but not update it', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends/FriendRequests/${CAROL}`), { senderUID: CAROL, status: 'pending' });
    });
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(getDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${CAROL}`)));
    await assertFails(updateDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${CAROL}`), { status: 'accepted' }));
    await assertSucceeds(deleteDoc(doc(carol, `${ALICE}/Friends/FriendRequests/${CAROL}`)));
  });

  it('does not let an unrelated third party read the request', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `${ALICE}/Friends/FriendRequests/${CAROL}`), { senderUID: CAROL, status: 'pending' });
    });
    const dave = ctxFor(DAVE).firestore();
    await assertFails(getDoc(doc(dave, `${ALICE}/Friends/FriendRequests/${CAROL}`)));
  });
});

describe('G. usernames collection', () => {
  it('lets any signed-in user read/query it', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'usernames/u1'), { username: 'alice', uid: ALICE });
    });
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(getDoc(doc(bob, 'usernames/u1')));
    await assertSucceeds(getDocs(collection(bob, 'usernames')));
  });

  it('lets a user create a document with their own uid', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(setDoc(doc(bob, 'usernames/bobname'), { username: 'bob', uid: BOB }));
  });

  it('does not let a user create a document with someone else\'s uid (impersonation guard)', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, 'usernames/bobname'), { username: 'bob', uid: ALICE }));
  });

  it('does not let a user create a document with extra fields beyond username and uid', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, 'usernames/bobname'), { username: 'bob', uid: BOB, extra: true }));
  });

  it('lets a user delete or update only their own entry', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'usernames/aliceEntry'), { username: 'alice', uid: ALICE });
      await setDoc(doc(db, 'usernames/bobEntry'), { username: 'bob', uid: BOB });
    });
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(updateDoc(doc(bob, 'usernames/bobEntry'), { username: 'bobby' }));
    await assertSucceeds(deleteDoc(doc(bob, 'usernames/bobEntry')));
  });

  it('does not let a user delete or update someone else\'s entry', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'usernames/aliceEntry'), { username: 'alice', uid: ALICE });
    });
    const bob = ctxFor(BOB).firestore();
    await assertFails(updateDoc(doc(bob, 'usernames/aliceEntry'), { username: 'hacked' }));
    await assertFails(deleteDoc(doc(bob, 'usernames/aliceEntry')));
  });
});

describe('H. Watchlists', () => {
  it('lets any signed-in user read them (documented current behaviour)', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
    });
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(getDoc(doc(carol, 'Watchlists/list1')));
  });

  it('lets a user create a playlist where they are listed as Owner', async () => {
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, 'Watchlists/list1'), {
      Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
      Users: [{ [ALICE]: 'Owner' }],
    }));
  });

  it('does not let a user create a playlist where someone else is the only Owner', async () => {
    const alice = ctxFor(ALICE).firestore();
    await assertFails(setDoc(doc(alice, 'Watchlists/list1'), {
      Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
      Users: [{ [BOB]: 'Owner' }],
    }));
  });

  it('lets an Approved member update the playlist\'s Movies and TV Shows', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }, { [BOB]: 'Approved' }],
      });
    });
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(updateDoc(doc(bob, 'Watchlists/list1'), { Movies: ['tt1'] }));
    await assertSucceeds(updateDoc(doc(bob, 'Watchlists/list1'), { 'TV Shows': ['tv1'] }));
  });

  it('does not let a non-member update a playlist\'s contents', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
    });
    const carol = ctxFor(CAROL).firestore();
    await assertFails(updateDoc(doc(carol, 'Watchlists/list1'), { Movies: ['tt1'] }));
  });

  it('lets a non-member add themselves to Users (joining by access code, documented current behaviour)', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
    });
    const carol = ctxFor(CAROL).firestore();
    await assertSucceeds(updateDoc(doc(carol, 'Watchlists/list1'), {
      Users: [{ [ALICE]: 'Owner' }, { [CAROL]: 'Approved' }],
    }));
  });

  it('does not let a non-member add themselves and change another field at the same time', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
    });
    const carol = ctxFor(CAROL).firestore();
    await assertFails(updateDoc(doc(carol, 'Watchlists/list1'), {
      Users: [{ [ALICE]: 'Owner' }, { [CAROL]: 'Approved' }],
      Name: 'hacked',
    }));
  });

  it('lets an Owner delete the playlist', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }],
      });
    });
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(deleteDoc(doc(alice, 'Watchlists/list1')));
  });

  it('does not let a non-owner member delete the playlist', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Watchlists/list1'), {
        Name: 'n', CoverPhoto: '', Movies: [], 'TV Shows': [], AccessCode: 'abc',
        Users: [{ [ALICE]: 'Owner' }, { [BOB]: 'Approved' }],
      });
    });
    const bob = ctxFor(BOB).firestore();
    await assertFails(deleteDoc(doc(bob, 'Watchlists/list1')));
  });
});

describe('I. Oscars', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Oscars/2024'), { winner: 'x' });
    });
  });

  it('lets any signed-in user read Oscars', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertSucceeds(getDoc(doc(bob, 'Oscars/2024')));
  });

  it('does not let a signed-in user write (create, update or delete) Oscars', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, 'Oscars/2025'), { winner: 'y' }));
    await assertFails(updateDoc(doc(bob, 'Oscars/2024'), { winner: 'z' }));
    await assertFails(deleteDoc(doc(bob, 'Oscars/2024')));
  });
});

describe('J. Cached credits', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'Credits/Movies_550'), { cast: ['287'] });
    });
  });

  it('does not let a signed-in user read cached credits', async () => {
    // Filled and read only by recomputePeopleScores, which uses admin
    // credentials. Nothing in the app reads it, so nothing needs access.
    const bob = ctxFor(BOB).firestore();
    await assertFails(getDoc(doc(bob, 'Credits/Movies_550')));
  });

  it('does not let a signed-in user write cached credits', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, 'Credits/Movies_807'), { cast: ['1'] }));
    await assertFails(updateDoc(doc(bob, 'Credits/Movies_550'), { cast: [] }));
    await assertFails(deleteDoc(doc(bob, 'Credits/Movies_550')));
  });
});

describe('K. People score jobs', () => {
  it('lets a user mark their own scores as needing a recompute', async () => {
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, `PeopleScoreJobs/${ALICE}`), {
      dirty: true, dirtyAt: new Date(),
    }));
    await assertSucceeds(getDoc(doc(alice, `PeopleScoreJobs/${ALICE}`)));
  });

  it('lets a user re-mark an existing job the worker has already run', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, `PeopleScoreJobs/${ALICE}`), {
        dirty: false, dirtyAt: new Date(), lastRunAt: new Date(), lastError: null,
      });
    });
    const alice = ctxFor(ALICE).firestore();
    await assertSucceeds(updateDoc(doc(alice, `PeopleScoreJobs/${ALICE}`), {
      dirty: true, dirtyAt: new Date(),
    }));
  });

  it('does not let a user clear their own job', async () => {
    // Only the worker may say the work is done; otherwise a client could make
    // itself be skipped and never be rescored.
    await seed(async (db) => {
      await setDoc(doc(db, `PeopleScoreJobs/${ALICE}`), {
        dirty: true, dirtyAt: new Date(),
      });
    });
    const alice = ctxFor(ALICE).firestore();
    await assertFails(updateDoc(doc(alice, `PeopleScoreJobs/${ALICE}`), {
      dirty: false,
    }));
    await assertFails(deleteDoc(doc(alice, `PeopleScoreJobs/${ALICE}`)));
  });

  it('does not let a user forge the bookkeeping the worker writes', async () => {
    const alice = ctxFor(ALICE).firestore();
    await assertFails(setDoc(doc(alice, `PeopleScoreJobs/${ALICE}`), {
      dirty: true, dirtyAt: new Date(), lastRunAt: new Date(),
    }));
  });

  it('does not let a user touch anyone else\'s job', async () => {
    const bob = ctxFor(BOB).firestore();
    await assertFails(setDoc(doc(bob, `PeopleScoreJobs/${ALICE}`), {
      dirty: true, dirtyAt: new Date(),
    }));
    await assertFails(getDoc(doc(bob, `PeopleScoreJobs/${ALICE}`)));
  });
});
