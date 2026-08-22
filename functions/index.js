const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const {FieldValue} = require('firebase-admin/firestore');

const {
  memberUidsFrom,
  sameMembers,
  roleOf,
  normalizeJoinRequest,
  selectPlaylist,
  throttleState,
  FAILURE_WINDOW_MS,
} = require('./playlist_members');
const {
  normalizeImdbId,
  buildOmdbUrl,
  trimOmdbResponse,
} = require('./omdb');
const {
  isLibraryWrite,
  libraryFrom,
  trimCredits,
  creditsKey,
  buildCreditsUrl,
  creditFailureKind,
  creditAttemptOutcome,
  mayClearDirty,
  cachedCreditsFrom,
  scoreLibrary,
  titlesNeedingCredits,
  LIBRARY_DOCS,
} = require('./people_scores');

admin.initializeApp();

const db = admin.firestore();
const REGION = 'us-central1';
const OMDB_API_KEY = defineSecret('OMDB_API_KEY');
const TMDB_API_KEY = defineSecret('TMDB_API_KEY');

// Looking up IMDb ratings through OMDB.
//
// The client used to call OMDB directly with a build-time `OMDB_API_KEY`. That
// put a non-rotatable Patreon key into every app binary, where anyone could
// extract it once the repository or an APK/IPA was public. The app now sends
// only a validated IMDb id, and the server keeps the key in a Firebase secret.
//
// Authentication is required because an unauthenticated callable would still be
// a public proxy for the same key. The id is deliberately narrow too: accepting
// only `tt` plus digits prevents callers from turning this into an arbitrary
// OMDB query proxy.
exports.omdbLookup = onCall(
  {region: REGION, secrets: [OMDB_API_KEY]},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in before looking up OMDB.');
    }

    const parsed = normalizeImdbId(request.data?.imdbId);
    if (!parsed.ok) {
      throw new HttpsError('invalid-argument', 'Provide a valid IMDb id.');
    }

    try {
      const apiKey = OMDB_API_KEY.value();
      if (!apiKey) {
        logger.error('OMDB secret is not configured');
        throw new HttpsError('unavailable', 'OMDB is unavailable.');
      }

      const response = await fetch(buildOmdbUrl(parsed.id, apiKey));
      if (!response.ok) {
        logger.warn('OMDB lookup returned a non-200 response', {
          imdbId: parsed.id,
          status: response.status,
        });
        throw new HttpsError('unavailable', 'OMDB is unavailable.');
      }

      const trimmed = trimOmdbResponse(await response.json());
      if (trimmed.Response === 'False') {
        throw new HttpsError('not-found', 'No OMDB title matches that IMDb id.');
      }
      return trimmed;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.warn('OMDB lookup failed', {
        imdbId: parsed.id,
        message: error?.message,
      });
      throw new HttpsError('unavailable', 'OMDB is unavailable.');
    }
  },
);

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
      Users: FieldValue.arrayUnion({[uid]: 'Approved'}),
      memberUids: FieldValue.arrayUnion(uid),
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

// ---------------------------------------------------------------------------
// Favourite actors, directors and writers.
//
// These scores used to be written by the person page: opening someone's
// profile fetched THEIR filmography, intersected it with the viewer's library
// and saved the result. The ranking that came out was really a record of whose
// page you had opened -- an actor you never tapped never appeared however much
// of their work you had seen, and a score you did have stayed frozen at your
// last visit.
//
// It runs the other way round here, over the viewer's own library, so every
// person who could rank is reached whether or not anyone ever looked them up.
// It also runs on a schedule rather than on each write: marking one film seen
// touches several documents in a burst, and each of those alone would
// otherwise start a full recompute.
// ---------------------------------------------------------------------------

// How many users one scheduled run will recompute. Bounded so a backlog costs
// several ordinary runs rather than one run that overruns its timeout.
const PEOPLE_SCORE_JOB_BATCH = 20;

// How many titles one run will fetch credits for. A large library that is
// entirely uncached cannot be finished inside a single run, so the run banks
// what it fetched, leaves the user dirty and lets the next run continue from
// a warmer cache. Nothing is written until every title resolves, because a
// ranking computed from half a library is wrong rather than incomplete.
const MAX_CREDIT_FETCHES_PER_RUN = 250;

// Concurrent TMDB requests. Their limit is far higher; this is low enough to
// stay clear of it while several users are being recomputed in one run.
const CREDIT_FETCH_CONCURRENCY = 8;

// Firestore takes a generous number of refs per getAll, but not unlimited.
const CREDIT_READ_CHUNK = 200;

// When to stop starting another user, short of the 540 second timeout.
//
// A run that is killed mid-user leaves that user claimed but unscored, and
// everyone queued behind them unstarted. Stopping between users instead means
// the batch always ends on a clean boundary and the rest are simply picked up
// by the next run five minutes later.
const RUN_DEADLINE_MS = 480000;

