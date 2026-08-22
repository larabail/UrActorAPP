'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MAX_CAST_PER_TITLE,
  MAX_CREDIT_ATTEMPTS,
  MAX_RANKED_PEOPLE,
  TMDB_BASE_URL,
  creditFailureKind,
  creditAttemptOutcome,
  mayClearDirty,
  runIsIncomplete,
  cachedCreditsFrom,
  isLibraryWrite,
  libraryFrom,
  titleScore,
  scoreForTitle,
  scorableTitles,
  trimCredits,
  buildCreditsUrl,
  topScores,
  scoreLibrary,
  titlesNeedingCredits,
} = require('../people_scores');

test('isLibraryWrite accepts the documents that change a score', () => {
  for (const docId of ['Movies', 'TVShows', 'Favorites', 'Watchlist',
    'Rewatched', 'RewatchedTV']) {
    assert.equal(isLibraryWrite('user-1', docId), true, docId);
  }
});

test('isLibraryWrite ignores unrelated per-user documents', () => {
  for (const docId of ['Settings', 'Calendar', 'Notifications', 'Progress',
    'Reviews', 'Friends', 'Seen']) {
    assert.equal(isLibraryWrite('user-1', docId), false, docId);
  }
});

test('isLibraryWrite ignores the shared collections', () => {
  // A trigger on {uid}/{docId} also fires for these, and Watchlists in
  // particular is one character away from the per-user Watchlist document.
  assert.equal(isLibraryWrite('Watchlists', 'Movies'), false);
  assert.equal(isLibraryWrite('Credits', 'Movies'), false);
  assert.equal(isLibraryWrite('PeopleScoreJobs', 'Movies'), false);
  assert.equal(isLibraryWrite('Oscars', 'Movies'), false);
  assert.equal(isLibraryWrite('', 'Movies'), false);
});

test('libraryFrom reads a full set of documents', () => {
  const library = libraryFrom({
    Movies: {Seen: ['550', '807']},
    TVShows: {Seen: ['1396']},
    Favorites: {Movies: ['550'], TVShows: ['1396']},
    Watchlist: {Movies: ['13'], TVShows: ['1399']},
    Rewatched: {550: 4},
    RewatchedTV: {1396: 2},
  });

  assert.deepEqual(library.Movies.seen, ['550', '807']);
  assert.deepEqual(library.Movies.favourites, ['550']);
  assert.deepEqual(library.Movies.watchlist, ['13']);
  assert.deepEqual(library.Movies.rewatched, {550: 4});
  assert.deepEqual(library.TVShows.seen, ['1396']);
  assert.deepEqual(library.TVShows.watchlist, ['1399']);
  assert.deepEqual(library.TVShows.rewatched, {1396: 2});
});

test('libraryFrom treats missing documents as empty', () => {
  // A user who has never opened the watchlist has no Watchlist document, so
  // absent has to read as empty rather than throwing mid-recompute.
  const library = libraryFrom({});
  assert.deepEqual(library.Movies.seen, []);
  assert.deepEqual(library.TVShows.watchlist, []);
  assert.deepEqual(library.Movies.rewatched, {});

  const missing = libraryFrom(undefined);
  assert.deepEqual(missing.Movies.seen, []);
});

test('libraryFrom normalises ids written as numbers', () => {
  // Different builds have written ids as strings and as numbers; comparing
  // them as anything but strings silently fails to match.
  const library = libraryFrom({
    Movies: {Seen: [550, '807', 550]},
    Favorites: {Movies: [550]},
  });
  assert.deepEqual(library.Movies.seen, ['550', '807']);
  assert.deepEqual(library.Movies.favourites, ['550']);
});

test('titleScore matches the weights the person page has always used', () => {
  assert.equal(titleScore({seen: true}), 2);
  assert.equal(titleScore({seen: true, favourite: true}), 5);
  assert.equal(titleScore({seen: true, rewatchCount: 4}), 4);
  assert.equal(titleScore({seen: true, rewatchCount: 4, favourite: true}), 7);
  assert.equal(titleScore({seen: false, onWatchlist: true}), 1);
  assert.equal(titleScore({seen: false}), 0);
});

test('titleScore floors a rewatch counter of one at a single viewing', () => {
  // The counter only appears once a title is logged twice, so a 1 means the
  // same one viewing an absent counter means.
  assert.equal(titleScore({seen: true, rewatchCount: 1}), 2);
  assert.equal(titleScore({seen: true, rewatchCount: 0}), 2);
});

