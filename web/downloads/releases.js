/**
 * Turning GitHub's list of releases into the rows the downloads page shows.
 *
 * The page reads the releases API in the browser rather than being generated
 * at release time. A generated page can only be as current as the last run of
 * the release workflow, and it can only describe one version: re-tagging a
 * build, deleting a bad release or publishing a hotfix from a branch all left
 * the page advertising something that was no longer true, with no way to fix
 * it but to run a release. Asking GitHub at page load means the page is a view
 * of whatever is actually downloadable, and older versions come along for free
 * because they are in the same response.
 *
 * Everything in this file is pure: it takes a decoded API payload and returns
 * plain objects. Fetching, and the DOM, live in `page.js`. That split is what
 * makes the fiddly parts -- which asset belongs to which platform, and which
 * of `3.9.0` and `3.10.0` is newer -- testable without a browser.
 */

export const REPO = 'larabail/UrActorAPP';

/** Newest first, and enough of them to cover a year of releases. */
export const RELEASES_API =
  `https://api.github.com/repos/${REPO}/releases?per_page=30`;

export const RELEASES_PAGE = `https://github.com/${REPO}/releases`;

export const MACOS = 'macos';
export const WINDOWS = 'windows';
export const PLATFORMS = [MACOS, WINDOWS];

/**
 * The mobile platforms, which are installed from a store rather than
 * downloaded. They are deliberately not in PLATFORMS: that list drives
 * everything that reads the releases API, and there is no GitHub asset to
 * find for either of these.
 */
export const ANDROID = 'android';
export const IOS = 'ios';
export const STORE_PLATFORMS = [ANDROID, IOS];

/** Where each mobile build actually comes from. */
export const STORES = {
  [ANDROID]: {
    name: 'Android',
    store: 'Google Play',
    url: 'https://play.google.com/store/apps/details?id=com.uractor.uractorapp',
  },
  [IOS]: {
    name: 'iPhone & iPad',
    store: 'the App Store',
    url: 'https://apps.apple.com/app/uractor/id6503330070',
  },
};

/**
 * The installer extensions each platform is recognised by.
 *
 * Wider than what CI currently produces -- a `.dmg` and an Inno Setup `.exe`.
 * The cost of listing a format that is never built is nothing; the cost of
 * being exhaustive is a page that silently shows no download at all the day
 * the packaging changes.
 */
const EXTENSIONS = {
  [MACOS]: ['.dmg', '.pkg', '.zip'],
  [WINDOWS]: ['.exe', '.msi'],
};

/** Checksums sit beside the installers and are not themselves downloads. */
const NOT_AN_INSTALLER = ['.sha256', '.sha512', '.md5', '.asc', '.sig'];

/**
 * The `MAJOR.MINOR.PATCH` numbers in [raw], or null if it is not a version.
 *
 * Mirrors `AppVersion.tryParse` in `lib/common/update/update_check.dart` so
 * the page and the app agree about what a version is. A `+build` suffix and a
 * `-rc1` tail are both dropped: neither participates in ordering, and the
 * build number in particular belongs to Play rather than to the desktop
 * builds.
 */
export function parseVersion(raw) {
  if (typeof raw !== 'string') return null;

  let text = raw.trim();
  if (text.startsWith('v') || text.startsWith('V')) text = text.slice(1);
  text = text.split('+')[0].split('-')[0].trim();
  if (!text) return null;

  const parts = text.split('.');
  if (parts.length > 3) return null;

  const numbers = [];
  for (const part of parts) {
    // `Number('')` is 0 and `Number('3px')` is NaN, so both are refused here
    // rather than read as a version component.
    if (!/^\d+$/.test(part)) return null;
    numbers.push(Number(part));
  }
  while (numbers.length < 3) numbers.push(0);
  return numbers;
}

/** [raw] as a normalised `3.16.0`, or null if it is not a version. */
export function versionText(raw) {
  const parsed = parseVersion(raw);
  return parsed ? parsed.join('.') : null;
}

/**
 * Orders two versions, oldest first.
 *
 * Compared number by number rather than as text, because as text `3.9.0`
 * sorts after `3.10.0` and the page would offer the older build as the
 * current one -- the kind of mistake that only appears once a project reaches
 * a tenth minor release, which is exactly when nobody is looking for it.
 */
export function compareVersions(a, b) {
  const left = parseVersion(a);
  const right = parseVersion(b);
  if (!left || !right) return 0;
  for (let i = 0; i < 3; i += 1) {
    if (left[i] !== right[i]) return left[i] - right[i];
  }
  return 0;
}

