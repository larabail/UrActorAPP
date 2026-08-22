/**
 * Tests for the downloads page's release logic.
 *
 * Run with: node --test web/downloads/
 *
 * These cover the decisions the page cannot be eyeballed for. Whether it looks
 * right is answered by opening it; whether it offers the newest build, the
 * right file, and something at all when GitHub is unreachable is answered
 * here, because each of those only misbehaves on a payload nobody has in front
 * of them.
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  MACOS,
  WINDOWS,
  assetPlatform,
  compareVersions,
  detectPlatform,
  formatDate,
  formatSize,
  latestFor,
  manifestRelease,
  normalizeRelease,
  parseVersion,
  pickDownloads,
  selectReleases,
  summariseNotes,
  versionText,
} from './releases.js';

/** A release the API would return, with both installers attached. */
function release(version, extra = {}) {
  return {
    tag_name: `v${version}`,
    html_url: `https://github.com/larabail/UrActorAPP/releases/tag/v${version}`,
    published_at: '2026-08-21T09:00:00Z',
    body: 'Something changed.',
    assets: [
      {
        name: `UrActor-${version}-macos.dmg`,
        size: 152_043_520,
        browser_download_url:
          `https://github.com/larabail/UrActorAPP/releases/download/v${version}/UrActor-${version}-macos.dmg`,
      },
      {
        name: `UrActor-${version}-windows-setup.exe`,
        size: 48_234_496,
        browser_download_url:
          `https://github.com/larabail/UrActorAPP/releases/download/v${version}/UrActor-${version}-windows-setup.exe`,
      },
    ],
    ...extra,
  };
}

describe('parseVersion', () => {
  it('reads a plain version', () => {
    assert.deepEqual(parseVersion('3.16.0'), [3, 16, 0]);
  });

  it('reads a tag', () => {
    assert.deepEqual(parseVersion('v3.16.0'), [3, 16, 0]);
  });

  it('fills in a missing patch', () => {
    assert.deepEqual(parseVersion('3.16'), [3, 16, 0]);
  });

  it('drops a build suffix, which belongs to Play', () => {
    assert.deepEqual(parseVersion('3.16.0+74'), [3, 16, 0]);
  });

  it('refuses anything that is not a version', () => {
    for (const raw of ['', 'latest', 'v', '3.16.0.1', '3.x.0', null, 42]) {
      assert.equal(parseVersion(raw), null, `accepted ${JSON.stringify(raw)}`);
    }
  });

  it('normalises to three parts as text', () => {
    assert.equal(versionText('v3.16'), '3.16.0');
    assert.equal(versionText('nightly'), null);
  });
});

describe('compareVersions', () => {
  it('orders a tenth minor after a ninth', () => {
    // Sorted as text, 3.10.0 comes before 3.9.0 and the page would open by
    // offering the older build as the current one.
    assert.ok(compareVersions('3.10.0', '3.9.0') > 0);
  });

  it('orders by major before minor', () => {
    assert.ok(compareVersions('4.0.0', '3.99.99') > 0);
  });

  it('treats equal versions as equal', () => {
    assert.equal(compareVersions('3.16.0', 'v3.16.0+74'), 0);
  });
});

describe('assetPlatform', () => {
  it('recognises the installers CI builds', () => {
    assert.equal(assetPlatform('UrActor-3.16.0-macos.dmg'), MACOS);
    assert.equal(assetPlatform('UrActor-3.16.0-windows-setup.exe'), WINDOWS);
  });

  it('ignores the checksum beside an installer', () => {
    // It ends in .sha256 but still contains .dmg, so a naive match offers a
    // 64-byte text file as the macOS download.
    assert.equal(assetPlatform('UrActor-3.16.0-macos.dmg.sha256'), null);
    assert.equal(
      assetPlatform('UrActor-3.16.0-windows-setup.exe.sha256'), null);
  });

  it('ignores anything that is not an installer', () => {
    assert.equal(assetPlatform('source-code.tar.gz'), null);
    assert.equal(assetPlatform(undefined), null);
  });
});

describe('pickDownloads', () => {
  it('finds both installers', () => {
    const downloads = pickDownloads(release('3.16.0').assets);
    assert.equal(downloads[MACOS].name, 'UrActor-3.16.0-macos.dmg');
    assert.equal(downloads[WINDOWS].size, 48_234_496);
  });

  it('reports a missing platform as null rather than omitting it', () => {
    const downloads = pickDownloads([
      { name: 'UrActor-3.16.0-macos.dmg', size: 1, browser_download_url: 'https://example.com/a.dmg' },
    ]);
    assert.equal(downloads[WINDOWS], null);
  });

  it('refuses a link that is not https', () => {
    // A release asset URL is data from a server, and a javascript: URL in an
    // href runs when someone clicks the download button.
    const downloads = pickDownloads([
      { name: 'evil.dmg', size: 1, browser_download_url: 'javascript:alert(1)' },
      { name: 'plain.exe', size: 1, browser_download_url: 'http://example.com/x.exe' },
    ]);
    assert.equal(downloads[MACOS], null);
    assert.equal(downloads[WINDOWS], null);
  });

  it('survives a payload with no assets at all', () => {
    assert.deepEqual(pickDownloads(undefined), { [MACOS]: null, [WINDOWS]: null });
  });
});

