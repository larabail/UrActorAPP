/**
 * Tests that the page still gives page.js everything it reaches for.
 *
 * Run with: node --test web/downloads/*.test.js
 *
 * releases.test.js covers the logic. This covers the seam between that logic
 * and the document, which is the thing a restyle breaks: rename an id while
 * moving markup around and the page still looks finished, still deploys, and
 * lists no downloads at all. Nothing else here would notice, because the
 * failure is a `null` in a browser nobody is watching.
 *
 * The required ids are read out of page.js rather than written down twice, so
 * this cannot drift from the script it is protecting.
 */

import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';

import { ANDROID, IOS, STORES } from './releases.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(HERE, 'index.html'), 'utf8');
const script = readFileSync(join(HERE, 'page.js'), 'utf8');

/** The platforms page.js loops over when it builds an id. */
const PLATFORMS = ['macos', 'windows'];

/** Every id page.js looks up, taken from the script itself. */
function requiredIds() {
  const ids = new Set();

  for (const match of script.matchAll(/el\('([^']+)'\)/g)) {
    ids.add(match[1]);
  }

  // `el(`asset-${platform}`)` and friends, expanded over the platform list.
  for (const match of script.matchAll(/el\(`([^`]+)`\)/g)) {
    for (const platform of PLATFORMS) {
      ids.add(match[1].replace('${platform}', platform));
    }
  }

  return [...ids];
}

describe('the markup page.js depends on', () => {
  it('finds every id the script looks up', () => {
    const missing = requiredIds().filter((id) => !html.includes(`id="${id}"`));
    assert.deepEqual(missing, [],
      `page.js looks these up and the page has none of them: ${missing.join(', ')}`);
  });

  it('looks up a plausible number of ids', () => {
    // Guards the regexes above: if they ever stop matching, every id would
    // "exist" and the test would pass while checking nothing.
    assert.ok(requiredIds().length >= 12,
      `only found ${requiredIds().length} ids in page.js, which suggests the `
      + 'patterns in this test stopped matching');
  });

  it('styles the classes the script assigns', () => {
    // page.js sets these on elements it creates or changes. They are not in
    // the committed markup, so nothing else would catch the styling going.
    for (const cls of ['yours', 'secondary', 'links', 'ver', 'when']) {
      assert.ok(html.includes(`.${cls}`), `no styling for .${cls}`);
    }
  });

  it('keeps the rule that makes the hidden attribute win', () => {
    // Several sections are held back with `hidden` until they have content,
    // and a class that sets `display` outranks the browser's own rule for it.
    // Without this the "Yours" badge shows on both platforms at once.
    assert.match(html, /\[hidden\]\s*\{\s*display:\s*none\s*!important/);
  });

  it('leads somewhere real with no script', () => {
    // Every button is useful in the served markup, before page.js runs and if
    // it never does. Where "useful" points depends on the platform: the
    // desktop buttons fall back to the releases page, which is where the
    // installers actually live, while the store buttons are already final --
    // there is no Android or iOS build on GitHub to fall back to.
    //
    // The store entries are compared against releases.js rather than a
    // prefix. An earlier version of this test asserted the iOS button merely
    // started with apps.apple.com, and passed for months on a link that
    // answered 404: the app id in it belonged to nothing. A prefix cannot
    // tell a working store link from a dead one.
    const RELEASES = 'https://github.com/larabail/UrActorAPP/releases';
    const expected = {
      'hero-button': RELEASES,
      'button-macos': RELEASES,
      'button-windows': RELEASES,
      'button-android': STORES[ANDROID].url,
      'button-ios': STORES[IOS].url,
    };

    const found = new Map(
      [...html.matchAll(/<a class="button"[^>]*id="([^"]+)"[^>]*href="([^"]+)"/g)]
        .map(([, id, href]) => [id, href]),
    );

    for (const [id, href] of found) {
      assert.ok(expected[id],
        `${id} is a button with nowhere declared to lead without script`);
      if (expected[id] === RELEASES) {
        assert.ok(href.startsWith(RELEASES),
          `${id} leads to ${href}, expected something under ${RELEASES}`);
      } else {
        // Exactly, not by prefix: the page and releases.js must agree, or
        // page.js will replace a correct link with a stale one.
        assert.equal(href, expected[id],
          `${id} in the page disagrees with releases.js`);
      }
    }

    for (const id of Object.keys(expected)) {
      assert.ok(found.has(id), `${id} is missing from the page`);
    }
  });

  it('names a real app in each store link', () => {
    // Not a check that the link resolves -- these tests make no network
    // calls -- but the shape of a listing that exists. The dead iOS link was
    // a well-formed URL with the wrong id.
    assert.match(STORES[IOS].url,
      /^https:\/\/apps\.apple\.com\/(?:[a-z]{2}\/)?app\/[^/]+\/id\d{9,}$/);
    assert.match(STORES[ANDROID].url,
      /^https:\/\/play\.google\.com\/store\/apps\/details\?id=[\w.]+$/);
  });
});

describe('the shared design', () => {
  it('wears the same mark as the rest of the site', () => {
    // The icon is the brand. A downloads page carrying a different one reads
    // as somebody else's website.
    for (const asset of ['mark-512.png', 'mark-192.png', 'favicon-32.png']) {
      assert.ok(html.includes(`/assets/${asset}`), `${asset} is not referenced`);
      assert.ok(existsSync(join(HERE, 'assets', asset)),
        `${asset} is referenced but not committed`);
    }
  });

  it('uses the palette uractor.com uses', () => {
    // These are the contract between two sites deployed from different
    // repositories. Drift here is how they stop looking related.
    for (const token of ['--black:  #08090A', '--gold:   #E4B462', '--bone:   #F2EFE6']) {
      assert.ok(html.includes(token), `missing token ${token}`);
    }
  });

  it('keeps no local asset it does not ship', () => {
    for (const match of html.matchAll(/(?:href|src)="(\/[^"]+)"/g)) {
      const target = join(HERE, match[1].replace(/^\//, ''));
      assert.ok(existsSync(target), `${match[1]} is referenced but not committed`);
    }
  });

  it('is a single well formed document with one h1', () => {
    assert.ok(html.includes('<html lang="en">'));
    assert.equal((html.match(/<h1\b/g) || []).length, 1);
    assert.ok(html.trimEnd().endsWith('</html>'));
  });
});