/** Which platform an asset called [name] installs, or null if it installs none. */
export function assetPlatform(name) {
  if (typeof name !== 'string') return null;
  const lower = name.toLowerCase();

  // Checked first: `UrActor-3.16.0-macos.dmg.sha256` ends in `.sha256` but
  // still contains `.dmg`, and offering a 64-byte text file as the macOS
  // installer is worse than offering nothing.
  if (NOT_AN_INSTALLER.some((suffix) => lower.endsWith(suffix))) return null;

  for (const platform of PLATFORMS) {
    if (EXTENSIONS[platform].some((suffix) => lower.endsWith(suffix))) {
      return platform;
    }
  }
  return null;
}

/**
 * The macOS and Windows installers among a release's [assets].
 *
 * Missing platforms come back as null rather than being omitted, so a caller
 * can tell "this release had no Windows build" from "this release is not a
 * release", and say so on the page.
 */
export function pickDownloads(assets) {
  const downloads = { [MACOS]: null, [WINDOWS]: null };
  if (!Array.isArray(assets)) return downloads;

  for (const asset of assets) {
    if (!asset || typeof asset !== 'object') continue;
    const platform = assetPlatform(asset.name);
    // First one wins. A release carrying two macOS builds is not something
    // this pipeline produces, and guessing between them would be worse than
    // taking the one GitHub lists first.
    if (!platform || downloads[platform]) continue;

    const url = asset.browser_download_url;
    // Only ever put an https link on the page. The API is fetched over https,
    // but a release asset URL is data from a server and a `javascript:` or
    // `data:` URL smuggled into an href would run when clicked.
    if (typeof url !== 'string' || !url.startsWith('https://')) continue;

    const size = Number(asset.size);
    downloads[platform] = {
      name: asset.name,
      url,
      size: Number.isFinite(size) && size > 0 ? size : 0,
    };
  }
  return downloads;
}

/**
 * A release from the API as the page wants it, or null if it is not one.
 *
 * Drafts are invisible to anyone without push access, so listing one would
 * show a download that 404s for every visitor. Pre-releases are excluded for
 * the same reason in reverse: they are visible, but this pipeline does not
 * publish them, so one appearing is a hand-made release that was deliberately
 * not meant for the front page.
 */
export function normalizeRelease(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (raw.draft || raw.prerelease) return null;

  const version = versionText(raw.tag_name);
  if (!version) return null;

  const downloads = pickDownloads(raw.assets);
  // A release with neither installer is a tag with notes attached -- the
  // Android and iOS releases go out under the same version numbers -- and has
  // nothing to offer a page about desktop downloads.
  if (!downloads[MACOS] && !downloads[WINDOWS]) return null;

  const tag = typeof raw.tag_name === 'string' ? raw.tag_name : `v${version}`;
  const page = typeof raw.html_url === 'string' &&
      raw.html_url.startsWith('https://github.com/')
    ? raw.html_url
    : `${RELEASES_PAGE}/tag/${encodeURIComponent(tag)}`;

  return {
    version,
    tag,
    page,
    published: typeof raw.published_at === 'string' ? raw.published_at : '',
    notes: summariseNotes(raw.body),
    downloads,
  };
}

/**
 * Every release worth listing in [payload], newest first.
 *
 * The API returns them in creation order, which is usually but not reliably
 * version order: a hotfix tagged after a bigger release that was prepared
 * earlier arrives out of sequence, and the page would then open with an older
 * version than the one the app is telling people to install.
 */
export function selectReleases(payload, { limit = 20 } = {}) {
  if (!Array.isArray(payload)) return [];

  const releases = [];
  const seen = new Set();
  for (const raw of payload) {
    const release = normalizeRelease(raw);
    if (!release || seen.has(release.version)) continue;
    seen.add(release.version);
    releases.push(release);
  }

  releases.sort((a, b) => compareVersions(b.version, a.version));
  return releases.slice(0, limit);
}

/**
 * The newest release in [releases] that actually has a [platform] installer.
 *
 * Not simply the newest release: the two desktop builds are produced by
 * separate jobs on separate runners, so a release can exist with only one of
 * them attached. Falling back to the last version that did ship for this
 * platform offers something that works, which is better than an empty card
 * on the one platform whose build failed.
 */
export function latestFor(releases, platform) {
  if (!Array.isArray(releases)) return null;
  return releases.find((release) => release.downloads[platform]) || null;
}

/**
 * The release notes with the "Downloads" section removed.
 *
 * The release body ends with a section pointing at this very page and
 * repeating the SmartScreen warning, which the page already explains beside
 * the Windows button. Repeating it under "What's new" reads as though it were
 * news, every release.
 */
