'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const {MAX_FAILURES, FAILURE_WINDOW_MS} = require('../playlist_members');

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

  test.beforeEach(async () => {
    await clearCollection('JoinAttempts');
  });

  test.after(async () => {
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

    const data = (await playlist('valid').get()).data();
    assert.deepEqual(data.Users, [{owner: 'Owner'}, {guest: 'Approved'}]);
    assert.deepEqual(new Set(data.memberUids), new Set(['owner', 'guest']));
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
    assert.equal(data.memberUids.filter((uid) => uid === 'guest').length, 1);
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