const PEOPLE_SCORE_DOCS = ['FavActors', 'FavDirectors', 'FavWriters'];

// TMDB rejecting the key is not one title's problem, it is every title's, so
// it has to be distinguishable from an ordinary fetch failure all the way up.
class CreditsAuthError extends Error {
  constructor(status) {
    super(`TMDB rejected the API key with ${status}`);
    this.name = 'CreditsAuthError';
    this.status = status;
  }
}

// Notes that a user's library changed, without doing any of the work.
//
// The trigger has to watch `{uid}/{docId}` because every user owns a
// TOP-LEVEL collection named after their uid, so this fires for every
// top-level document write in the database. isLibraryWrite is what keeps that
// cheap: anything outside the handful of library documents returns before
// touching Firestore, including the writes these functions make themselves,
// which is also what stops this from retriggering itself forever.
exports.markPeopleScoresDirty = onDocumentWritten(
  {document: '{uid}/{docId}', region: REGION},
  async (event) => {
    const {uid, docId} = event.params;
    if (!isLibraryWrite(uid, docId)) return;

    await db.collection('PeopleScoreJobs').doc(uid).set(
      {dirty: true, dirtyAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  },
);

// Reads the documents a score is computed from. One round trip rather than
// six, and missing documents are normal rather than an error.
async function readLibrary(uid) {
  const refs = LIBRARY_DOCS.map((docId) => db.collection(uid).doc(docId));
  const snapshots = await db.getAll(...refs);
  const docs = {};
  for (const snapshot of snapshots) {
    if (snapshot.exists) docs[snapshot.id] = snapshot.data();
  }
  return libraryFrom(docs);
}

// Credits already cached, keyed the way scoreLibrary asks for them.
//
// The cache is shared by every user because a title's credits are the same for
// everyone: the first viewer to have seen a film pays for it and nobody pays
// again. A `missing` marker is cached too, so an id TMDB does not recognise --
// there are plenty in old libraries -- is not re-fetched on every run forever.
async function readCachedCredits(titles) {
  const cached = new Map();
  for (let i = 0; i < titles.length; i += CREDIT_READ_CHUNK) {
    const chunk = titles.slice(i, i + CREDIT_READ_CHUNK);
    const refs = chunk.map(({type, id}) =>
      db.collection('Credits').doc(creditsKey(type, id)));
    const snapshots = await db.getAll(...refs);
    for (const snapshot of snapshots) {
      if (!snapshot.exists) continue;
      const answer = cachedCreditsFrom(snapshot.data());
      if (answer === undefined) continue;
      cached.set(snapshot.id, answer);
    }
  }
  return cached;
}

// Counts a temporary failure against a title, and writes it off once it has
// failed often enough.
//
// Nothing is written for a user until every one of their titles resolves, so
// without this a single id that always answers 500 would defer that user on
// every run forever and their scores would never appear at all.
async function recordCreditFailure(ref, error) {
  const previous = (await ref.get()).data()?.attempts;
  const {attempts, writeOff} = creditAttemptOutcome(previous);

  if (writeOff) {
    await ref.set({
      missing: true,
      attempts,
      fetchedAt: FieldValue.serverTimestamp(),
    });
    logger.warn('Gave up on a title after repeated credit failures', {
      credits: ref.id,
      attempts,
      message: error?.message,
    });
    return;
  }

  await ref.set(
    {attempts, failedAt: FieldValue.serverTimestamp()},
    {merge: true},
  );
}

// Fetches one title's credits and caches the trimmed result.
async function fetchAndCacheCredits(type, id, apiKey) {
  const key = creditsKey(type, id);
  const ref = db.collection('Credits').doc(key);

  try {
    const response = await fetch(buildCreditsUrl(type, id, apiKey));

    if (response.ok) {
      const credits = trimCredits(await response.json());
      // Written whole, so a title that finally answers loses the record of the
      // attempts it took to get there.
      await ref.set({...credits, fetchedAt: FieldValue.serverTimestamp()});
      return {key, credits};
    }

    const kind = creditFailureKind(response.status);
    if (kind === 'auth') throw new CreditsAuthError(response.status);
    if (kind === 'permanent') {
      await ref.set({missing: true, fetchedAt: FieldValue.serverTimestamp()});
      return {key, credits: null};
    }
    throw new Error(`TMDB credits request failed with ${response.status}`);
  } catch (error) {
    // A rejected key says nothing about this title and must not be recorded
    // against it. Everything else -- a rate limit, an outage, a socket that
    // never answered -- counts as one failed attempt.
    if (error instanceof CreditsAuthError) throw error;
    await recordCreditFailure(ref, error);
    throw error;
  }
}

// Fills the gaps in the cache, a few at a time, up to this run's budget.
// Returns the credits it managed to resolve and whether any title is still
// outstanding.
async function fetchMissingCredits(missing, apiKey) {
  const resolved = new Map();
  const budget = missing.slice(0, MAX_CREDIT_FETCHES_PER_RUN);
  let failed = missing.length - budget.length;

  for (let i = 0; i < budget.length; i += CREDIT_FETCH_CONCURRENCY) {
    const batch = budget.slice(i, i + CREDIT_FETCH_CONCURRENCY);
    const results = await Promise.allSettled(
      batch.map(({type, id}) => fetchAndCacheCredits(type, id, apiKey)),
    );
    for (const result of results) {
      if (result.status === 'fulfilled') {
        resolved.set(result.value.key, result.value.credits);
      } else if (result.reason instanceof CreditsAuthError) {
        // Nothing will succeed until the secret is fixed, so stop rather than
        // spend the rest of the run proving it.
        throw result.reason;
      } else {
        failed++;
      }
    }
  }

  return {resolved, incomplete: failed > 0};
}

// Recomputes and stores one user's three score documents.
async function recomputeFor(uid, apiKey) {
  const library = await readLibrary(uid);
  const titles = titlesNeedingCredits(library);
  const cached = await readCachedCredits(titles);

  const missing = titles.filter(
    ({type, id}) => !cached.has(creditsKey(type, id)),
  );
  const {resolved, incomplete} = missing.length ?
    await fetchMissingCredits(missing, apiKey) :
    {resolved: new Map(), incomplete: false};

  if (incomplete) return {written: false, titles: titles.length};

  const credits = new Map([...cached, ...resolved]);
  const scores = scoreLibrary(library, (type, id) =>
    credits.get(creditsKey(type, id)) || null);

  // Written whole rather than merged, so a person who has dropped out of the
  // library -- an unfavourited film, a cleared watchlist -- loses their score
  // instead of keeping the one they last had. It is also what corrects the
  // values older clients still write from the person page.
  const batch = db.batch();
  for (const docId of PEOPLE_SCORE_DOCS) {
    batch.set(db.collection(uid).doc(docId), scores[docId]);
  }
  await batch.commit();

  return {written: true, titles: titles.length};
}

// Works through the users whose libraries have changed.
//
// The dirty flag is cleared only once the scores are actually stored, and only
// when nothing has re-flagged the user in the meantime. Clearing it up front
// would be simpler but loses two things: a run killed by its timeout would
// leave a user marked done and never scored, and a library write that landed
// mid-run would be forgotten rather than picked up next time.
exports.recomputePeopleScores = onSchedule(
  {
    schedule: 'every 5 minutes',
    region: REGION,
    secrets: [TMDB_API_KEY],
    timeoutSeconds: 540,
  },
  async () => {
    const apiKey = TMDB_API_KEY.value();
    if (!apiKey) {
      logger.error('TMDB secret is not configured');
      return;
    }

    const jobs = await db
      .collection('PeopleScoreJobs')
      .where('dirty', '==', true)
      .orderBy('dirtyAt')
      .limit(PEOPLE_SCORE_JOB_BATCH)
      .get();

    if (jobs.empty) return;

    const startedAt = Date.now();
    for (const job of jobs.docs) {
      if (Date.now() - startedAt > RUN_DEADLINE_MS) {
        logger.info('Stopped short of the timeout; the rest wait for the next run');
        return;
      }

      const uid = job.id;
      const claimedAt = job.get('dirtyAt');
      try {
        const result = await recomputeFor(uid, apiKey);
        if (!result.written) {
          // Not an error: the library was bigger than one run's fetch budget,
          // or TMDB refused part of it. What was fetched is cached, so the
          // next run starts closer to the end. The flag is untouched, so the
          // user stays queued.
          logger.info('People scores deferred to the next run', {
            uid,
            titles: result.titles,
          });
          continue;
        }
        await finishJob(job.ref, claimedAt);
        logger.info('Recomputed people scores', {uid, titles: result.titles});
      } catch (error) {
        if (error instanceof CreditsAuthError) {
          // Every user would fail the same way, so stop and make it loud. The
          // flags are all untouched, so nothing is lost once the secret is
          // fixed.
          logger.error('TMDB rejected the API key; abandoning this run', {
            status: error.status,
          });
          return;
        }
        // The flag stays set, so the next run tries again rather than the user
        // being stuck with whatever they had.
        await job.ref.set(
          {lastError: String(error?.message || error)},
          {merge: true},
        );
        logger.warn('Failed to recompute people scores', {
          uid,
          message: error?.message,
        });
      }
    }
  },
);

// Marks a job done, unless the library changed while it was being scored.
//
// The comparison is the whole point: `dirtyAt` moves on every library write,
// so a value that still matches the one this run claimed proves nothing has
// happened since. If it has moved, the flag is left set and the next run
// covers the change.
async function finishJob(ref, claimedAt) {
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(ref);
    const settled = mayClearDirty(claimedAt, current.get('dirtyAt'));
    transaction.set(
      ref,
      {
        ...(settled ? {dirty: false} : {}),
        lastRunAt: FieldValue.serverTimestamp(),
        lastError: null,
      },
      {merge: true},
    );
  });
}

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
