'use strict';

// Pure helpers for the OMDB proxy.
//
// The callable in index.js owns authentication, secrets and fetch. This module
// owns only validation and response shaping, so the proxy rules can be tested
// without touching the network or Firebase.

function normalizeImdbId(input) {
  const id = typeof input === 'string' ? input.trim() : '';
  if (!/^tt\d{7,10}$/.test(id)) return {ok: false};
  return {ok: true, id};
}

function buildOmdbUrl(id, apiKey) {
  const url = new URL('https://www.omdbapi.com/');
  url.searchParams.set('i', id);
  url.searchParams.set('apikey', apiKey);
  return url.toString();
}

function trimOmdbResponse(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return {Response: 'False'};
  }
  if (payload.Response === 'False') return {Response: 'False'};

  const result = {Response: 'True'};
  if (typeof payload.imdbRating === 'string') {
    result.imdbRating = payload.imdbRating;
  }
  if (typeof payload.Year === 'string') {
    result.Year = payload.Year;
  }
  return result;
}

module.exports = {
  normalizeImdbId,
  buildOmdbUrl,
  trimOmdbResponse,
};
