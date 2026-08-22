'use strict';

// Pure helpers for the favourite actor / director / writer scores.
//
// Nothing here touches firebase-admin or the network, so it can be unit
// tested directly. index.js holds the parts that need Firestore and TMDB.
//
// The scores used to be computed the other way round: opening a person's page
// fetched THEIR filmography, intersected it with the viewer's library, and
// wrote the result. That made the ranking a record of whose page you had
// opened rather than what you had watched -- someone you never tapped never
// appeared at all, and a score stayed frozen at the moment of your last visit
// however much of their work you saw afterwards.
//
// Here it runs the other way: walk the viewer's OWN library, look up each
// title's credits, and add that title's points to everyone it credits. Every
// person who could possibly rank is reached, because every title that could
// credit them is visited, so the ranking is complete by construction and no
// longer depends on anybody being tapped.

// The per-user documents whose contents can change a score. A write to any of
// them marks the user dirty; a write to anything else is ignored, which keeps
// the trigger off the hot path of unrelated writes like Calendar or Settings.
//
// `Seen` is deliberately absent even though it also lists watched titles: it
// is a mirror of Movies/TVShows and is always written alongside them, so
// including it would only ever mark a user dirty who is already dirty.
const LIBRARY_DOCS = [
  'Movies',
  'TVShows',
  'Favorites',
  'Watchlist',
  'Rewatched',
  'RewatchedTV',
];

// Every user owns a top-level collection named after their uid, so a trigger
// on `{uid}/{docId}` also fires for the collections that are shared rather
// than owned. No uid can equal one of these names, so skipping them by name
// is safe, and it stops a title's cached credits or a job record from being
// mistaken for somebody's library.
const SHARED_COLLECTIONS = [
  'Oscars',
  'usernames',
  'Watchlists',
  'JoinAttempts',
  'Credits',
  'PeopleScoreJobs',
];

const MEDIA_TYPES = ['Movies', 'TVShows'];

// How far down a title's billing the cast is counted.
//
// TMDB lists everyone, down to the uncredited extras, and someone billed
// hundredth in a film you happened to watch is not a favourite actor of yours.
// Billing order is TMDB's own, so cutting the list keeps the people a viewer
// would recognise. It also keeps a cached credits document to a few hundred
// bytes rather than tens of kilobytes.
//
// This is the one thing the person page counts and the server does not: the
// page works from a person's own filmography, which carries no billing for the
// films in it, so a character actor can read a point or two higher on their
// own page than in the profile list. Both numbers are honest about what they
// measured; only the cheap one can be stored for everybody.
const MAX_CAST_PER_TITLE = 20;

// How many people are kept per role. Far more than the profile shows (10) or
// than a person page needs to state a rank, and small enough that the
// document stays a few kilobytes whatever the size of the library -- which is
// what keeps it under Firestore's 1 MiB limit for a viewer with thousands of
// titles.
const MAX_RANKED_PEOPLE = 500;

// Characters that mean the person appeared as themselves or was not really in
// the finished film. The person page has always excluded these from a
// filmography and they should not earn anyone a score either.
const IGNORED_CHARACTER_MARKERS = ['self', 'archived', 'uncredited'];

const WRITER_JOBS = ['Writer', 'Screenplay'];

// Statuses that mean the title itself is the problem, so asking again will
// never help. Old libraries are full of ids TMDB no longer recognises.
const PERMANENT_CREDIT_STATUSES = [400, 404, 410, 422];

// A rejected key is not the title's fault. Caching it as one would write off
// every title in the database over a misconfigured secret, so it is treated as
// a configuration failure that stops the run instead.
const AUTH_CREDIT_STATUSES = [401, 403];

// How many times a title may fail temporarily before it is written off.
//
// Nothing is written for a user until every one of their titles resolves, so
// without a limit a single id that always answers 500 would defer that user on
// every run forever and their scores would never appear at all.
const MAX_CREDIT_ATTEMPTS = 5;

