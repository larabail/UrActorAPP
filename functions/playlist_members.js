'use strict';

// Pure helpers for playlist membership.
//
// Nothing here touches firebase-admin or the network, so it can be unit
// tested directly. index.js holds the parts that need Firestore.

// A playlist's `Users` field is a list of single-key maps, each mapping a uid
// to a role: [{uidA: "Owner"}, {uidB: "Approved"}]. That shape cannot be
// queried -- `arrayContains` needs the whole element, and the role is part of
// the element, so you cannot ask "is this uid in here" without already knowing
// their role. `memberUids` is the flat, queryable projection of it.
function memberUidsFrom(users) {
  if (!Array.isArray(users)) return [];

  const uids = [];
  for (const entry of users) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) continue;
    for (const uid of Object.keys(entry)) {
      if (typeof uid === 'string' && uid !== '' && !uids.includes(uid)) {
        uids.push(uid);
      }
    }
  }
  return uids.sort();
}

// The trigger writes memberUids, which retriggers the trigger. This is what
// stops that from looping forever.
function sameMembers(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  return a.every((value, index) => value === b[index]);
}

function roleOf(users, uid) {
  if (!Array.isArray(users)) return null;
  for (const entry of users) {
    if (entry && typeof entry === 'object' && !Array.isArray(entry)) {
      if (Object.prototype.hasOwnProperty.call(entry, uid)) return entry[uid];
    }
  }
  return null;
}

// Compared with `timingSafeEqual` semantics in mind: always walk the whole
// string so the time taken does not tell an attacker how many leading
// characters they guessed correctly.
function codesMatch(expected, supplied) {
  if (typeof expected !== 'string' || typeof supplied !== 'string') return false;
  if (expected.length !== supplied.length) return false;

  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  }
  return difference === 0;
}

const MAX_NAME_LENGTH = 200;
const MAX_CODE_LENGTH = 200;

function normalizeJoinRequest(data) {
  const name = typeof data?.name === 'string' ? data.name.trim() : '';
  const accessCode =
    typeof data?.accessCode === 'string' ? data.accessCode.trim() : '';

  if (name === '' || accessCode === '') {
    return { ok: false, reason: 'missing' };
  }
  if (name.length > MAX_NAME_LENGTH || accessCode.length > MAX_CODE_LENGTH) {
    return { ok: false, reason: 'too-long' };
  }
  return { ok: true, name, accessCode };
}

// `candidates` is [{id, data}]. Returns the first playlist whose access code
// matches, so a wrong code is indistinguishable from a wrong name.
function selectPlaylist(candidates, accessCode) {
  for (const candidate of candidates) {
    if (codesMatch(candidate.data?.AccessCode, accessCode)) return candidate;
  }
  return null;
}

const MAX_FAILURES = 10;
const FAILURE_WINDOW_MS = 60 * 60 * 1000;

// Without this a callable is a free brute-force oracle: the whole point of
// moving the check server side is that guesses become countable.
function throttleState(record, now) {
  const startedAt = typeof record?.startedAt === 'number' ? record.startedAt : 0;
  const failures = typeof record?.failures === 'number' ? record.failures : 0;

  if (now - startedAt >= FAILURE_WINDOW_MS) {
    return { blocked: false, failures: 0, startedAt: now };
  }
  return { blocked: failures >= MAX_FAILURES, failures, startedAt };
}

module.exports = {
  memberUidsFrom,
  sameMembers,
  roleOf,
  codesMatch,
  normalizeJoinRequest,
  selectPlaylist,
  throttleState,
  MAX_FAILURES,
  FAILURE_WINDOW_MS,
  MAX_NAME_LENGTH,
  MAX_CODE_LENGTH,
};
