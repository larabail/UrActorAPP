'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const admin = require('firebase-admin');

const {MAX_FAILURES, FAILURE_WINDOW_MS} = require('../playlist_members');
const {MAX_CREDIT_ATTEMPTS} = require('../people_scores');
const {MAX_USERNAME_LENGTH} = require('../friend_writes');

// Uids for the favourite-people tests. Each test takes a fresh one because
// they own top-level collections named after themselves, like every real user,
// and DELETING one of those documents is itself a library write that queues a
// recompute -- so tidying up after one test would flag the next one's user
// before it had done anything.
let viewerCount = 0;
function nextViewer() {
  viewerCount += 1;
  return `people-scores-${viewerCount}`;
}

// The stub standing in for TMDB. Its port is fixed because the functions
// emulator is started before this file runs and reads the address out of the
// environment -- see TMDB_API_BASE_URL in package.json.
const TMDB_STUB_PORT = Number(process.env.TMDB_STUB_PORT || 5099);

let tmdbStub;
const tmdbCredits = new Map();
const tmdbRequests = [];

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-uractor-functions-test';
const REGION = 'us-central1';
const FUNCTIONS_HOST =
  process.env.TEST_FUNCTIONS_EMULATOR_HOST ||
  process.env.FUNCTIONS_EMULATOR_HOST ||
  '127.0.0.1:5001';
const USING_EMULATOR = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

let db;

