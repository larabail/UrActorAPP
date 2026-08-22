'use strict';

// Pure helpers for the writes one user makes into another user's documents.
//
// Nothing here touches firebase-admin or the network, so it can be unit
// tested directly. index.js holds the parts that need Firestore.

// The two type strings the app actually sends. movie_result.dart passes
// 'movie' and tvshow_result.dart passes 'tvshow', and notifications.dart
// renders anything that is not 'movie' as a show -- so an unrecognised third
// value would not be rejected on arrival, it would quietly show up as a
// series. Pinning the pair here is what keeps the inbox honest.
const RECOMMENDABLE_TYPES = ['movie', 'tvshow'];

// Bounds rather than exact shapes: a callable is reachable by anything holding
// a valid ID token, so every string it stores in someone else's document has
// to have a ceiling. These are generous next to real TMDB values (the longest
// title in the catalogue is nowhere near 300 characters) and small enough that
// nobody can park a payload in a stranger's inbox.
const MAX_ID_LENGTH = 64;
const MAX_TITLE_LENGTH = 300;
const MAX_COVER_PHOTO_LENGTH = 500;
const MAX_UID_LENGTH = 128; // Firebase's own ceiling for a uid.
const MAX_USERNAME_LENGTH = 100;
const MAX_FRIENDS_PER_CALL = 50;

// A value containing a slash addresses a nested collection, one containing
// dots hits Firestore's `.` and `..` path segments, and `__x__` is the
// reserved form Firestore keeps for itself. Underscores and hyphens are
// allowed because real uids and the repo's own fixtures use them.
const UID_PATTERN = /^[A-Za-z0-9_-]+$/;
const RESERVED_UID_PATTERN = /^__.*__$/;

// The collections that belong to the app rather than to a user. A caller who
// could name one of these would have the server write a junk document into
// shared data -- `Watchlists/Notifications`, say -- so they are refused even
// though they are otherwise well formed. Kept in step with the list in
// people_scores.js, which excludes the same collections for the same reason.
const SHARED_COLLECTIONS = [
  'Oscars',
  'usernames',
  'Watchlists',
  'JoinAttempts',
  'Credits',
  'PeopleScoreJobs',
];

function trimmedString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

// Turns the payload of a recommendTitle call into the fields worth storing,
// or says why it cannot.
//
// `sender` is deliberately absent from the result even if the caller sent one.
// It used to be built on the writer's device and believed, which is how a
// friend could file a recommendation in your inbox under a third party's name.
// The server derives it from the auth context instead, so anything the payload
// claims about who is recommending is dropped here rather than overruled later.
function normalizeRecommendRequest(data) {
  const id = trimmedString(data?.id);
  const type = trimmedString(data?.type);
  const title = trimmedString(data?.title);
  const coverPhoto = trimmedString(data?.coverPhoto);

  if (id === '' || title === '') {
    return { ok: false, reason: 'missing' };
  }
  if (!RECOMMENDABLE_TYPES.includes(type)) {
    return { ok: false, reason: 'type' };
  }
  if (
    id.length > MAX_ID_LENGTH ||
    title.length > MAX_TITLE_LENGTH ||
    coverPhoto.length > MAX_COVER_PHOTO_LENGTH
  ) {
    return { ok: false, reason: 'too-long' };
  }

  const friends = normalizeFriendList(data?.friends);
  if (!friends.ok) return friends;

  return { ok: true, id, type, title, coverPhoto, friends: friends.uids };
}

// The recipients. Duplicates are collapsed because sending the same title to
// the same person twice in one call is never what was meant, and each one
// would otherwise cost a transaction and land as a second inbox entry.
function normalizeFriendList(value) {
  if (!Array.isArray(value) || value.length === 0) {
    return { ok: false, reason: 'no-friends' };
  }
  if (value.length > MAX_FRIENDS_PER_CALL) {
    return { ok: false, reason: 'too-many-friends' };
  }

  const uids = [];
  for (const entry of value) {
    const uid = trimmedString(entry);
    if (!isUsableUid(uid)) {
      return { ok: false, reason: 'bad-friend' };
    }
    if (!uids.includes(uid)) uids.push(uid);
  }
  return { ok: true, uids };
}

