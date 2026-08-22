/**
 * Filling the downloads page in from whatever is actually downloadable.
 *
 * The page ships with every button pointing at the GitHub releases page, which
 * is a correct if unhelpful answer. This replaces those with the specific
 * installers for the newest release, and lists the older ones underneath. If
 * both sources below fail, the page is left exactly as it was served rather
 * than being emptied -- a stale-looking page that still leads somewhere beats
 * a blank one.
 *
 * Nothing here is written with innerHTML. Release names and notes are text
 * that whoever cut the release wrote, and the one thing a page full of
 * download links must not do is execute markup it was handed by a server.
 */

import {
  ANDROID,
  IOS,
  MACOS,
  PLATFORMS,
  RELEASES_API,
  RELEASES_PAGE,
  STORES,
  WINDOWS,
  detectPlatform,
  formatDate,
  formatSize,
  isStorePlatform,
  latestFor,
  manifestRelease,
  selectReleases,
} from './releases.js';

const PLATFORM_NAMES = {
  [MACOS]: 'macOS',
  [WINDOWS]: 'Windows',
};

const el = (id) => document.getElementById(id);

async function fetchJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(`${url} answered ${response.status}`);
  return response.json();
}

/**
 * Every published release, and where the answer came from.
 *
 * GitHub first, because it knows about all of them. `version.json` second: it
 * is written by the release workflow and served from this origin, so it is
 * reachable whenever this page is, and it covers the case that matters most --
 * the API rate limit, which is sixty requests an hour for everyone sharing an
 * address, and is spent by a busy office long before anyone downloads
 * anything.
 */
async function loadReleases() {
  try {
    const payload = await fetchJson(RELEASES_API, {
      // A safelisted header, so this stays a simple request with no preflight.
      headers: { Accept: 'application/vnd.github+json' },
    });
    const releases = selectReleases(payload);
    if (releases.length) return { releases, source: 'github' };
    // The API answered and there is genuinely nothing yet, which is a
    // different thing to say than "we could not ask".
    return { releases: [], source: 'empty' };
  } catch (error) {
    console.warn('The releases API could not be read:', error);
  }

  try {
    const release = manifestRelease(await fetchJson('version.json', {
      cache: 'no-cache',
    }));
    if (release) return { releases: [release], source: 'manifest' };
  } catch (error) {
    console.warn('version.json could not be read:', error);
  }

  return { releases: [], source: 'unavailable' };
}

function showStatus(message) {
  const status = el('status');
  status.textContent = message;
  status.hidden = false;
}

/** A line a person can act on: what version, how big, and when. */
function describeDownload(release, download) {
  return [
    `Version ${release.version}`,
    formatSize(download.size),
    formatDate(release.published),
  ].filter(Boolean).join(' \u00b7 ');
}

function renderCard(platform, releases, yours) {
  const card = el(`card-${platform}`);
  const button = el(`button-${platform}`);
  const asset = el(`asset-${platform}`);

  if (yours === platform) {
    card.classList.add('yours');
    el(`badge-${platform}`).hidden = false;
  }

  const release = latestFor(releases, platform);
  if (!release) {
    button.setAttribute('aria-disabled', 'true');
    button.textContent = `No ${PLATFORM_NAMES[platform]} build yet`;
    asset.textContent = '';
    return;
  }

  const download = release.downloads[platform];
  button.href = download.url;
  button.textContent = `Download for ${PLATFORM_NAMES[platform]}`;
  asset.textContent = describeDownload(release, download);
  // The exact filename is what a checksum is verified against, but it is long
  // and the same on every row, so it goes where it can be asked for.
  asset.title = download.name;

  // Said out loud only when it is surprising: this platform's newest build is
  // older than the release the rest of the page is about.
  if (releases[0] && releases[0].version !== release.version) {
    asset.textContent +=
      ` \u00b7 newest ${PLATFORM_NAMES[platform]} build`;
  }
}

function renderHero(releases, yours) {
  const button = el('hero-button');
  const meta = el('hero-meta');
  const latest = releases[0];

  // A phone or tablet. There is no installer to offer and no releases API
  // answer that would help, so lead with the store it installs from -- which
  // is the whole point of noticing the device in the first place.
  if (isStorePlatform(yours)) {
    const store = STORES[yours];
    button.href = store.url;
    button.textContent = `Get UrActor on ${store.store}`;
    meta.textContent =
      `Looks like you are on ${store.name}. The desktop builds are below.`;
    return;
  }

  if (!latest) {
    button.textContent = 'Browse the releases on GitHub';
    button.href = RELEASES_PAGE;
    meta.textContent = '';
    return;
  }

  const mine = yours ? latestFor(releases, yours) : null;
  if (!mine) {
    // Either a platform this does not ship for, or a phone. Neither wants a
    // headline button that has to guess, so the two cards below do the work.
    button.hidden = true;
    meta.textContent =
      `Latest version ${latest.version}, released ${formatDate(latest.published)}. `
      + 'Choose your platform below.';
    return;
  }

  const download = mine.downloads[yours];
  button.href = download.url;
  button.textContent = `Download for ${PLATFORM_NAMES[yours]}`;
  meta.textContent = describeDownload(mine, download);

  const other = yours === MACOS ? WINDOWS : MACOS;
  const otherRelease = latestFor(releases, other);
  if (otherRelease) {
    const secondary = document.createElement('a');
    secondary.className = 'button secondary';
    secondary.href = otherRelease.downloads[other].url;
    secondary.textContent = `Also for ${PLATFORM_NAMES[other]}`;
    el('hero-actions').appendChild(secondary);
  }
}