describe('normalizeRelease', () => {
  it('keeps a published release with installers', () => {
    const normalized = normalizeRelease(release('3.16.0'));
    assert.equal(normalized.version, '3.16.0');
    assert.equal(normalized.tag, 'v3.16.0');
    assert.ok(normalized.downloads[MACOS].url.startsWith('https://'));
  });

  it('drops a draft, which nobody else can download', () => {
    assert.equal(normalizeRelease(release('3.17.0', { draft: true })), null);
  });

  it('drops a pre-release, which this pipeline never publishes', () => {
    assert.equal(normalizeRelease(release('3.17.0', { prerelease: true })), null);
  });

  it('drops a release with no desktop installers', () => {
    // Android and iOS ship under the same version numbers; a tag with only
    // notes on it has nothing to offer a downloads page.
    assert.equal(normalizeRelease(release('3.16.0', { assets: [] })), null);
  });

  it('drops a tag that is not a version', () => {
    assert.equal(normalizeRelease(release('3.16.0', { tag_name: 'nightly' })), null);
  });

  it('builds a release page link when the payload has no usable one', () => {
    const normalized = normalizeRelease(release('3.16.0', { html_url: 'ftp://nope' }));
    assert.equal(
      normalized.page,
      'https://github.com/larabail/UrActorAPP/releases/tag/v3.16.0',
    );
  });
});

describe('selectReleases', () => {
  it('returns the newest version first, whatever order they arrive in', () => {
    const selected = selectReleases([
      release('3.9.0'),
      release('3.16.0'),
      release('3.10.0'),
    ]);
    assert.deepEqual(selected.map((r) => r.version), ['3.16.0', '3.10.0', '3.9.0']);
  });

  it('lists a version once', () => {
    const selected = selectReleases([release('3.16.0'), release('v3.16.0')]);
    assert.equal(selected.length, 1);
  });

  it('honours a limit', () => {
    const selected = selectReleases(
      [release('3.16.0'), release('3.15.0'), release('3.14.0')],
      { limit: 2 },
    );
    assert.deepEqual(selected.map((r) => r.version), ['3.16.0', '3.15.0']);
  });

  it('returns nothing for a payload that is not a list', () => {
    // The API answers a rate limit with an object carrying a message, not an
    // array, and the page must render that as "unavailable" rather than throw.
    assert.deepEqual(selectReleases({ message: 'API rate limit exceeded' }), []);
    assert.deepEqual(selectReleases(null), []);
  });
});

describe('latestFor', () => {
  it('takes the newest release that has that platform', () => {
    const releases = selectReleases([release('3.16.0'), release('3.15.0')]);
    assert.equal(latestFor(releases, MACOS).version, '3.16.0');
  });

  it('falls back when the newest release is missing a platform', () => {
    // The two desktop builds come from separate jobs on separate runners, so
    // a release can exist with only one attached. Offering the last Windows
    // build that did ship beats an empty card.
    const windowsless = release('3.16.0');
    windowsless.assets = windowsless.assets.filter((a) => a.name.endsWith('.dmg'));

    const releases = selectReleases([windowsless, release('3.15.0')]);
    assert.equal(latestFor(releases, MACOS).version, '3.16.0');
    assert.equal(latestFor(releases, WINDOWS).version, '3.15.0');
  });

  it('is null when no release has that platform', () => {
    assert.equal(latestFor([], WINDOWS), null);
  });
});

describe('summariseNotes', () => {
  const body = [
    'Playlists can be reordered.',
    '',
    '## Downloads',
    '',
    'https://downloads.uractor.com',
    '',
    'The Windows installer is not yet code signed.',
  ].join('\n');

  it('drops the Downloads section the workflow appends', () => {
    // It points at this very page and repeats the SmartScreen warning shown
    // beside the Windows button, so under "What\'s new" it reads as news.
    const notes = summariseNotes(body);
    assert.equal(notes, 'Playlists can be reordered.');
  });

  it('keeps a section that is not Downloads, without its hashes', () => {
    const notes = summariseNotes('## Fixed\n\nSearch stopped losing results.');
    assert.equal(notes, 'Fixed\n\nSearch stopped losing results.');
  });

  it('skips subheadings nested under Downloads', () => {
    const notes = summariseNotes(
      'Top.\n\n## Downloads\n\n### Windows\n\nWarning text.\n\n## Thanks\n\nEveryone.',
    );
    assert.equal(notes, 'Top.\n\nThanks\n\nEveryone.');
  });

  it('is empty for a release with no body', () => {
    assert.equal(summariseNotes(null), '');
    assert.equal(summariseNotes('   \n\n  '), '');
  });
});