if (!USING_EMULATOR) {
  test('Cloud Functions emulator end-to-end tests', {
    skip: 'Firebase emulator suite is not running',
  }, () => {});
} else {
  if (!PROJECT_ID.startsWith('demo-')) {
    throw new Error(`Refusing to run emulator tests against ${PROJECT_ID}`);
  }

  admin.initializeApp({projectId: PROJECT_ID});
  db = admin.firestore();

  test.before(async () => {
    await startTmdbStub();
  });

  test.beforeEach(async () => {
    tmdbRequests.length = 0;
    tmdbCredits.clear();
    await clearCollection('JoinAttempts');
    // Both are shared collections written only by the worker, so clearing them
    // queues nothing -- unlike clearing a user's own documents, where the
    // deletes are themselves library writes. Each test therefore starts with a
    // cold cache and an empty queue, and cannot be reached by a user an
    // earlier test left flagged.
    await clearCollection('Credits');
    await clearCollection('PeopleScoreJobs');
  });

  test.after(async () => {
    await stopTmdbStub();
    await admin.app().delete();
  });

  test('joinPlaylist adds a caller with a valid code', async () => {
    await playlist('valid').set({
      Name: 'Valid Movie Night',
      AccessCode: 'secret',
      Users: [{owner: 'Owner'}],
      memberUids: ['owner'],
    });

    const response = await callJoin(
      {name: 'Valid Movie Night', accessCode: 'secret'},
      'guest',
    );

    assert.equal(response.status, 200);
    assert.deepEqual(response.body.result, {id: 'valid', alreadyMember: false});

    // Users is written by the callable itself, so it is settled the moment the
    // call returns. memberUids is not: joinPlaylist adds the uid with
    // arrayUnion, and syncPlaylistMembers separately rewrites the whole array
    // from the Users in its own snapshot. A trigger still working through an
    // earlier write can therefore clobber the new uid and be corrected on the
    // retrigger, so the array is only reliable once it has settled.
    const data = (await playlist('valid').get()).data();
    assert.deepEqual(data.Users, [{owner: 'Owner'}, {guest: 'Approved'}]);
    await waitForMemberUids('valid', ['guest', 'owner']);
  });

  test('joinPlaylist rejects a wrong code and records the failure', async () => {
    await playlist('wrong-code').set({
      Name: 'Movie Night',
      AccessCode: 'secret',
      Users: [{owner: 'Owner'}],
    });

    const response = await callJoin(
      {name: 'Movie Night', accessCode: 'wrong'},
      'guessing-user',
    );

    assert.equal(response.status, 404);
    assert.equal(response.body.error.status, 'NOT_FOUND');

    const attempt = (await joinAttempt('guessing-user').get()).data();
    assert.equal(attempt.failures, 1);
    assert.equal(typeof attempt.startedAt, 'number');
  });

  test('joinPlaylist rejects an unauthenticated caller', async () => {
    await playlist('private').set({
      Name: 'Private',
      AccessCode: 'secret',
      Users: [{owner: 'Owner'}],
    });

    const response = await callJoin({name: 'Private', accessCode: 'secret'});

    assert.equal(response.status, 401);
    assert.equal(response.body.error.status, 'UNAUTHENTICATED');
    const data = (await playlist('private').get()).data();
    assert.deepEqual(data.Users, [{owner: 'Owner'}]);
  });

  test('joinPlaylist joining twice does not duplicate membership', async () => {
    await playlist('twice').set({
      Name: 'Rewatch',
      AccessCode: 'again',
      Users: [{owner: 'Owner'}],
    });

    const first = await callJoin({name: 'Rewatch', accessCode: 'again'}, 'guest');
    const second = await callJoin({name: 'Rewatch', accessCode: 'again'}, 'guest');

    assert.equal(first.body.result.alreadyMember, false);
    assert.equal(second.body.result.alreadyMember, true);

    const data = (await playlist('twice').get()).data();
    assert.equal(data.Users.filter((entry) => entry.guest === 'Approved').length, 1);
    // Settled rather than immediate, for the reason given above. Comparing the
    // whole sorted array still proves the point of this test: a second join
    // that duplicated the uid would leave ['guest', 'guest', 'owner'].
    await waitForMemberUids('twice', ['guest', 'owner']);
  });

  test('joinPlaylist rate limits repeated wrong codes', async () => {
    await playlist('limited').set({
      Name: 'Limited',
      AccessCode: 'secret',
      Users: [{owner: 'Owner'}],
    });

    for (let i = 0; i < MAX_FAILURES; i++) {
      const response = await callJoin(
        {name: 'Limited', accessCode: `bad-${i}`},
        'blocked-user',
      );
      assert.equal(response.status, 404);
      assert.equal(response.body.error.status, 'NOT_FOUND');
    }

    const blocked = await callJoin(
      {name: 'Limited', accessCode: 'secret'},
      'blocked-user',
    );

    assert.equal(blocked.status, 429);
    assert.equal(blocked.body.error.status, 'RESOURCE_EXHAUSTED');
    assert.equal((await joinAttempt('blocked-user').get()).data().failures, MAX_FAILURES);
  });

  // -------------------------------------------------------------------------
  // Recommending a title to a friend.
  //
  // The client used to write into the recipient's inbox itself, with a
  // `sender` built on its own device. What matters here is that the server
  // now decides who the sender is, who is allowed to be written to, and where
  // in the document the entry lands.
  // -------------------------------------------------------------------------

  test('recommendTitle delivers, and derives the sender itself', async () => {
    const {sender, recipient} = recommendationPair();
    await db.collection(sender).doc('Settings').set({username: 'Alice'});
    await befriend(recipient, sender);

    const response = await callRecommend(recommendation([recipient]), sender);

    assert.equal(response.status, 200);
    assert.deepEqual(response.body.result, {delivered: 1, skipped: []});

    const inbox = (await notifications(recipient).get()).data();
    assert.deepEqual(Object.keys(inbox), ['0']);
    assert.equal(inbox['0'].id, '27205');
    assert.equal(inbox['0'].type, 'movie');
    assert.equal(inbox['0'].title, 'Inception');
    assert.equal(inbox['0'].coverPhoto, '/cover.jpg');
    assert.deepEqual(inbox['0'].sender, {uid: sender, username: 'Alice'});
    assert.equal(inbox['0'].read, false);
    assert.ok(inbox['0'].timestamp, 'the inbox orders by timestamp');
  });

  test('recommendTitle ignores a sender supplied by the caller', async () => {
    // The defect the whole callable exists for: a friend could file a
    // recommendation in your inbox attributed to somebody else entirely.
    const {sender, recipient} = recommendationPair();
    await db.collection(sender).doc('Settings').set({username: 'Mallory'});
    await db.collection('impostor').doc('Settings').set({username: 'Alice'});
    await befriend(recipient, sender);

    const response = await callRecommend(
      {
        ...recommendation([recipient]),
        sender: {uid: 'impostor', username: 'Alice'},
      },
      sender,
    );

    assert.equal(response.status, 200);
    const inbox = (await notifications(recipient).get()).data();
    assert.deepEqual(inbox['0'].sender, {uid: sender, username: 'Mallory'});
  });

  test('recommendTitle skips someone who has not listed the caller', async () => {
    // The target's own friends list decides, not the caller's -- the same
    // asymmetry as friendOf() in firestore.rules, because anyone can write
    // themselves into their own list.
    const {sender, recipient} = recommendationPair();
    await db.collection(sender).doc('Friends').set({friends: [recipient]});
    await befriend(recipient, 'somebody-else');

    const response = await callRecommend(recommendation([recipient]), sender);

    assert.equal(response.status, 200);
    assert.deepEqual(response.body.result, {delivered: 0, skipped: [recipient]});
    assert.equal((await notifications(recipient).get()).exists, false);
  });

  test('recommendTitle delivers to the friends in a mixed list', async () => {
    // One stranger in the list must not cost the real friends their copy.
    const {sender, recipient} = recommendationPair();
    const stranger = `${recipient}-stranger`;
    await befriend(recipient, sender);

    const response = await callRecommend(
      recommendation([stranger, recipient]),
      sender,
    );

    assert.deepEqual(response.body.result, {delivered: 1, skipped: [stranger]});
    assert.equal(Object.keys((await notifications(recipient).get()).data()).length, 1);
    assert.equal((await notifications(stranger).get()).exists, false);
  });

  test('recommendTitle refuses an unauthenticated caller', async () => {
    const {sender, recipient} = recommendationPair();
    await befriend(recipient, sender);

    const response = await callRecommend(recommendation([recipient]));

    assert.equal(response.status, 401);
    assert.equal(response.body.error.status, 'UNAUTHENTICATED');
    assert.equal((await notifications(recipient).get()).exists, false);
  });

  test('recommendTitle refuses a malformed payload', async () => {
    const {sender, recipient} = recommendationPair();
    await befriend(recipient, sender);

    const payloads = [
      {...recommendation([recipient]), title: ''},
      {...recommendation([recipient]), id: ''},
      // 'series' is not what the app sends, and notifications.dart would
      // render it as a show rather than reject it.
      {...recommendation([recipient]), type: 'series'},
      {...recommendation([recipient]), friends: []},
      {...recommendation([recipient]), friends: recipient},
      {},
    ];

    for (const payload of payloads) {
      const response = await callRecommend(payload, sender);
      assert.equal(
        response.status,
        400,
        `accepted ${JSON.stringify(payload)}`,
      );
      assert.equal(response.body.error.status, 'INVALID_ARGUMENT');
    }

    assert.equal((await notifications(recipient).get()).exists, false);
  });

  test('recommendTitle appends at consecutive dense keys', async () => {
    // LOAD-BEARING, and the reason this test exists rather than being implied
    // by the one above. appendsOneNotificationOnly() in firestore.rules
    // validates an appended notification by rebuilding its key as
    // string(resource.data.keys().size()), which only ever names the right
    // entry while the keys are 0, 1, 2, ... with no gaps. Builds already on
    // people's phones append the same way (lib/popups/share.dart), so a uuid
    // or a timestamp here would make every later write from one of them read
    // as a change rather than an add -- refused, silently, forever.
    const {sender, recipient} = recommendationPair();
    await befriend(recipient, sender);

    await callRecommend(recommendation([recipient], {id: '1'}), sender);
    await callRecommend(recommendation([recipient], {id: '2'}), sender);
    await callRecommend(recommendation([recipient], {id: '3'}), sender);

    const inbox = (await notifications(recipient).get()).data();
    assert.deepEqual(Object.keys(inbox).sort(), ['0', '1', '2']);
    assert.deepEqual(
      ['0', '1', '2'].map((key) => inbox[key].id),
      ['1', '2', '3'],
    );
  });

  test('recommendTitle loses neither of two simultaneous recommendations',
      async () => {
        // The old client read the whole document, added a key and wrote the
        // whole thing back unmerged, so whichever of these finished second
        // erased the other. Both keys have to be here, and densely.
        const {sender, recipient} = recommendationPair();
        const other = `${sender}-other`;
        await db.collection(recipient).doc('Friends')
            .set({friends: [sender, other]});

        await Promise.all([
          callRecommend(recommendation([recipient], {id: '1'}), sender),
          callRecommend(recommendation([recipient], {id: '2'}), other),
        ]);

        const inbox = (await notifications(recipient).get()).data();
        assert.deepEqual(Object.keys(inbox).sort(), ['0', '1']);
        assert.deepEqual(
          ['0', '1'].map((key) => inbox[key].id).sort(),
          ['1', '2'],
        );
      });

  test('recommendTitle creates an inbox that does not exist yet', async () => {
    // A friend who has never been sent anything has no Notifications
    // document. The old client threw on the missing data and swallowed it, so
    // they could never receive a first recommendation at all.
    const {sender, recipient} = recommendationPair();
    await befriend(recipient, sender);
    assert.equal((await notifications(recipient).get()).exists, false);

    const response = await callRecommend(recommendation([recipient]), sender);

    assert.deepEqual(response.body.result, {delivered: 1, skipped: []});
    assert.deepEqual(Object.keys((await notifications(recipient).get()).data()), ['0']);
  });

  test('recommendTitle refuses to write into a collection the app owns',
      async () => {
        // The uid names a top-level collection the server writes to with admin
        // credentials. Without a check, a caller who can create
        // `Watchlists/Friends` listing themselves gets a junk
        // `Watchlists/Notifications` written on their behalf.
        const {sender} = recommendationPair();
        await db.collection('Watchlists').doc('Friends')
            .set({friends: [sender]});

        const response = await callRecommend(
          recommendation(['Watchlists']),
          sender,
        );

        assert.equal(response.status, 400);
        assert.equal(response.body.error.status, 'INVALID_ARGUMENT');
        assert.equal(
          (await db.collection('Watchlists').doc('Notifications').get()).exists,
          false,
        );
      });

  test('recommendTitle refuses a uid that is really a path', async () => {
    const {sender} = recommendationPair();

    const response = await callRecommend(
      recommendation(['Oscars/best/Notifications']),
      sender,
    );

    assert.equal(response.status, 400);
    assert.equal(response.body.error.status, 'INVALID_ARGUMENT');
  });

  test('recommendTitle refuses to write over a sparse inbox', async () => {
    // {0, 2} has two keys, so the dense key is '2' -- already taken. Writing
    // there would destroy a notification the recipient may not have read, and
    // writing at '3' would leave the document permanently unwritable by an
    // old client. Skipping is the only option that loses nothing.
    const {sender, recipient} = recommendationPair();
    await befriend(recipient, sender);
    await notifications(recipient).set({
      0: {id: '603', read: true},
      2: {id: '604', read: false},
    });

    const response = await callRecommend(recommendation([recipient]), sender);

    assert.deepEqual(response.body.result, {delivered: 0, skipped: [recipient]});
    const inbox = (await notifications(recipient).get()).data();
    assert.deepEqual(Object.keys(inbox).sort(), ['0', '2']);
    assert.equal(inbox['2'].id, '604');
  });

  test('recommendTitle refuses a gap the dense key does not land on',
      async () => {
        // {0, 3} is the shape that a "is String(count) taken?" check waves
        // through: the count is 2 and '2' is free. Appending there produces
        // {0, 2, 3}, whose dense key IS taken -- so a build already on
        // someone's phone could append to this inbox before the call and never
        // again after it. Nothing may be written here.
        const {sender, recipient} = recommendationPair();
        await befriend(recipient, sender);
        await notifications(recipient).set({
          0: {id: '603', read: true},
          3: {id: '604', read: false},
        });

        const response = await callRecommend(recommendation([recipient]), sender);

        assert.deepEqual(response.body.result,
            {delivered: 0, skipped: [recipient]});
        assert.deepEqual(
          Object.keys((await notifications(recipient).get()).data()).sort(),
          ['0', '3'],
        );
      });

  test('recommendTitle bounds the username it copies into an inbox',
      async () => {
        // The sender writes their own Settings document, so its size is
        // theirs to choose. One call fans it into every recipient.
        const {sender, recipient} = recommendationPair();
        await db.collection(sender).doc('Settings')
            .set({username: 'A'.repeat(5000)});
        await befriend(recipient, sender);

        await callRecommend(recommendation([recipient]), sender);

        const inbox = (await notifications(recipient).get()).data();
        assert.equal(inbox['0'].sender.username.length, MAX_USERNAME_LENGTH);
      });

  test('syncPlaylistMembers handles legacy, added, and removed members', async () => {
    await playlist('sync').set({
      Name: 'Synced',
      AccessCode: 'sync',
      Users: [{owner: 'Owner'}, {guest: 'Approved'}],
    });

    await waitForMemberUids('sync', ['guest', 'owner']);

    await playlist('sync').update({Users: [{guest: 'Approved'}]});
    await waitForMemberUids('sync', ['guest']);

    await playlist('sync').update({
      Users: [{guest: 'Approved'}, {newbie: 'Approved'}],
    });
    await waitForMemberUids('sync', ['guest', 'newbie']);
  });

  test('cleanupJoinAttempts removes old records and keeps recent ones', async () => {
    const now = Date.now();
    await joinAttempt('old').set({
      failures: 7,
      startedAt: now - FAILURE_WINDOW_MS - 1000,
    });
    await joinAttempt('recent').set({
      failures: 2,
      startedAt: now,
    });

    const response = await callScheduledCleanup();

    assert.equal(response.status, 200);
    assert.equal((await joinAttempt('old').get()).exists, false);
    assert.equal((await joinAttempt('recent').get()).exists, true);
  });

  // -------------------------------------------------------------------------
  // Favourite actors, directors and writers.
  //
  // The whole point of moving this off the person page is that it no longer
  // depends on anyone being tapped, so what these check is the pipeline: a
  // library write queues the work, and the scheduled run turns a library into
  // three ranked documents without a person page ever being opened.
  // -------------------------------------------------------------------------

  test('a library write queues a recompute', async () => {
    const viewer = nextViewer();

    await db.collection(viewer).doc('Movies').set({Seen: ['550']});

    await waitFor(async () => {
      const job = await peopleScoreJob(viewer).get();
      assert.equal(job.data()?.dirty, true);
    });
  });

  test('a write that cannot change a score queues nothing', async () => {
    const viewer = nextViewer();
    const other = nextViewer();

    await db.collection(viewer).doc('Settings').set({language: 'en'});

    // Writing a real library document for someone else and waiting for THEIR
    // job proves the trigger has caught up past the write above, so the
    // absence below is a decision rather than a race.
    await db.collection(other).doc('Movies').set({Seen: ['550']});
    await waitFor(async () => {
      assert.equal((await peopleScoreJob(other).get()).exists, true);
    });

    assert.equal((await peopleScoreJob(viewer).get()).exists, false);
  });

  test('a scheduled run scores a library nobody has opened a person page for',
    async () => {
      const viewer = nextViewer();
      stubCredits('movie/550', {
        cast: [{id: 819, character: 'The Narrator'}],
        crew: [{id: 7467, job: 'Director'}, {id: 7469, job: 'Screenplay'}],
      });
      // A show answers in the aggregate shape, with roles and jobs nested.
      stubCredits('tv/1396', {
        cast: [{id: 17419, roles: [{character: 'Walter White'}]}],
        crew: [{id: 66633, jobs: [{job: 'Director'}]}],
      });

      await db.collection(viewer).doc('Movies').set({Seen: ['550']});
      await db.collection(viewer).doc('TVShows').set({Seen: ['1396']});
      await db.collection(viewer).doc('Favorites').set({Movies: ['550']});
      await waitForDirtyJob(viewer);

      await runPeopleScores();

      // 550 seen and favourited is 5; 1396 seen is 2.
      assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {
        819: 5, 17419: 2,
      });
      assert.deepEqual((await favDoc(viewer, 'FavDirectors')).data(), {
        7467: 5, 66633: 2,
      });
      assert.deepEqual((await favDoc(viewer, 'FavWriters')).data(), {7469: 5});
    });

  test('a scheduled run marks the job done', async () => {
    const viewer = nextViewer();
    stubCredits('movie/550', {cast: [], crew: []});
    await db.collection(viewer).doc('Movies').set({Seen: ['550']});
    await waitForDirtyJob(viewer);

    await runPeopleScores();

    const job = (await peopleScoreJob(viewer).get()).data();
    assert.equal(job.dirty, false);
    assert.ok(job.lastRunAt);
  });

  test('credits are fetched once and then read from the cache', async () => {
    // A title's credits are the same for everyone, so the first viewer to have
    // seen a film pays for it and nobody pays again -- including that same
    // viewer on their next recompute.
    const viewer = nextViewer();
    stubCredits('movie/550', {
      cast: [{id: 819, character: 'The Narrator'}],
      crew: [],
    });

    await db.collection(viewer).doc('Movies').set({Seen: ['550']});
    await waitForDirtyJob(viewer);
    await runPeopleScores();
    assert.deepEqual(tmdbRequests, ['movie/550']);

    await peopleScoreJob(viewer).set({dirty: true, dirtyAt: new Date()});
    await runPeopleScores();

    assert.deepEqual(tmdbRequests, ['movie/550'], 'asked TMDB a second time');
    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {819: 2});
  });

  test('someone who has left the library loses their score', async () => {
    // The documents are written whole rather than merged. Merging would leave
    // a person scoring for a film that has since been unfavourited or removed,
    // which is one of the ways the old person-page version went wrong.
    const viewer = nextViewer();
    stubCredits('movie/550', {
      cast: [{id: 819, character: 'Narrator'}],
      crew: [],
    });
    stubCredits('movie/807', {
      cast: [{id: 2231, character: 'Somerset'}],
      crew: [],
    });

    await db.collection(viewer).doc('Movies').set({Seen: ['550', '807']});
    await waitForDirtyJob(viewer);
    await runPeopleScores();
    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {
      819: 2, 2231: 2,
    });

    await db.collection(viewer).doc('Movies').set({Seen: ['550']});
    await waitForDirtyJob(viewer);
    await runPeopleScores();

    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {819: 2});
  });

  test('a title TMDB does not know is remembered as missing', async () => {
    // Old libraries hold ids TMDB no longer recognises. Caching the 404 is
    // what stops every run from asking about them again forever.
    const viewer = nextViewer();
    stubCredits('movie/550', {
      cast: [{id: 819, character: 'Narrator'}],
      crew: [],
    });

    await db.collection(viewer).doc('Movies').set({Seen: ['550', '99999999']});
    await waitForDirtyJob(viewer);
    await runPeopleScores();

    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {819: 2});
    const cached = await db.collection('Credits').doc('Movies_99999999').get();
    assert.equal(cached.data().missing, true);

    // Titles are fetched concurrently, so only the count is deterministic.
    const asked = tmdbRequests.length;
    await peopleScoreJob(viewer).set({dirty: true, dirtyAt: new Date()});
    await runPeopleScores();
    assert.equal(tmdbRequests.length, asked, 'asked about the 404 again');
  });

  test('a title that keeps failing is eventually written off', async () => {
    // A 500 is temporary as far as one request goes, so it is retried rather
    // than cached. Retried forever, though, it would hold this viewer's whole
    // library back: nothing is stored until every title resolves.
    const viewer = nextViewer();
    stubCredits('movie/550', {
      cast: [{id: 819, character: 'Narrator'}],
      crew: [],
    });
    stubStatus('movie/807', 500);

    await db.collection(viewer).doc('Movies').set({Seen: ['550', '807']});
    await waitForDirtyJob(viewer);

    await runPeopleScores();
    assert.equal((await favDoc(viewer, 'FavActors')).exists, false,
      'stored a ranking computed from half a library');
    assert.equal((await peopleScoreJob(viewer).get()).data().dirty, true,
      'a deferred user has to stay queued');

    // The run that gives up on the title is also the one that finally scores
    // its owner, so the whole thing takes exactly MAX_CREDIT_ATTEMPTS runs.
    for (let attempt = 2; attempt <= MAX_CREDIT_ATTEMPTS; attempt++) {
      await runPeopleScores();
    }

    const cached = await db.collection('Credits').doc('Movies_807').get();
    assert.equal(cached.data().missing, true);
    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {819: 2});
    assert.equal((await peopleScoreJob(viewer).get()).data().dirty, false);
  });

  test('a library write during a run is not lost', async () => {
    // Clearing the flag on the strength of a claim made before the write would
    // drop the second film: the ranking would sit a title out of date until
    // something else happened to change.
    const viewer = nextViewer();
    stubCredits(
      'movie/550',
      {cast: [{id: 819, character: 'Narrator'}], crew: []},
      {delayMs: 2000},
    );
    stubCredits('movie/807', {
      cast: [{id: 2231, character: 'Somerset'}],
      crew: [],
    });

    await db.collection(viewer).doc('Movies').set({Seen: ['550']});
    await waitForDirtyJob(viewer);

    // The run claims the job immediately and then sits on the held-back
    // credits request, so this write genuinely lands mid-recompute.
    const running = runPeopleScores();
    await new Promise((resolve) => setTimeout(resolve, 500));
    await db.collection(viewer).doc('Movies').set({Seen: ['550', '807']});
    await running;

    await waitFor(async () => {
      const job = await peopleScoreJob(viewer).get();
      assert.equal(job.data().dirty, true, 'the mid-run write was forgotten');
    });

    // And the next run picks the change up.
    await runPeopleScores();
    assert.deepEqual((await favDoc(viewer, 'FavActors')).data(), {
      819: 2, 2231: 2,
    });
  });
}