// Where credits are fetched from. Overridable so the emulator tests can stand
// a stub in front of it; nothing in production sets it.
const TMDB_BASE_URL =
  process.env.TMDB_API_BASE_URL || 'https://api.themoviedb.org/3';

// How a failed credits request should be treated.
//
// `auth` stops the whole run, `permanent` writes the title off immediately,
// and `temporary` is retried -- but only so many times, which is what
// creditAttemptOutcome decides.
function creditFailureKind(status) {
  if (AUTH_CREDIT_STATUSES.includes(status)) return 'auth';
  if (PERMANENT_CREDIT_STATUSES.includes(status)) return 'permanent';
  return 'temporary';
}

// What to record after a title has failed temporarily. Returns the new attempt
// count and whether this was the last chance.
function creditAttemptOutcome(previousAttempts) {
  const attempts = (Number.isFinite(previousAttempts) ? previousAttempts : 0) + 1;
  return {attempts, writeOff: attempts >= MAX_CREDIT_ATTEMPTS};
}

// Whether a finished recompute may clear the user's dirty flag.
//
// The flag is only cleared when nothing has re-flagged the user since the run
// claimed them. A library write that lands mid-run moves `dirtyAt`, and
// clearing on the strength of a stale claim would drop it: the scores would
// silently stay one film out of date until something else happened to change.
//
// Both arguments are Firestore Timestamps, or null when the field is absent.
function mayClearDirty(claimedAt, currentAt) {
  if (!claimedAt || !currentAt) return false;
  return claimedAt.isEqual(currentAt);
}

// True when a write to `collectionId/docId` could change someone's scores.
function isLibraryWrite(collectionId, docId) {
  if (typeof collectionId !== 'string' || collectionId === '') return false;
  if (SHARED_COLLECTIONS.includes(collectionId)) return false;
  return LIBRARY_DOCS.includes(docId);
}

// Firestore stores media ids as strings in some documents and numbers in
// others, depending on which build wrote them. Everything here compares them
// as strings so the two shapes cannot silently fail to match.
function idsFrom(value) {
  if (!Array.isArray(value)) return [];
  const ids = [];
  for (const entry of value) {
    if (entry === null || entry === undefined) continue;
    const id = String(entry);
    if (id !== '' && !ids.includes(id)) ids.push(id);
  }
  return ids;
}

function countsFrom(value) {
  const counts = {};
  if (!value || typeof value !== 'object' || Array.isArray(value)) return counts;
  for (const [key, count] of Object.entries(value)) {
    if (typeof count === 'number' && Number.isFinite(count)) {
      counts[String(key)] = count;
    }
  }
  return counts;
}

// A user's library, reduced to the four facts that decide a title's points.
//
// `docs` is the user's documents keyed by id, exactly as they come out of
// Firestore. Missing documents are normal -- a user who has never used the
// watchlist has no Watchlist document -- so anything absent reads as empty.
function libraryFrom(docs) {
  const source = docs && typeof docs === 'object' ? docs : {};
  const favourites = source.Favorites || {};
  const watchlist = source.Watchlist || {};

  return {
    Movies: {
      seen: idsFrom((source.Movies || {}).Seen),
      favourites: idsFrom(favourites.Movies),
      watchlist: idsFrom(watchlist.Movies),
      rewatched: countsFrom(source.Rewatched),
    },
    TVShows: {
      seen: idsFrom((source.TVShows || {}).Seen),
      favourites: idsFrom(favourites.TVShows),
      watchlist: idsFrom(watchlist.TVShows),
      rewatched: countsFrom(source.RewatchedTV),
    },
  };
}

// Every title in the library that can score, seen ones first.
//
// A title can appear in both the seen list and the watchlist -- nothing
// removes it from the watchlist when it is marked seen -- and the two award
// different points, so it has to be counted once, as seen.
function scorableTitles(entry) {
  const titles = [];
  for (const id of entry.seen) titles.push(id);
  for (const id of entry.watchlist) {
    if (!titles.includes(id)) titles.push(id);
  }
  return titles;
}