test('a seen title on the watchlist scores as seen, not as a watchlist item', () => {
  // Marking a title seen does not take it off the watchlist, so the two lists
  // overlap and the title must not be counted twice.
  const entry = libraryFrom({
    Movies: {Seen: ['550']},
    Watchlist: {Movies: ['550']},
  }).Movies;

  assert.deepEqual(scorableTitles(entry), ['550']);
  assert.equal(scoreForTitle(entry, '550'), 2);
});

test('trimCredits reads a movie credits payload', () => {
  const credits = trimCredits({
    cast: [
      {id: 819, character: 'The Narrator'},
      {id: 287, character: 'Tyler Durden'},
    ],
    crew: [
      {id: 7467, job: 'Director'},
      {id: 7469, job: 'Screenplay'},
      {id: 7474, job: 'Thanks'},
    ],
  });

  assert.deepEqual(credits.cast, ['819', '287']);
  assert.deepEqual(credits.directors, ['7467']);
  assert.deepEqual(credits.writers, ['7469']);
});

test('trimCredits reads an aggregate credits payload for a show', () => {
  // /tv/{id}/aggregate_credits nests roles and jobs instead of putting one on
  // each entry, and it is the only endpoint that covers every season.
  const credits = trimCredits({
    cast: [
      {id: 17419, roles: [{character: 'Walter White'}]},
      {id: 84497, roles: [{character: 'Jesse Pinkman'}]},
    ],
    crew: [
      {id: 66633, jobs: [{job: 'Director'}, {job: 'Writer'}]},
    ],
  });

  assert.deepEqual(credits.cast, ['17419', '84497']);
  assert.deepEqual(credits.directors, ['66633']);
  assert.deepEqual(credits.writers, ['66633']);
});

test('trimCredits drops people credited as themselves or not really there', () => {
  const credits = trimCredits({
    cast: [
      {id: 1, character: 'Self'},
      {id: 2, character: 'Herself - Archived Footage'},
      {id: 3, character: 'Bystander (uncredited)'},
      {id: 4, character: ''},
      {id: 5},
      {id: 6, character: 'Ripley'},
    ],
    crew: [],
  });

  assert.deepEqual(credits.cast, ['6']);
});

test('trimCredits keeps an actor who also appeared as themselves', () => {
  // On a long show a regular can pick up a "Self" role in a later season; the
  // real part is what matters.
  const credits = trimCredits({
    cast: [
      {id: 7, roles: [{character: 'Self'}, {character: 'Dana Scully'}]},
    ],
    crew: [],
  });

  assert.deepEqual(credits.cast, ['7']);
});

test('trimCredits caps the cast at the top of the billing', () => {
  // Someone billed hundredth in a film you happened to watch is not a
  // favourite actor of yours, and TMDB lists them all.
  const cast = [];
  for (let i = 0; i < MAX_CAST_PER_TITLE + 25; i++) {
    cast.push({id: i, character: `Role ${i}`});
  }

  const credits = trimCredits({cast, crew: []});
  assert.equal(credits.cast.length, MAX_CAST_PER_TITLE);
  assert.equal(credits.cast[0], '0');
});

test('trimCredits survives a payload TMDB never sent', () => {
  assert.deepEqual(trimCredits(null), {cast: [], directors: [], writers: []});
  assert.deepEqual(trimCredits({}), {cast: [], directors: [], writers: []});
  assert.deepEqual(
    trimCredits({cast: 'nope', crew: [null, 3, {}]}),
    {cast: [], directors: [], writers: []},
  );
});

test('buildCreditsUrl asks for aggregate credits only for shows', () => {
  // /tv/{id}/credits answers with the newest season alone, so a long running
  // show would come back missing everyone who left.
  assert.equal(
    buildCreditsUrl('Movies', '550', 'key', 'https://api.themoviedb.org/3'),
    'https://api.themoviedb.org/3/movie/550/credits?api_key=key',
  );
  assert.equal(
    buildCreditsUrl('TVShows', '1396', 'key', 'https://api.themoviedb.org/3'),
    'https://api.themoviedb.org/3/tv/1396/aggregate_credits?api_key=key',
  );
});