export function summariseNotes(body) {
  if (typeof body !== 'string') return '';

  const kept = [];
  let skippingBelow = 0;
  for (const line of body.replace(/\r\n/g, '\n').split('\n')) {
    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      const depth = heading[1].length;
      const text = heading[2].trim();
      // A deeper heading is still inside the section being skipped; one at
      // the same level or shallower ends it.
      if (skippingBelow && depth > skippingBelow) continue;
      skippingBelow = /^downloads?\b/i.test(text) ? depth : 0;
      if (skippingBelow) continue;
      kept.push(text);
      continue;
    }
    if (!skippingBelow) kept.push(line);
  }

  return kept.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

/**
 * The one release described by `version.json`, as a fallback.
 *
 * The API allows sixty unauthenticated requests an hour per address, which a
 * shared network can exhaust between them, and it is a third party that can
 * simply be down. `version.json` is written by the release workflow and served
 * from this same origin, so it is available whenever the page itself is. It
 * carries only the current version, which is the one that matters most.
 */
export function manifestRelease(manifest) {
  if (!manifest || typeof manifest !== 'object') return null;

  const version = versionText(
    typeof manifest.version === 'number'
      ? String(manifest.version)
      : manifest.version,
  );
  if (!version) return null;

  const assets = manifest.assets && typeof manifest.assets === 'object'
    ? manifest.assets
    : {};
  const downloads = { [MACOS]: null, [WINDOWS]: null };
  for (const platform of PLATFORMS) {
    const url = assets[platform];
    if (typeof url !== 'string' || !url.startsWith('https://')) continue;
    downloads[platform] = {
      // The manifest records URLs and no sizes, so the name is read back off
      // the URL and the size is left unknown rather than invented.
      name: decodeURIComponent(url.split('/').pop() || ''),
      url,
      size: 0,
    };
  }
  if (!downloads[MACOS] && !downloads[WINDOWS]) return null;

  return {
    version,
    tag: `v${version}`,
    page: `${RELEASES_PAGE}/tag/v${version}`,
    published: typeof manifest.published === 'string' ? manifest.published : '',
    notes: summariseNotes(manifest.notes),
    downloads,
  };
}

/**
 * The platform [userAgent] is running, or null if it is none of them.
 *
 * Returns a store platform for phones and tablets, not null. The page ships
 * every build UrActor has, and a phone arriving here wants the store rather
 * than nothing.
 *
 * [maxTouchPoints] disambiguates the one case a user agent cannot. An iPad in
 * desktop mode says "Macintosh; Intel Mac OS X" with no iPad token anywhere,
 * so a string match alone hands it a 150MB disk image it cannot open. A Mac
 * reports 0 touch points; an iPad reports 5. Pass `navigator.maxTouchPoints`.
 */
export function detectPlatform(userAgent, maxTouchPoints = 0) {
  if (typeof userAgent !== 'string' || !userAgent) return null;

  // Before the Apple checks: an Android tablet's user agent can carry "Linux"
  // and touch points too, and Android is unambiguous when it is present.
  if (/Android/i.test(userAgent)) return ANDROID;

  if (/iPhone|iPad|iPod/i.test(userAgent)) return IOS;

  const appleDesktop = /Mac OS X|Macintosh|macOS/i.test(userAgent);
  // An iPad pretending to be a Mac. Macs have no touch screen, so any touch
  // capability on a "Macintosh" means this is iPadOS.
  if (appleDesktop && Number(maxTouchPoints) > 1) return IOS;

  if (/Windows|Win64|Win32/i.test(userAgent)) return WINDOWS;
  if (appleDesktop) return MACOS;
  return null;
}

/** True when [platform] is installed from a store rather than downloaded. */
export function isStorePlatform(platform) {
  return platform === ANDROID || platform === IOS;
}

/** [bytes] as something a person reads, or '' when the size is unknown. */
export function formatSize(bytes) {
  const size = Number(bytes);
  if (!Number.isFinite(size) || size <= 0) return '';

  const mb = size / (1024 * 1024);
  if (mb < 1) return `${Math.max(1, Math.round(size / 1024))} KB`;
  if (mb < 1024) return `${mb < 10 ? mb.toFixed(1) : Math.round(mb)} MB`;
  return `${(mb / 1024).toFixed(1)} GB`;
}

/**
 * An ISO timestamp as a readable date, or '' if it is not one.
 *
 * Formatted in UTC. Read in the viewer's own zone, a release published at
 * 02:00 UTC shows as the previous day everywhere west of Greenwich, which
 * does not match the date on the GitHub release it links to.
 */
export function formatDate(value, locale = 'en-GB') {
  if (typeof value !== 'string' || !value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}
