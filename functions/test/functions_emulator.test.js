'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const admin = require('firebase-admin');

const {MAX_FAILURES, FAILURE_WINDOW_MS} = require('../playlist_members');
const {MAX_CREDIT_ATTEMPTS} = require('../people_scores');

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

    for (let attempt = 1; attempt < MAX_CREDIT_ATTEMPTS; attempt++) {
      await runPeopleScores();
    }

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

async function clearCollection(name) {
  const snapshot = await db.collection(name).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function callJoin(data, uid) {
  const headers = {'Content-Type': 'application/json'};
  if (uid) headers.Authorization = `Bearer ${unsignedToken(uid)}`;

  const response = await fetch(functionUrl('joinPlaylist'), {
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
