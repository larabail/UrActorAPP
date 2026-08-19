#!/usr/bin/env node
/**
 * Sync Oscar winners from the UrActor API into the Firestore `Oscars` collection.
 *
 * The app (lib/objects/User.dart) reads `Oscars` keyed by tmdb_id, so this job
 * bridges the two shapes: the API is ceremony-indexed and names people with
 * plain strings, while the app needs per-person documents keyed by TMDB id.
 *
 *   API  ->  [{category, nominations:[{primary, secondary, won}]}]
 *   app  ->  Oscars/{tmdb_id} {tmdb_id, imdb_id, name, num_oscars,
 *                              oscars: {"<year>": [{oscar, movie}]}}
 *
 * Only winners are stored; that matches the existing collection and the
 * num_oscars badge count in person_result.dart.
 *
 * Usage:
 *   node sync-oscars.js --year=2026              # dry run, prints a plan
 *   node sync-oscars.js --year=2026 --commit     # actually writes
 *   node sync-oscars.js --all --commit           # every year the API knows
 *
 * Credentials (first match wins):
 *   GCP_ACCESS_TOKEN                 an OAuth access token
 *   GOOGLE_APPLICATION_CREDENTIALS   path to a service-account JSON
 *   gcloud auth print-access-token   whatever gcloud is logged in as
 *
 * Other env:
 *   URACTOR_API_KEY   key for api.uractor.com   (required)
 *   TMDB_API_KEY      key for api.themoviedb.org (required to resolve new people)
 *   FIRESTORE_PROJECT defaults to actordb-cf981
 */

'use strict';

const crypto = require('crypto');
const { execFileSync } = require('child_process');

const PROJECT = process.env.FIRESTORE_PROJECT || 'actordb-cf981';
const API_BASE = 'https://api.uractor.com';
const TMDB_BASE = 'https://api.themoviedb.org/3';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

// ---------------------------------------------------------------- category map

// The API uses expanded names ("Best Achievement in Directing"); the Firestore
// collection uses the Academy's own shorter labels. Anything not listed here is
// skipped, which is how International Feature Film drops out: it credits a
// country and a film, never a person, so it has no place in a per-person doc.
const CATEGORY_MAP = {
  'Best Picture': 'Best Picture',
  'Best Performance by an Actor in a Leading Role': 'Actor in a Leading Role',
  'Best Performance by an Actress in a Leading Role': 'Actress in a Leading Role',
  'Best Performance by an Actor in a Supporting Role': 'Actor in a Supporting Role',
  'Best Performance by an Actress in a Supporting Role': 'Actress in a Supporting Role',
  'Best Achievement in Directing': 'Directing',
  'Best Original Screenplay': 'Original Screenplay',
  'Best Adapted Screenplay': 'Best Adapted Screenplay',
  'Best Achievement in Cinematography': 'Cinematography',
  'Best Achievement in Film Editing': 'Film Editing',
  'Best Achievement in Production Design': 'Production Design',
  'Best Achievement in Costume Design': 'Costume Design',
  'Best Sound': 'Best Sound',
  'Best Achievement in Makeup and Hairstyling': 'Makeup and Hairstyling',
  'Best Achievement in Music Written for Motion Pictures (Original Score)': 'Original Score',
  'Best Achievement in Music Written for Motion Pictures (Original Song)': 'Original Song',
  'Best Achievement in Visual Effects': 'Visual Effects',
  'Best Documentary Feature': 'Documentary Feature',
  'Best Animated Feature Film': 'Animated Feature Film',
  'Best Animated Short Film': 'Animated Short Film',
  'Best Live Action Short Film': 'Live Action Short Film',
  'Best Documentary Short Film': 'Documentary Short Film',
  'Best Achievement in Casting': 'Casting',
};

// For these the honoured person sits in `primary` and the film in `secondary`.
// Everywhere else it is the other way round.
const PERSON_IN_PRIMARY = /^Best (Achievement in Directing|Performance by an)/;