test('buildCreditsUrl can be pointed at a stub', () => {
  assert.equal(
    buildCreditsUrl('Movies', '550', 'key', 'http://127.0.0.1:5099/3/'),
    'http://127.0.0.1:5099/3/movie/550/credits?api_key=key',
  );
});

test('buildCreditsUrl defaults to TMDB', () => {
  assert.ok(buildCreditsUrl('Movies', '550', 'key').startsWith(TMDB_BASE_URL));
});

test('topScores keeps the highest and breaks ties stably', () => {
  const kept = topScores({a: 1, b: 9, c: 5, d: 9}, 3);
  assert.deepEqual(Object.keys(kept), ['b', 'd', 'c']);
});

test('topScores drops anyone who scored nothing', () => {
  assert.deepEqual(topScores({a: 0, b: 3}), {b: 3});
});

test('scoreLibrary tallies every title in the library', () => {
  const library = libraryFrom({
    Movies: {Seen: ['550', '807']},
    Favorites: {Movies: ['550']},
    Watchlist: {Movies: ['13']},
    Rewatched: {807: 3},
  });

  const credits = {
    Movies_550: {cast: ['287'], directors: ['7467'], writers: ['7469']},
    Movies_807: {cast: ['287'], directors: ['7467'], writers: []},
    Movies_13: {cast: ['287'], directors: ['1'], writers: []},
  };

  const scores = scoreLibrary(library, (type, id) => credits[`${type}_${id}`]);

  // 550 seen and favourited (5) + 807 seen three times (3) + 13 on the
  // watchlist (1).
  assert.equal(scores.FavActors['287'], 9);
  assert.equal(scores.FavDirectors['7467'], 8);
  assert.equal(scores.FavDirectors['1'], 1);
  assert.equal(scores.FavWriters['7469'], 5);
});

test('scoreLibrary counts someone once per title however they are credited', () => {
  // A writer-director earns their title's points once in each role, not twice
  // in either.
  const library = libraryFrom({Movies: {Seen: ['550']}});
  const scores = scoreLibrary(library, () => ({
    cast: ['7467'],
    directors: ['7467'],
    writers: ['7467'],
  }));

  assert.equal(scores.FavActors['7467'], 2);
  assert.equal(scores.FavDirectors['7467'], 2);
  assert.equal(scores.FavWriters['7467'], 2);
});

test('scoreLibrary adds movie and show scores for the same person', () => {
  const library = libraryFrom({
    Movies: {Seen: ['550']},
    TVShows: {Seen: ['1396']},
  });
  const scores = scoreLibrary(library, () => ({
    cast: ['17419'],
    directors: [],
    writers: [],
  }));

  assert.equal(scores.FavActors['17419'], 4);
});

test('scoreLibrary skips a title whose credits cannot be resolved', () => {
  // TMDB does not know every id a client has ever written. One unresolvable
  // title must not take the whole run down with it.
  const library = libraryFrom({Movies: {Seen: ['550', '99999999']}});
  const credits = {Movies_550: {cast: ['287'], directors: [], writers: []}};

  const scores = scoreLibrary(library, (type, id) => credits[`${type}_${id}`] || null);
  assert.deepEqual(scores.FavActors, {287: 2});
});

test('scoreLibrary survives a cached credits document missing a role', () => {
  // The cache is data, and data can outlive the shape the code expects. One
  // malformed document must not take a whole recompute down.
  const library = libraryFrom({Movies: {Seen: ['550']}});
  const scores = scoreLibrary(library, () => ({cast: ['287']}));

  assert.deepEqual(scores.FavActors, {287: 2});
  assert.deepEqual(scores.FavDirectors, {});
});

test('scoreLibrary returns nothing for an empty library', () => {
  const scores = scoreLibrary(libraryFrom({}), () => null);
  assert.deepEqual(scores, {FavActors: {}, FavDirectors: {}, FavWriters: {}});
});

test('titlesNeedingCredits lists every scoring title once', () => {
  const library = libraryFrom({
    Movies: {Seen: ['550']},
    TVShows: {Seen: ['1396']},
    Watchlist: {Movies: ['550', '13']},
  });

  assert.deepEqual(titlesNeedingCredits(library), [
    {type: 'Movies', id: '550'},
    {type: 'Movies', id: '13'},
    {type: 'TVShows', id: '1396'},
  ]);
});