function playlist(id) {
  return db.collection('Watchlists').doc(id);
}

function joinAttempt(uid) {
  return db.collection('JoinAttempts').doc(uid);
}

function notifications(uid) {
  return db.collection(uid).doc('Notifications');
}

// Fresh uids per recommendation test, for the same reason nextViewer() exists:
// every user owns a top-level collection named after themselves, and a
// document one test left behind is one the next test would append after.
let recommendationCount = 0;
function recommendationPair() {
  recommendationCount += 1;
  return {
    sender: `recommender-${recommendationCount}`,
    recipient: `recipient-${recommendationCount}`,
  };
}

// Writes `friend` into `uid`'s own friends list, which is the direction that
// counts: recommendTitle reads the TARGET's list to decide who may write to
// them, never the caller's.
async function befriend(uid, friend) {
  await db.collection(uid).doc('Friends').set({friends: [friend]});
}

function recommendation(friends, overrides = {}) {
  return {
    id: '27205',
    type: 'movie',
    title: 'Inception',
    coverPhoto: '/cover.jpg',
    friends,
    ...overrides,
  };
}

async function clearCollection(name) {
  const snapshot = await db.collection(name).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function callJoin(data, uid) {
  return callFunction('joinPlaylist', data, uid);
}

async function callRecommend(data, uid) {
  return callFunction('recommendTitle', data, uid);
}

async function callFunction(name, data, uid) {
  const headers = {'Content-Type': 'application/json'};
  if (uid) headers.Authorization = `Bearer ${unsignedToken(uid)}`;

  const response = await fetch(functionUrl(name), {
    method: 'POST',
    headers,
    body: JSON.stringify({data}),
  });

  return {status: response.status, body: await response.json()};
}

async function callScheduledCleanup() {
  const response = await fetch(functionUrl('cleanupJoinAttempts-0'), {
    method: 'POST',
  });
  return {status: response.status, body: await response.text()};
}

function functionUrl(name) {
  return `http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}/${name}`;
}

function unsignedToken(uid) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url({alg: 'none', typ: 'JWT'});
  const payload = base64Url({
    aud: PROJECT_ID,
    iss: `https://securetoken.google.com/${PROJECT_ID}`,
    sub: uid,
    user_id: uid,
    iat: now,
    exp: now + 3600,
    firebase: {sign_in_provider: 'custom'},
  });
  return `${header}.${payload}.`;
}