describe('manifestRelease', () => {
  const manifest = {
    version: '3.16.0',
    downloadUrl: 'https://downloads.uractor.com/',
    published: '2026-08-21',
    notes: 'Playlists can be reordered.',
    assets: {
      macos: 'https://github.com/larabail/UrActorAPP/releases/download/v3.16.0/UrActor-3.16.0-macos.dmg',
      windows: 'https://github.com/larabail/UrActorAPP/releases/download/v3.16.0/UrActor-3.16.0-windows-setup.exe',
    },
  };

  it('produces the same shape as a release from the API', () => {
    // So the page renders the fallback through exactly the same code path,
    // and a bug there cannot hide until GitHub is down.
    const fallback = manifestRelease(manifest);
    const fromApi = normalizeRelease(release('3.16.0'));
    assert.deepEqual(Object.keys(fallback).sort(), Object.keys(fromApi).sort());
    assert.equal(fallback.version, '3.16.0');
    assert.equal(fallback.downloads[MACOS].name, 'UrActor-3.16.0-macos.dmg');
  });

  it('leaves the size unknown rather than inventing one', () => {
    assert.equal(manifestRelease(manifest).downloads[MACOS].size, 0);
  });

  it('accepts a version written as a number', () => {
    // A hand-edited manifest is as likely to say 3.16 as "3.16.0".
    const numeric = manifestRelease({ ...manifest, version: 3.16 });
    assert.equal(numeric.version, '3.16.0');
  });

  it('refuses a manifest with nothing downloadable', () => {
    assert.equal(manifestRelease({ ...manifest, assets: {} }), null);
    assert.equal(
      manifestRelease({ ...manifest, assets: { macos: 'javascript:alert(1)' } }),
      null,
    );
    assert.equal(manifestRelease(null), null);
    assert.equal(manifestRelease({ version: 'nope' }), null);
  });
});

describe('detectPlatform', () => {
  it('recognises the desktops', () => {
    assert.equal(
      detectPlatform('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'), MACOS);
    assert.equal(
      detectPlatform('Mozilla/5.0 (Windows NT 10.0; Win64; x64)'), WINDOWS);
  });

  it('does not offer a disk image to a phone', () => {
    // An iPhone says "like Mac OS X" and an iPad in desktop mode says
    // "Macintosh" outright, so a naive match pushes a 150MB .dmg at a device
    // that cannot open it.
    assert.equal(
      detectPlatform('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'),
      null,
    );
    assert.equal(
      detectPlatform('Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)'), null);
    assert.equal(detectPlatform('Mozilla/5.0 (Linux; Android 14; Pixel 8)'), null);
  });

  it('is null for anything else', () => {
    assert.equal(detectPlatform('Mozilla/5.0 (X11; Linux x86_64)'), null);
    assert.equal(detectPlatform(''), null);
    assert.equal(detectPlatform(undefined), null);
  });
});

describe('formatSize', () => {
  it('reads installers in megabytes', () => {
    assert.equal(formatSize(152_043_520), '145 MB');
    assert.equal(formatSize(5 * 1024 * 1024), '5.0 MB');
  });

  it('falls back to kilobytes and up to gigabytes', () => {
    assert.equal(formatSize(2048), '2 KB');
    assert.equal(formatSize(3 * 1024 * 1024 * 1024), '3.0 GB');
  });

  it('says nothing when the size is unknown', () => {
    // The version.json fallback has no sizes, and "0 MB" beside a download
    // button reads as a broken build.
    assert.equal(formatSize(0), '');
    assert.equal(formatSize(undefined), '');
    assert.equal(formatSize(-1), '');
  });
});

describe('formatDate', () => {
  it('reads an ISO timestamp', () => {
    assert.equal(formatDate('2026-08-21T09:00:00Z'), '21 August 2026');
  });

  it('formats in UTC', () => {
    // In a westward zone this instant is still 20 August locally, which would
    // disagree with the date on the GitHub release it links to.
    assert.equal(formatDate('2026-08-21T02:00:00Z'), '21 August 2026');
  });

  it('says nothing for a date it cannot read', () => {
    assert.equal(formatDate('soon'), '');
    assert.equal(formatDate(''), '');
    assert.equal(formatDate(null), '');
  });
});