test('creditFailureKind separates a bad key from a bad title', () => {
  // Caching a rejected key as "this title does not exist" would write off the
  // whole database over a misconfigured secret.
  assert.equal(creditFailureKind(401), 'auth');
  assert.equal(creditFailureKind(403), 'auth');
  assert.equal(creditFailureKind(404), 'permanent');
  assert.equal(creditFailureKind(410), 'permanent');
  assert.equal(creditFailureKind(422), 'permanent');
  assert.equal(creditFailureKind(429), 'temporary');
  assert.equal(creditFailureKind(500), 'temporary');
  assert.equal(creditFailureKind(503), 'temporary');
});

test('creditAttemptOutcome gives up eventually', () => {
  // Nothing is written for a user until every title resolves, so one id that
  // always answers 500 would otherwise defer them forever.
  assert.deepEqual(creditAttemptOutcome(undefined), {attempts: 1, writeOff: false});
  assert.deepEqual(creditAttemptOutcome(0), {attempts: 1, writeOff: false});
  assert.deepEqual(
    creditAttemptOutcome(MAX_CREDIT_ATTEMPTS - 2),
    {attempts: MAX_CREDIT_ATTEMPTS - 1, writeOff: false},
  );
  assert.deepEqual(
    creditAttemptOutcome(MAX_CREDIT_ATTEMPTS - 1),
    {attempts: MAX_CREDIT_ATTEMPTS, writeOff: true},
  );
});

test('creditAttemptOutcome ignores a corrupt counter', () => {
  assert.deepEqual(creditAttemptOutcome('lots'), {attempts: 1, writeOff: false});
  assert.deepEqual(creditAttemptOutcome(null), {attempts: 1, writeOff: false});
});

test('mayClearDirty only clears an uncontested claim', () => {
  const at = (millis) => ({
    isEqual: (other) => Boolean(other) && other.millis === millis,
    millis,
  });

  assert.equal(mayClearDirty(at(10), at(10)), true);
  // A library write landed mid-run. Clearing here would drop it and serve a
  // ranking one film out of date until something else changed.
  assert.equal(mayClearDirty(at(10), at(20)), false);
  assert.equal(mayClearDirty(at(10), null), false);
  assert.equal(mayClearDirty(null, at(10)), false);
});

test('cachedCreditsFrom tells an answer from a failed attempt', () => {
  const credits = {cast: ['1'], directors: [], writers: []};
  assert.equal(cachedCreditsFrom(credits), credits);

  // A title TMDB does not know: an answer, and the answer is nobody.
  assert.equal(cachedCreditsFrom({missing: true}), null);

  // A record left by a failed attempt has to be fetched again, not read as a
  // title with nobody in it.
  assert.equal(cachedCreditsFrom({attempts: 2}), undefined);
  assert.equal(cachedCreditsFrom({}), undefined);
  assert.equal(cachedCreditsFrom(null), undefined);
});

test('topScores keeps a library-sized ranking, not a profile-sized one', () => {
  // A dry run against a real 4,593 title library credited 42,683 actors with a
  // non-zero score. Storing them all is about 630 KB in a document Firestore
  // caps at 1 MiB, so a limit is not optional -- but the limit is also what
  // decides where the person page's ranking goes flat, and at 500 it was
  // cutting people who had been watched a dozen times.
  const totals = {};
  for (let i = 0; i < MAX_RANKED_PEOPLE + 500; i++) {
    totals[`p${i}`] = MAX_RANKED_PEOPLE + 500 - i;
  }

  const kept = topScores(totals);
  assert.equal(Object.keys(kept).length, MAX_RANKED_PEOPLE);
  assert.ok(MAX_RANKED_PEOPLE >= 2000, 'the cut must stay below a real ranking');
  assert.equal(kept.p0, MAX_RANKED_PEOPLE + 500, 'kept the best');
  assert.equal(kept[`p${MAX_RANKED_PEOPLE}`], undefined, 'dropped past the cut');
});

test('runIsIncomplete treats a run that stopped early as unfinished', () => {
  assert.equal(runIsIncomplete(100, 100, 0), false, 'all attempted, none failed');

  // The deadline cut it off. Everything attempted worked, but the rest was
  // never asked about, so storing now would rank a part of the library.
  assert.equal(runIsIncomplete(100, 40, 0), true);

  // attempted advances a batch at a time, so it can overshoot the total.
  assert.equal(runIsIncomplete(100, 104, 0), false);

  assert.equal(runIsIncomplete(100, 100, 1), true, 'one title would not resolve');
});
