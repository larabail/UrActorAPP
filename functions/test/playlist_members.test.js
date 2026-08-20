'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
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
} = require('../playlist_members');

test('memberUidsFrom pulls every uid out of the single-key maps', () => {
  const users = [{owner: 'Owner'}, {guest: 'Approved'}];
  assert.deepEqual(memberUidsFrom(users), ['guest', 'owner']);
});

test('memberUidsFrom sorts, so sameMembers can compare positionally', () => {
  assert.deepEqual(memberUidsFrom([{b: 'Owner'}, {a: 'Approved'}]), ['a', 'b']);
});

test('memberUidsFrom drops duplicates', () => {
  const users = [{same: 'Owner'}, {same: 'Approved'}];
  assert.deepEqual(memberUidsFrom(users), ['same']);
});

test('memberUidsFrom survives the shapes production actually contains', () => {
  // Documents written by older builds are not guaranteed to be well formed,
  // and a trigger that throws retries forever.
  assert.deepEqual(memberUidsFrom(undefined), []);
  assert.deepEqual(memberUidsFrom(null), []);
  assert.deepEqual(memberUidsFrom('not an array'), []);
  assert.deepEqual(memberUidsFrom([null, undefined, 'text', 42, []]), []);
  assert.deepEqual(memberUidsFrom([{'': 'Owner'}]), []);
});

test('memberUidsFrom handles a map holding more than one uid', () => {
  assert.deepEqual(memberUidsFrom([{a: 'Owner', b: 'Approved'}]), ['a', 'b']);
});

test('sameMembers recognises an unchanged list', () => {
  assert.equal(sameMembers(['a', 'b'], ['a', 'b']), true);
});

test('sameMembers spots additions, removals and reorderings', () => {
  assert.equal(sameMembers(['a'], ['a', 'b']), false);
  assert.equal(sameMembers(['a', 'b'], ['a']), false);
  assert.equal(sameMembers(['a', 'c'], ['a', 'b']), false);
});

test('sameMembers treats a missing field as different from empty', () => {
  // A playlist with no memberUids field must be written once, even though its
  // Users array is empty, otherwise it never becomes queryable.
  assert.equal(sameMembers(undefined, []), false);
  assert.equal(sameMembers([], []), true);
});

test('roleOf finds a role and reports absence as null', () => {
  const users = [{owner: 'Owner'}, {guest: 'Approved'}];
  assert.equal(roleOf(users, 'owner'), 'Owner');
  assert.equal(roleOf(users, 'guest'), 'Approved');
  assert.equal(roleOf(users, 'stranger'), null);
  assert.equal(roleOf(undefined, 'owner'), null);
});

test('roleOf does not match inherited object properties', () => {
  // Object.prototype.hasOwnProperty guards this: a lookup of "constructor"
  // must not report a role.
  assert.equal(roleOf([{owner: 'Owner'}], 'constructor'), null);
  assert.equal(roleOf([{owner: 'Owner'}], 'toString'), null);
});

test('codesMatch accepts an exact code only', () => {
  assert.equal(codesMatch('secret', 'secret'), true);
  assert.equal(codesMatch('secret', 'Secret'), false);
  assert.equal(codesMatch('secret', 'secret '), false);
  assert.equal(codesMatch('secret', 'sec'), false);
  assert.equal(codesMatch(undefined, 'secret'), false);
  assert.equal(codesMatch('secret', undefined), false);
});

test('normalizeJoinRequest trims and accepts a usable request', () => {
  const result = normalizeJoinRequest({name: '  Movies  ', accessCode: ' 42 '});
  assert.deepEqual(result, {ok: true, name: 'Movies', accessCode: '42'});
});

test('normalizeJoinRequest rejects empty and non-string input', () => {
  for (const data of [
    undefined,
    {},
    {name: 'Movies'},
    {accessCode: '42'},
    {name: '   ', accessCode: '42'},
    {name: 'Movies', accessCode: '   '},
    {name: 42, accessCode: '42'},
    {name: 'Movies', accessCode: {}},
  ]) {
    assert.equal(normalizeJoinRequest(data).ok, false, JSON.stringify(data));
  }
});

test('normalizeJoinRequest caps the length of what it will look up', () => {
  const long = 'x'.repeat(MAX_NAME_LENGTH + 1);
  assert.deepEqual(normalizeJoinRequest({name: long, accessCode: '42'}), {
    ok: false,
    reason: 'too-long',
  });
});

test('selectPlaylist returns the list whose code matches', () => {
  const candidates = [
    {id: '1', data: {AccessCode: 'wrong'}},
    {id: '2', data: {AccessCode: 'right'}},
  ];
  assert.equal(selectPlaylist(candidates, 'right').id, '2');
});

test('selectPlaylist returns null when no code matches', () => {
  const candidates = [{id: '1', data: {AccessCode: 'wrong'}}];
  assert.equal(selectPlaylist(candidates, 'right'), null);
  assert.equal(selectPlaylist([], 'right'), null);
});

test('selectPlaylist ignores a list with no access code at all', () => {
  assert.equal(selectPlaylist([{id: '1', data: {}}], ''), null);
});

test('throttleState allows a caller with no history', () => {
  const state = throttleState(undefined, 1000);
  assert.equal(state.blocked, false);
  assert.equal(state.failures, 0);
});

test('throttleState blocks once the limit is reached', () => {
  const now = 1000;
  const under = throttleState({failures: MAX_FAILURES - 1, startedAt: now}, now);
  assert.equal(under.blocked, false);

  const at = throttleState({failures: MAX_FAILURES, startedAt: now}, now);
  assert.equal(at.blocked, true);
});

test('throttleState forgets failures once the window has passed', () => {
  const startedAt = 1000;
  const later = startedAt + FAILURE_WINDOW_MS;
  const state = throttleState({failures: MAX_FAILURES, startedAt}, later);
  assert.equal(state.blocked, false);
  assert.equal(state.failures, 0);
  assert.equal(state.startedAt, later);
});

test('throttleState keeps counting within the window', () => {
  const startedAt = 1000;
  const state = throttleState({failures: 3, startedAt}, startedAt + 60000);
  assert.equal(state.startedAt, startedAt);
  assert.equal(state.failures, 3);
});