// ---------------------------------------------------------------------- helpers

const arg = (name) => {
  const hit = process.argv.find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return undefined;
  return hit.includes('=') ? hit.slice(hit.indexOf('=') + 1) : true;
};

const die = (msg) => {
  console.error(`error: ${msg}`);
  process.exit(1);
};

async function getJson(url, what) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${what}: HTTP ${res.status}`);
  return res.json();
}

// ------------------------------------------------------------------ credentials

async function accessToken() {
  if (process.env.GCP_ACCESS_TOKEN) return process.env.GCP_ACCESS_TOKEN.trim();

  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath) {
    const key = JSON.parse(require('fs').readFileSync(keyPath, 'utf8'));
    const now = Math.floor(Date.now() / 1000);
    const claim = {
      iss: key.client_email,
      scope: 'https://www.googleapis.com/auth/datastore',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    };
    const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const body = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64(claim)}`;
    const sig = crypto.createSign('RSA-SHA256').update(body).sign(key.private_key, 'base64url');
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${body}.${sig}`,
      }),
    });
    const j = await res.json();
    if (!j.access_token) throw new Error(`service account auth failed: ${JSON.stringify(j)}`);
    return j.access_token;
  }

  try {
    return execFileSync('gcloud', ['auth', 'print-access-token'], { encoding: 'utf8' }).trim();
  } catch {
    throw new Error('no credentials: set GCP_ACCESS_TOKEN or GOOGLE_APPLICATION_CREDENTIALS');
  }
}

// -------------------------------------------------------------- firestore value

const decode = (v) => {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  if ('mapValue' in v) {
    return Object.fromEntries(
      Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)])
    );
  }
  return null;
};

const encode = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  return {
    mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) },
  };
};

// ------------------------------------------------------------------- data loads

async function loadExistingDocs(token) {
  const docs = new Map(); // tmdb_id -> {docId, data}
  const byName = new Map(); // lowercased name -> tmdb_id
  let pageToken = null;

  do {
    const url = `${FS_BASE}/Oscars?pageSize=300${
      pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''
    }`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    const j = await res.json();
    if (j.error) throw new Error(`firestore read: ${j.error.message}`);

    for (const d of j.documents || []) {
      const data = Object.fromEntries(
        Object.entries(d.fields || {}).map(([k, v]) => [k, decode(v)])
      );
      const id = String(data.tmdb_id ?? d.name.split('/').pop());
      docs.set(id, { docId: d.name.split('/').pop(), data });
      if (data.name) byName.set(String(data.name).toLowerCase(), id);
    }
    pageToken = j.nextPageToken;
  } while (pageToken);

  return { docs, byName };
}

/** Flatten one year of API data into per-person award rows. */
function winnersForYear(apiYear, year) {
  const rows = [];
  for (const cat of apiYear) {
    const label = CATEGORY_MAP[cat.category];
    if (!label) continue; // e.g. International Feature Film: no person credited

    for (const nom of cat.nominations) {
      if (!nom.won) continue;
      const personFirst = PERSON_IN_PRIMARY.test(cat.category);
      const people = personFirst ? nom.primary || [] : nom.secondary || [];
      const movie = personFirst ? (nom.secondary || [])[0] : (nom.primary || [])[0];
      if (!movie) continue;
      for (const person of people) rows.push({ year, oscar: label, movie, person });
    }
  }
  return rows;
}

// ------------------------------------------------------------------ tmdb lookup

async function resolvePerson(name, tmdbKey, cache) {
  if (cache.has(name)) return cache.get(name);

  let out = null;
  try {
    const search = await getJson(
      `${TMDB_BASE}/search/person?api_key=${tmdbKey}&query=${encodeURIComponent(name)}`,
      'tmdb search'
    );
    const hit = (search.results || [])[0];
    if (hit) {
      let imdb = null;
      try {
        const ext = await getJson(
          `${TMDB_BASE}/person/${hit.id}/external_ids?api_key=${tmdbKey}`,
          'tmdb external_ids'
        );
        imdb = ext.imdb_id || null;
      } catch {
        /* imdb id is optional */
      }
      out = {
        tmdb_id: hit.id,
        imdb_id: imdb,
        name,
        tmdbName: hit.name,
        exact: hit.name.toLowerCase() === name.toLowerCase(),
        popularity: hit.popularity,
      };
    }
  } catch (e) {
    out = null;
  }

  cache.set(name, out);
  return out;
}

// ------------------------------------------------------------------------- main

(async () => {
  const year = arg('year');
  const all = arg('all');
  const commit = arg('commit') === true;
  if (!year && !all) die('pass --year=YYYY or --all');

  const apiKey = process.env.URACTOR_API_KEY || die('set URACTOR_API_KEY');
  const tmdbKey = process.env.TMDB_API_KEY || die('set TMDB_API_KEY');
  const acceptFuzzy = arg('accept-fuzzy') === true;

  // name -> tmdb_id, or null to skip the person entirely. Hand-curated, because
  // TMDB search cannot be trusted for songwriters and below-the-line crew.
  let overrides = {};
  const overridePath = require('path').join(__dirname, 'overrides.json');
  if (require('fs').existsSync(overridePath)) {
    overrides = JSON.parse(require('fs').readFileSync(overridePath, 'utf8'));
  }

  const token = await accessToken();

  console.log(`project        : ${PROJECT}`);
  console.log(`mode           : ${commit ? 'COMMIT (will write)' : 'dry run'}`);
  console.log(`overrides      : ${Object.keys(overrides).length}`);

  // 1. pull from the API
  const years = {};
  if (all) {
    const data = await getJson(`${API_BASE}/oscars/apikey=${apiKey}`, 'api all');
    Object.assign(years, data);
  } else {
    years[year] = await getJson(`${API_BASE}/oscars/year=${year}/apikey=${apiKey}`, 'api year');
  }
  console.log(`years from API : ${Object.keys(years).sort().join(', ')}`);

  // 2. flatten to award rows
  const rows = [];
  for (const [y, payload] of Object.entries(years)) {
    if (Array.isArray(payload)) rows.push(...winnersForYear(payload, y));
  }
  const people = [...new Set(rows.map((r) => r.person))];
  console.log(`award rows     : ${rows.length} across ${people.length} people\n`);

  // 3. existing collection
  const { docs, byName } = await loadExistingDocs(token);
  console.log(`existing docs  : ${docs.size} (${byName.size} with a name)\n`);

  // 4. resolve every person to a tmdb id
  const cache = new Map();
  const resolved = new Map(); // person -> tmdb_id
  const created = [];
  const unresolved = [];
  const fuzzy = [];
  const skipped = [];

  for (const person of people) {
    // An explicit override always wins; null means "deliberately skip".
    if (Object.prototype.hasOwnProperty.call(overrides, person)) {
      const pinned = overrides[person];
      if (pinned === null) {
        skipped.push(person);
      } else {
        resolved.set(person, String(pinned));
        if (!docs.has(String(pinned))) {
          created.push({ tmdb_id: pinned, imdb_id: null, name: person, pinned: true });
        }
      }
      continue;
    }

    const known = byName.get(person.toLowerCase());
    if (known) {
      resolved.set(person, known);
      continue;
    }

    const hit = await resolvePerson(person, tmdbKey, cache);
    if (!hit) {
      unresolved.push(person);
      continue;
    }

    // A TMDB search will happily return a near-miss. Accepting one silently
    // pins an Oscar on the wrong person in the app, so an inexact hit is only
    // used when explicitly opted into.
    if (!hit.exact && !acceptFuzzy) {
      fuzzy.push(hit);
      continue;
    }

    resolved.set(person, String(hit.tmdb_id));
    created.push(hit);
    if (!hit.exact) fuzzy.push(hit);
  }

  console.log(`resolved       : ${resolved.size}/${people.length}`);
  console.log(`  new via TMDB : ${created.length}`);
  console.log(`  held back    : ${fuzzy.length} inexact`);
  console.log(`  UNRESOLVED   : ${unresolved.length}`);
  console.log(`  skipped      : ${skipped.length} (override null)`);

  if (fuzzy.length) {
    const verb = acceptFuzzy ? 'ACCEPTED (--accept-fuzzy)' : 'held back, not written';
    console.log(`\ninexact TMDB name matches - ${verb}:`);
    for (const f of fuzzy) {
      console.log(`  "${f.name}" -> "${f.tmdbName}" (tmdb ${f.tmdb_id})`);
    }
    if (!acceptFuzzy) {
      console.log('  resolve by adding each to overrides.json as "name": tmdb_id,');
      console.log('  or "name": null to exclude them.');
    }
  }
  if (unresolved.length) {
    console.log('\nno TMDB match at all, skipped:');
    for (const u of unresolved) console.log(`  ${u}`);
  }

  // 5. merge award rows into per-person documents
  const pending = new Map(); // tmdb_id -> doc data

  for (const row of rows) {
    const id = resolved.get(row.person);
    if (!id) continue;

    if (!pending.has(id)) {
      const existing = docs.get(id);
      const base = existing
        ? JSON.parse(JSON.stringify(existing.data))
        : { tmdb_id: Number(id), imdb_id: null, name: row.person, oscars: {} };
      if (!base.oscars) base.oscars = {};
      if (!existing) {
        const meta = created.find((c) => String(c.tmdb_id) === id);
        if (meta) base.imdb_id = meta.imdb_id;
      }
      pending.set(id, base);
    }

    const doc = pending.get(id);
    if (!doc.oscars[row.year]) doc.oscars[row.year] = [];
    const dup = doc.oscars[row.year].some(
      (e) => e.oscar === row.oscar && e.movie === row.movie
    );
    if (!dup) doc.oscars[row.year].push({ oscar: row.oscar, movie: row.movie });
  }

  // num_oscars is the badge count in person_result.dart: total wins, all years.
  for (const doc of pending.values()) {
    doc.num_oscars = Object.values(doc.oscars).reduce((a, list) => a + list.length, 0);
  }

  const newDocs = [...pending.keys()].filter((id) => !docs.has(id));
  console.log(`\ndocuments to write: ${pending.size} (${newDocs.length} new, ${
    pending.size - newDocs.length
  } updated)`);

  if (!commit) {
    console.log('\n--- dry run, sample of what would be written ---');
    for (const [id, doc] of [...pending.entries()].slice(0, 8)) {
      const yrs = Object.keys(doc.oscars).sort();
      const latest = yrs[yrs.length - 1];
      console.log(
        `  ${String(id).padEnd(9)} ${String(doc.name).padEnd(24)} num=${doc.num_oscars} ` +
          `${latest}: ${JSON.stringify(doc.oscars[latest])}`
      );
    }
    console.log('\nre-run with --commit to write.');
    return;
  }

  // 6. write
  let ok = 0;
  let failed = 0;
  for (const [id, doc] of pending) {
    const url = `${FS_BASE}/Oscars/${encodeURIComponent(id)}`;
    const res = await fetch(url, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: Object.fromEntries(Object.entries(doc).map(([k, v]) => [k, encode(v)])),
      }),
    });
    if (res.ok) {
      ok++;
    } else {
      failed++;
      console.error(`  write failed ${id}: HTTP ${res.status} ${await res.text()}`);
    }
  }
  console.log(`\nwrote ${ok} documents, ${failed} failed.`);
})().catch((e) => die(e.message));
