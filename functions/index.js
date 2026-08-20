const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const {
  memberUidsFrom,
  sameMembers,
  roleOf,
  normalizeJoinRequest,
  selectPlaylist,
  throttleState,
  FAILURE_WINDOW_MS,
} = require('./playlist_members');

admin.initializeApp();

const db = admin.firestore();
const REGION = 'us-central1';

// Joining a playlist by access code.
//
// The client used to do this itself: download every document in Watchlists,
// compare the access code on the device, then write itself into the Users
// array. That meant every signed-in user could read every playlist -- and the
// access codes were not secret from anyone willing to look at the traffic,
// because they arrived on the device in plain text.
//
// Here the code never leaves the server. The caller sends a guess, the server
// says yes or no, and read access to Watchlists can therefore be restricted to
// members (see the KNOWN GAPS note in firestore.rules).
exports.joinPlaylist = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in before joining a list.');
  }

  const parsed = normalizeJoinRequest(request.data);
  if (!parsed.ok) {
    throw new HttpsError(
      'invalid-argument',
      'Provide both a list name and an access code.',
    );
  }

  const throttleRef = db.collection('JoinAttempts').doc(uid);
  const now = Date.now();
  const throttle = throttleState((await throttleRef.get()).data(), now);
  if (throttle.blocked) {
    throw new HttpsError(
      'resource-exhausted',
      'Too many incorrect attempts. Try again later.',
    );
  }

  // Equality on Name is served by the automatic single-field index, so this
  // reads only the handful of lists sharing that name rather than all of them.
  const matches = await db
    .collection('Watchlists')
    .where('Name', '==', parsed.name)
    .get();

  const playlist = selectPlaylist(
    matches.docs.map((doc) => ({id: doc.id, data: doc.data()})),
    parsed.accessCode,
  );

  if (!playlist) {
    await throttleRef.set(
      {failures: throttle.failures + 1, startedAt: throttle.startedAt},
      {merge: true},
    );
    // Deliberately one message for both a wrong name and a wrong code: saying
    // which part was wrong would confirm that a list exists.
    throw new HttpsError(
      'not-found',
      'No list matches that name and access code.',
    );
  }

  await throttleRef.set({failures: 0, startedAt: now}, {merge: true});

  if (roleOf(playlist.data.Users, uid) !== null) {
    return {id: playlist.id, alreadyMember: true};
  }

  await db
    .collection('Watchlists')
    .doc(playlist.id)
    .update({
      Users: admin.firestore.FieldValue.arrayUnion({[uid]: 'Approved'}),
      memberUids: admin.firestore.FieldValue.arrayUnion(uid),
    });

  logger.info('User joined playlist', {uid, playlistId: playlist.id});
  return {id: playlist.id, alreadyMember: false};
});

// Keeps `memberUids` in step with `Users`.
//
// `Users` is a list of single-key maps ({uid: role}), which Firestore cannot
// query for membership. `memberUids` is a flat array of the same uids, so the
// client can ask for just its own lists with one indexed query instead of
// downloading the collection and filtering on the device.
//
// This runs server side on purpose. Builds already on people's phones write
// only `Users`; if the client maintained `memberUids`, lists touched by an old
// build would silently vanish from a new build. Doing it here means every
// write is covered no matter which version made it.
exports.syncPlaylistMembers = onDocumentWritten(
  {document: 'Watchlists/{listId}', region: REGION},
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;

    const data = after.data();
    const expected = memberUidsFrom(data.Users);

    // This is also the recursion guard: the update below retriggers this
    // function, and the second pass exits here.
    if (sameMembers(data.memberUids, expected)) return;

    await after.ref.update({memberUids: expected});
    logger.info('Synced playlist members', {
      playlistId: event.params.listId,
      count: expected.length,
    });
  },
);

// Housekeeping for the throttle records written above, so JoinAttempts does
// not grow without bound. Runs daily; the documents are worthless once their
// window has passed.
exports.cleanupJoinAttempts = onSchedule(
  {schedule: 'every 24 hours', region: REGION},
  async () => {
    const cutoff = Date.now() - FAILURE_WINDOW_MS;
    const stale = await db
      .collection('JoinAttempts')
      .where('startedAt', '<', cutoff)
      .limit(500)
      .get();

    if (stale.empty) return;

    const batch = db.batch();
    stale.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    logger.info('Cleaned up join attempt records', {count: stale.size});
  },
);

// Push notifications were removed: the Flutter client never registers an
// `fcmToken` (no `firebase_messaging` dependency anywhere in lib/), so the
// previous `sendFriendRequestNotification` trigger always read an undefined
// token and never sent anything. It also called `admin.messaging()
// .sendToDevice(...)`, which used the legacy FCM API decommissioned by
// Google in June 2024, so it would have thrown even if a token existed.
//
// A future implementation must first add `firebase_messaging` on the
// client, persist a real token to Firestore, and then use
// `admin.messaging().send(...)` (the current FCM API) here.