// Whether a string is safe to use as the name of a user's own collection.
//
// A recipient uid names a top-level COLLECTION the server then writes to with
// admin credentials, which makes it a path rather than just a string. Left
// unchecked, "recommend to a friend" becomes "write wherever I say".
function isUsableUid(uid) {
  if (typeof uid !== 'string') return false;
  if (uid === '' || uid.length > MAX_UID_LENGTH) return false;
  if (!UID_PATTERN.test(uid)) return false;
  if (RESERVED_UID_PATTERN.test(uid)) return false;
  return !SHARED_COLLECTIONS.includes(uid);
}

// The key a new notification takes in a recipient's Notifications document.
//
// LOAD-BEARING, and not an implementation detail. `appendsOneNotificationOnly`
// in firestore.rules cannot name the key a write adds -- diff() hands back a
// Set, and rules cannot index a Set -- so it REBUILDS the key as
// `string(resource.data.keys().size())` and reads the value there. That only
// works while every writer appends at exactly the number of keys already
// present, and builds already on people's phones write directly with that
// scheme (see lib/popups/share.dart).
//
// So: not a uuid, not a timestamp, not a random number. Any of those makes the
// document sparse, and from that moment the rule rebuilds a key that is
// already taken, an old client's next write reads as a change rather than an
// add, and the recommendation is refused forever with nothing said.
function nextNotificationKey(notifications) {
  return String(notificationKeyCount(notifications));
}

function notificationKeyCount(notifications) {
  if (!notifications || typeof notifications !== 'object') return 0;
  if (Array.isArray(notifications)) return 0;
  return Object.keys(notifications).length;
}

// True when appending at the dense key would be safe, which means the keys are
// exactly "0".."n-1" with nothing missing, nothing repeated and nothing that is
// not a plain non-negative integer.
//
// Checking only whether `String(count)` is already taken is not enough, and the
// difference bites: {0, 3} has two keys, so that check picks "2", finds it free
// and writes -- leaving {0, 2, 3}, where the next dense key IS taken. An old
// client could still append to {0, 3}; it cannot append to what this would have
// made of it. So the test has to be density itself, not the absence of one
// collision.
function isDenselyKeyed(notifications) {
  if (notifications === undefined || notifications === null) return true;
  if (typeof notifications !== 'object' || Array.isArray(notifications)) {
    return false;
  }

  const keys = Object.keys(notifications);
  const seen = new Set();
  for (const key of keys) {
    // String(Number(key)) rejects "01", "1.0", "+1", " 1" and "1e0", each of
    // which is a number rules would never rebuild as that key.
    const index = Number(key);
    if (!Number.isInteger(index) || index < 0) return false;
    if (String(index) !== key) return false;
    if (index >= keys.length) return false;
    if (seen.has(index)) return false;
    seen.add(index);
  }
  return true;
}

// True when `uid` appears in a Friends document's `friends` array.
//
// Callers pass the TARGET's document, never the caller's own, which mirrors
// friendOf() in firestore.rules: anyone can write their own friends list, so
// trusting it would let a stranger add you and reach your inbox.
function listsFriend(friendsDocData, uid) {
  const friends = friendsDocData?.friends;
  if (!Array.isArray(friends)) return false;
  return friends.includes(uid);
}

// The stored entry, minus `timestamp` -- that is a server sentinel and cannot
// be produced without firebase-admin. Kept here so the shape validNotification()
// in firestore.rules checks is written down beside the key scheme it depends on.
function buildNotification({ id, type, title, coverPhoto, senderUid, senderUsername }) {
  const username =
    typeof senderUsername === 'string' ? senderUsername.trim() : '';

  return {
    type,
    id,
    title,
    coverPhoto,
    sender: {
      // Bounded because it is the caller's own Settings document being copied
      // into up to MAX_FRIENDS_PER_CALL other people's inboxes: unbounded, one
      // call could park a very large string in every one of them. It stays
      // spoofable as a DISPLAY name -- usernames are not unique and the owner
      // writes their own -- which is why `uid` beside it is the field anything
      // making a decision should read.
      username: username.slice(0, MAX_USERNAME_LENGTH),
      uid: senderUid,
    },
    read: false,
  };
}

module.exports = {
  normalizeRecommendRequest,
  normalizeFriendList,
  nextNotificationKey,
  isDenselyKeyed,
  isUsableUid,
  listsFriend,
  buildNotification,
  RECOMMENDABLE_TYPES,
  MAX_ID_LENGTH,
  MAX_TITLE_LENGTH,
  MAX_COVER_PHOTO_LENGTH,
  MAX_UID_LENGTH,
  MAX_USERNAME_LENGTH,
  MAX_FRIENDS_PER_CALL,
  SHARED_COLLECTIONS,
};