function base64Url(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

async function waitForMemberUids(id, expected) {
  await waitFor(async () => {
    const data = (await playlist(id).get()).data();
    assert.deepEqual(data.memberUids, expected);
  });
}

async function waitFor(assertion) {
  const deadline = Date.now() + 10000;
  let lastError;

  while (Date.now() < deadline) {
    try {
      await assertion();
      return;
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }

  throw lastError;
}

function peopleScoreJob(uid) {
  return db.collection('PeopleScoreJobs').doc(uid);
}

function favDoc(uid, docId) {
  return db.collection(uid).doc(docId).get();
}

// Registers a credits response for a TMDB path such as `movie/550`. Anything
// not registered answers 404, which is what TMDB does for an id it has never
// heard of.
function stubCredits(path, payload, {delayMs = 0} = {}) {
  tmdbCredits.set(path, {status: 200, payload, delayMs});
}

// Registers a failure for a TMDB path, for the paths where the interesting
// behaviour is what happens when TMDB will not answer.
function stubStatus(path, status) {
  tmdbCredits.set(path, {status, payload: {status_code: 0}});
}

async function startTmdbStub() {
  tmdbStub = http.createServer((request, response) => {
    // `/3/movie/550/credits?api_key=...` -> `movie/550`
    const url = new URL(request.url, `http://127.0.0.1:${TMDB_STUB_PORT}`);
    const parts = url.pathname.split('/').filter(Boolean);
    const path = parts.slice(1, 3).join('/');
    tmdbRequests.push(path);

    const stub = tmdbCredits.get(path);
    if (!stub) {
      response.writeHead(404, {'Content-Type': 'application/json'});
      response.end(JSON.stringify({status_code: 34}));
      return;
    }
    const send = () => {
      response.writeHead(stub.status, {'Content-Type': 'application/json'});
      response.end(JSON.stringify(stub.payload));
    };
    // A held-back response is how a test gets to write to Firestore while a
    // recompute is genuinely in flight.
    if (stub.delayMs) setTimeout(send, stub.delayMs);
    else send();
  });

  await new Promise((resolve, reject) => {
    tmdbStub.once('error', reject);
    tmdbStub.listen(TMDB_STUB_PORT, '127.0.0.1', resolve);
  });
}

async function stopTmdbStub() {
  if (!tmdbStub) return;
  await new Promise((resolve) => tmdbStub.close(resolve));
  tmdbStub = null;
}

async function waitForDirtyJob(uid) {
  await waitFor(async () => {
    const job = await peopleScoreJob(uid).get();
    assert.equal(job.data()?.dirty, true);
  });
}

// The emulator exposes a scheduled function over HTTP, which is the only way
// to make one run on demand.
async function runPeopleScores() {
  const response = await fetch(functionUrl('recomputePeopleScores-0'), {
    method: 'POST',
  });
  const body = await response.text();
  assert.equal(response.ok, true, body);
}