// What one title is worth to everyone it credits.
//
// These weights are the ones the person page has always used, kept identical
// so moving the computation off the person page does not silently reshuffle
// anybody's ranking on top of correcting it.
//
// A rewatch counter below 2 still scores 2: the counter is only written when a
// title is logged a second time, so a 1 there means the same single viewing
// that an absent counter means.
function titleScore({seen, favourite, rewatchCount, onWatchlist}) {
  if (seen) {
    const base = rewatchCount > 1 ? rewatchCount : 2;
    return favourite ? base + 3 : base;
  }
  return onWatchlist ? 1 : 0;
}

function scoreForTitle(entry, id) {
  const seen = entry.seen.includes(id);
  return titleScore({
    seen,
    favourite: entry.favourites.includes(id),
    rewatchCount: entry.rewatched[id],
    onWatchlist: !seen && entry.watchlist.includes(id),
  });
}

function characterIsIgnored(character) {
  const value = String(character === null || character === undefined ? '' : character)
    .toLowerCase();
  if (value === '') return true;
  return IGNORED_CHARACTER_MARKERS.some((marker) => value.includes(marker));
}

// The jobs a crew entry covers.
//
// `/movie/{id}/credits` gives one entry per job, with the job on the entry.
// `/tv/{id}/aggregate_credits` gives one entry per person, with a `jobs` array
// -- the aggregate endpoint is the only one that answers for a show's whole
// run rather than its newest season, so both shapes have to be read here.
function jobsOf(entry) {
  if (Array.isArray(entry.jobs)) {
    return entry.jobs
      .filter((job) => job && typeof job === 'object')
      .map((job) => job.job);
  }
  return [entry.job];
}

// Likewise for cast: `/credits` puts the character on the entry, while
// `/aggregate_credits` puts one entry per person with a `roles` array. A
// person counts if ANY of their roles is a real one, so an actor who also
// turned up as themselves in a later season is not thrown away.
function charactersOf(entry) {
  if (Array.isArray(entry.roles)) {
    return entry.roles
      .filter((role) => role && typeof role === 'object')
      .map((role) => role.character);
  }
  return [entry.character];
}

function pushUnique(ids, value) {
  if (value === null || value === undefined) return;
  const id = String(value);
  if (id !== '' && !ids.includes(id)) ids.push(id);
}

// A TMDB credits payload reduced to the three id lists a score needs.
//
// Storing this rather than the raw response is what makes the cache worth
// having: a response is tens of kilobytes of biographies and artwork paths,
// and this is a few hundred bytes of ids that never change once a title has
// been released.
function trimCredits(payload) {
  const source = payload && typeof payload === 'object' ? payload : {};
  const cast = [];
  const directors = [];
  const writers = [];

  const castEntries = Array.isArray(source.cast) ? source.cast : [];
  for (const entry of castEntries) {
    if (!entry || typeof entry !== 'object') continue;
    if (cast.length >= MAX_CAST_PER_TITLE) break;
    if (charactersOf(entry).every(characterIsIgnored)) continue;
    pushUnique(cast, entry.id);
  }

  const crewEntries = Array.isArray(source.crew) ? source.crew : [];
  for (const entry of crewEntries) {
    if (!entry || typeof entry !== 'object') continue;
    const jobs = jobsOf(entry);
    if (jobs.includes('Director')) pushUnique(directors, entry.id);
    if (jobs.some((job) => WRITER_JOBS.includes(job))) {
      pushUnique(writers, entry.id);
    }
  }

  return {cast, directors, writers};
}

function creditsKey(type, id) {
  return `${type}_${id}`;
}