/**
 * Badges the store card for the device someone is on.
 *
 * The ids are written out rather than built from the platform name, so that
 * markup.test.js -- which reads the required ids straight out of this file --
 * can see them.
 */
function markStore(yours) {
  if (yours === ANDROID) {
    el('card-android').classList.add('yours');
    el('badge-android').hidden = false;
  } else if (yours === IOS) {
    el('card-ios').classList.add('yours');
    el('badge-ios').hidden = false;
  }
}

function renderNotes(latest) {
  if (!latest) return;

  el('notes-link').href = latest.page;
  el('checksums-link').href = latest.page;
  if (!latest.notes) return;

  el('notes-heading').textContent = `What\u2019s new in ${latest.version}`;
  el('notes-body').textContent = latest.notes;
  el('notes').hidden = false;
}

function renderHistory(releases) {
  // One row under a heading reading "Every version" tells nobody anything the
  // buttons above have not already said.
  if (releases.length < 2) return;

  const list = el('history-list');
  for (const release of releases) {
    const row = document.createElement('li');

    const version = document.createElement('span');
    version.className = 'ver';
    version.textContent = release.version;
    row.appendChild(version);

    const when = document.createElement('span');
    when.className = 'when';
    when.textContent = formatDate(release.published);
    row.appendChild(when);

    const links = document.createElement('span');
    links.className = 'links';
    for (const platform of PLATFORMS) {
      const download = release.downloads[platform];
      if (download) {
        const link = document.createElement('a');
        link.href = download.url;
        link.textContent = PLATFORM_NAMES[platform];
        link.title = download.name;
        links.appendChild(link);
      } else {
        // Kept in place rather than dropped, so the columns line up and a
        // release that shipped for one platform only is visibly that.
        const missing = document.createElement('span');
        missing.textContent = PLATFORM_NAMES[platform];
        links.appendChild(missing);
      }
    }
    row.appendChild(links);

    list.appendChild(row);
  }
  el('history').hidden = false;
}

function render({ releases, source }) {
  // navigator.maxTouchPoints is what separates an iPad in desktop mode from
  // an actual Mac; the user agent alone claims to be a Macintosh.
  const yours = detectPlatform(navigator.userAgent, navigator.maxTouchPoints);

  renderHero(releases, yours);
  for (const platform of PLATFORMS) renderCard(platform, releases, yours);
  markStore(yours);
  renderNotes(releases[0]);
  if (source === 'github') renderHistory(releases);

  if (source === 'manifest') {
    showStatus('GitHub\u2019s release list could not be read just now, so only '
      + 'the current version is shown. Older versions are on the releases '
      + 'page.');
  } else if (source === 'empty') {
    showStatus('No desktop build has been published yet. The buttons lead to '
      + 'the releases page, where the first one will appear.');
    clearHeroMeta(yours);
  } else if (source === 'unavailable') {
    showStatus('The download list could not be loaded. Every installer is on '
      + 'the releases page.');
    clearHeroMeta(yours);
  }
}

/**
 * Clears the line under the hero button, unless it is saying which store the
 * device in someone's hand installs from.
 *
 * That line is the only thing that survives the releases API being down on a
 * phone: there is no desktop build to describe, and wiping it would leave a
 * store button with nothing explaining why it is the one being offered.
 */
function clearHeroMeta(yours) {
  if (isStorePlatform(yours)) return;
  el('hero-meta').textContent = '';
}

loadReleases().then(render).catch((error) => {
  // Rendering itself failing is a bug in this file, not a network problem, and
  // it must not leave the page mid-update: "Checking..." under a button that
  // still says "Download" claims a load is in progress that has already given
  // up.
  console.error('The downloads page could not be filled in:', error);
  el('hero-meta').textContent = '';
  for (const platform of PLATFORMS) {
    el(`asset-${platform}`).textContent = '';
  }
  showStatus('The download list could not be loaded. Every installer is on '
    + 'the releases page.');
});
