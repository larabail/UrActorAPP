'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeImdbId,
  buildOmdbUrl,
  trimOmdbResponse,
} = require('../omdb');

test('normalizeImdbId accepts a well formed IMDb title id', () => {
  assert.deepEqual(normalizeImdbId('tt1375666'), {ok: true, id: 'tt1375666'});
  assert.deepEqual(normalizeImdbId(' tt1234567890 '), {
    ok: true,
    id: 'tt1234567890',
  });
});

test('normalizeImdbId rejects malformed and injection-like input', () => {
  for (const value of [
    undefined,
    null,
    42,
    '',
    '1375666',
    'TT1375666',
    'tt123456',
    'tt12345678901',
    'tt123&apikey=x',
    'tt1234567&apikey=x',
    '../tt1234567',
    'tt1234567?',
    'tt1234567/../',
  ]) {
    assert.equal(normalizeImdbId(value).ok, false, String(value));
  }
});

test('buildOmdbUrl builds the exact upstream query and encodes the key', () => {
  const url = new URL(buildOmdbUrl('tt1375666', 'key with & symbols'));

  assert.equal(url.origin, 'https://www.omdbapi.com');
  assert.equal(url.pathname, '/');
  assert.equal(url.searchParams.get('i'), 'tt1375666');
  assert.equal(url.searchParams.get('apikey'), 'key with & symbols');
  assert.match(url.toString(), /apikey=key\+with\+%26\+symbols/);
});

test('trimOmdbResponse keeps only fields the app consumes', () => {
  assert.deepEqual(
    trimOmdbResponse({
      Response: 'True',
      imdbRating: '8.8',
      Year: '2010',
      Plot: 'not proxied',
      Actors: 'not proxied',
    }),
    {Response: 'True', imdbRating: '8.8', Year: '2010'},
  );
});

test('trimOmdbResponse handles an OMDB miss', () => {
  assert.deepEqual(
    trimOmdbResponse({Response: 'False', Error: 'Movie not found!'}),
    {Response: 'False'},
  );
});

test('trimOmdbResponse ignores malformed payloads and non-string fields', () => {
  assert.deepEqual(trimOmdbResponse(null), {Response: 'False'});
  assert.deepEqual(trimOmdbResponse([]), {Response: 'False'});
  assert.deepEqual(
    trimOmdbResponse({Response: 'True', imdbRating: 8.8, Year: 2010}),
    {Response: 'True'},
  );
});