// TMDB answers `/tv/{id}/credits` with the newest season's regular cast only,
// so a long running show comes back with a handful of people and everyone who
// left missing. The aggregate endpoint covers every season instead, at the
// cost of the different response shape that jobsOf/charactersOf absorb.
//
// [baseUrl] exists so the emulator tests can point this at a stub rather than
// calling the real, rate-limited TMDB from CI.
function buildCreditsUrl(type, id, apiKey, baseUrl = TMDB_BASE_URL) {
  const path = type === 'Movies' ?
    `movie/${encodeURIComponent(id)}/credits` :
    `tv/${encodeURIComponent(id)}/aggregate_credits`;
  const url = new URL(`${baseUrl.replace(/\/+$/, '')}/${path}`);
  url.searchParams.set('api_key', apiKey);
  return url.toString();
}

function addScore(totals, ids, points) {
  // A cached credits document is data, and data can be older than the code
  // that reads it. One malformed entry must not take down a whole recompute.
  if (!Array.isArray(ids)) return;
  for (const id of ids) {
    totals[id] = (totals[id] || 0) + points;
  }
}

// Keeps the highest scores and drops the rest, so a document cannot grow past
// what Firestore will store. Ties break on id to make the result stable:
// without it two runs over identical data could keep different people and the
// profile would reshuffle for no reason.
function topScores(totals, limit = MAX_RANKED_PEOPLE) {
  const ranked = Object.entries(totals)
    .filter(([, score]) => score > 0)
    .sort((a, b) => (b[1] - a[1]) || a[0].localeCompare(b[0]))
    .slice(0, limit);
  return Object.fromEntries(ranked);
}

// The whole computation: a library plus a way to look up any title's credits,
// in, three id-to-score maps out.
//
// `creditsFor(type, id)` returns a trimmed credits object or null. A null is
// not an error -- TMDB does not know every id a client has ever written, and a
// title nobody can resolve simply scores nobody rather than failing the run.
function scoreLibrary(library, creditsFor) {
  const actors = {};
  const directors = {};
  const writers = {};

  for (const type of MEDIA_TYPES) {
    const entry = library[type];
    if (!entry) continue;
    for (const id of scorableTitles(entry)) {
      const points = scoreForTitle(entry, id);
      if (points <= 0) continue;
      const credits = creditsFor(type, id);
      if (!credits) continue;
      addScore(actors, credits.cast, points);
      addScore(directors, credits.directors, points);
      addScore(writers, credits.writers, points);
    }
  }

  return {
    FavActors: topScores(actors),
    FavDirectors: topScores(directors),
    FavWriters: topScores(writers),
  };
}

// Every title the library needs credits for, as `{type, id}` pairs. index.js
// uses this to decide what to read from the cache and what to fetch.
function titlesNeedingCredits(library) {
  const titles = [];
  for (const type of MEDIA_TYPES) {
    const entry = library[type];
    if (!entry) continue;
    for (const id of scorableTitles(entry)) {
      if (scoreForTitle(entry, id) > 0) titles.push({type, id});
    }
  }
  return titles;
}

// A cached credits document only counts as an answer once it holds one. A
// record left behind by a failed attempt carries an attempt count and no cast,
// and has to be fetched again rather than read as a title with nobody in it.
function cachedCreditsFrom(data) {
  if (!data || typeof data !== 'object') return undefined;
  if (data.missing) return null;
  if (!Array.isArray(data.cast)) return undefined;
  return data;
}

module.exports = {
  LIBRARY_DOCS,
  SHARED_COLLECTIONS,
  MEDIA_TYPES,
  MAX_CAST_PER_TITLE,
  MAX_RANKED_PEOPLE,
  MAX_CREDIT_ATTEMPTS,
  TMDB_BASE_URL,
  isLibraryWrite,
  libraryFrom,
  titleScore,
  scoreForTitle,
  scorableTitles,
  trimCredits,
  creditsKey,
  buildCreditsUrl,
  creditFailureKind,
  creditAttemptOutcome,
  mayClearDirty,
  cachedCreditsFrom,
  topScores,
  scoreLibrary,
  titlesNeedingCredits,
};
