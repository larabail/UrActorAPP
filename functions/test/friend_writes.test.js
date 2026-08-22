'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeRecommendRequest,
  normalizeFriendList,
  nextNotificationKey,
  isDenselyKeyed,
  isUsableUid,
  listsFriend,
  buildNotification,
  MAX_ID_LENGTH,
  MAX_TITLE_LENGTH,
  MAX_COVER_PHOTO_LENGTH,
  MAX_UID_LENGTH,
  MAX_USERNAME_LENGTH,
  MAX_FRIENDS_PER_CALL,
  SHARED_COLLECTIONS,
} = require('../friend_writes');

const validPayload = {
  id: '27205',
  type: 'movie',
  title: 'Inception',
  coverPhoto: 'https://image.tmdb.org/t/p/w500/cover.jpg',
  friends: ['friend-a'],
};

test('normalizeRecommendRequest keeps a well formed payload', () => {
  const parsed = normalizeRecommendRequest(validPayload);

  assert.equal(parsed.ok, true);
  assert.equal(parsed.id, '27205');
  assert.equal(parsed.type, 'movie');
  assert.equal(parsed.title, 'Inception');
  assert.deepEqual(parsed.friends, ['friend-a']);
});

test('normalizeRecommendRequest never carries a sender through', () => {
  // The whole point of the callable: whatever the payload says about who is
  // recommending is dropped here, and the server derives it from the auth
  // context instead.
  const parsed = normalizeRecommendRequest({
    ...validPayload,
    sender: {uid: 'somebody-else', username: 'Impostor'},
  });

  assert.equal(parsed.ok, true);
  assert.equal(parsed.sender, undefined);
});

test('normalizeRecommendRequest trims the strings it keeps', () => {
  const parsed = normalizeRecommendRequest({
    ...validPayload,
    id: '  27205 ',
    title: '  Inception  ',
    friends: [' friend-a '],
  });

  assert.equal(parsed.id, '27205');
  assert.equal(parsed.title, 'Inception');
  assert.deepEqual(parsed.friends, ['friend-a']);
});

test('normalizeRecommendRequest accepts both type strings the app sends', () => {
  // movie_result.dart sends 'movie', tvshow_result.dart sends 'tvshow'.
  assert.equal(normalizeRecommendRequest({...validPayload, type: 'movie'}).ok, true);
  assert.equal(normalizeRecommendRequest({...validPayload, type: 'tvshow'}).ok, true);
});

test('normalizeRecommendRequest refuses any other type', () => {
  // notifications.dart renders anything that is not 'movie' as a show, so an
  // unrecognised value is not caught on arrival -- it just displays wrongly.
  for (const type of ['series', 'Movies', '', null, 42, {}]) {
    const parsed = normalizeRecommendRequest({...validPayload, type});
    assert.equal(parsed.ok, false, `accepted type ${JSON.stringify(type)}`);
  }
  assert.equal(normalizeRecommendRequest({...validPayload, type: 'series'}).reason, 'type');
});

test('normalizeRecommendRequest requires an id and a title', () => {
  assert.equal(normalizeRecommendRequest({...validPayload, id: ''}).reason, 'missing');
  assert.equal(normalizeRecommendRequest({...validPayload, id: '   '}).reason, 'missing');
  assert.equal(normalizeRecommendRequest({...validPayload, id: 42}).reason, 'missing');
  assert.equal(normalizeRecommendRequest({...validPayload, title: ''}).reason, 'missing');
  assert.equal(normalizeRecommendRequest({...validPayload, title: null}).reason, 'missing');
});

test('normalizeRecommendRequest allows a missing cover photo', () => {
  // A title with no poster is normal; TMDB leaves poster_path null.
  const parsed = normalizeRecommendRequest({...validPayload, coverPhoto: undefined});

  assert.equal(parsed.ok, true);
  assert.equal(parsed.coverPhoto, '');
});

test('normalizeRecommendRequest bounds every string it stores', () => {
  // A callable is reachable by anyone holding a valid ID token, and each of
  // these ends up in a stranger's document.
  assert.equal(
    normalizeRecommendRequest({...validPayload, id: 'x'.repeat(MAX_ID_LENGTH + 1)}).reason,
    'too-long',
  );
  assert.equal(
    normalizeRecommendRequest({...validPayload, title: 'x'.repeat(MAX_TITLE_LENGTH + 1)}).reason,
    'too-long',
  );
  assert.equal(
    normalizeRecommendRequest({
      ...validPayload,
      coverPhoto: 'x'.repeat(MAX_COVER_PHOTO_LENGTH + 1),
    }).reason,
    'too-long',
  );
  assert.equal(
    normalizeRecommendRequest({...validPayload, id: 'x'.repeat(MAX_ID_LENGTH)}).ok,
    true,
  );
});

test('normalizeRecommendRequest survives a payload that is not an object', () => {
  for (const data of [undefined, null, 'text', 42, []]) {
    assert.equal(normalizeRecommendRequest(data).ok, false);
  }
});

test('normalizeFriendList requires at least one recipient', () => {
  assert.equal(normalizeFriendList([]).reason, 'no-friends');
  assert.equal(normalizeFriendList(undefined).reason, 'no-friends');
  assert.equal(normalizeFriendList('friend-a').reason, 'no-friends');
});

test('normalizeFriendList rejects an entry that is not a usable uid', () => {
  assert.equal(normalizeFriendList(['friend-a', '']).reason, 'bad-friend');
  assert.equal(normalizeFriendList(['friend-a', '   ']).reason, 'bad-friend');
  assert.equal(normalizeFriendList([null]).reason, 'bad-friend');
  assert.equal(normalizeFriendList([{uid: 'friend-a'}]).reason, 'bad-friend');
  assert.equal(normalizeFriendList(['x'.repeat(MAX_UID_LENGTH + 1)]).reason, 'bad-friend');
});

test('normalizeFriendList refuses a uid that is really a path', () => {
  // The uid names a top-level collection the server then writes to with admin
  // credentials, so it is a path, not just a string. A slash reaches a nested
  // collection and the reserved forms reach Firestore's own namespace.
  assert.equal(normalizeFriendList(['a/b/c']).reason, 'bad-friend');
  assert.equal(normalizeFriendList(['Watchlists/list/Notifications']).reason,
      'bad-friend');
  assert.equal(normalizeFriendList(['.']).reason, 'bad-friend');
  assert.equal(normalizeFriendList(['..']).reason, 'bad-friend');
  assert.equal(normalizeFriendList(['__id__']).reason, 'bad-friend');
});

test('normalizeFriendList refuses a collection the app owns', () => {
  // Otherwise a caller who can create `Watchlists/Friends` listing themselves
  // gets the server to write `Watchlists/Notifications` for them.
  for (const collection of SHARED_COLLECTIONS) {
    assert.equal(
      normalizeFriendList([collection]).reason,
      'bad-friend',
      `accepted the shared collection ${collection}`,
    );
  }
});

test('isUsableUid accepts what Firebase actually issues', () => {
  // Firebase uids are 28 alphanumeric characters; the app's own tests and
  // backfill tools also use hyphenated names.
  assert.equal(isUsableUid('kR3nB7xQ1mZaWt5YpLcVdEfGhIj2'), true);
  assert.equal(isUsableUid('friend-a'), true);
  assert.equal(isUsableUid('people_scores_1'), true);
  assert.equal(isUsableUid(''), false);
  assert.equal(isUsableUid(undefined), false);
});

test('normalizeFriendList caps how many people one call can reach', () => {
  const many = Array.from({length: MAX_FRIENDS_PER_CALL}, (_, i) => `friend-${i}`);

  assert.equal(normalizeFriendList(many).ok, true);
  assert.equal(normalizeFriendList([...many, 'one-too-many']).reason, 'too-many-friends');
});

test('normalizeFriendList collapses a repeated uid', () => {
  // Otherwise the same person gets the same title twice from one tap.
  assert.deepEqual(
    normalizeFriendList(['friend-a', 'friend-a', 'friend-b']).uids,
    ['friend-a', 'friend-b'],
  );
});

test('nextNotificationKey is the count of existing keys, as a string', () => {
  // LOAD-BEARING. appendsOneNotificationOnly() in firestore.rules rebuilds the
  // appended key as string(resource.data.keys().size()) and reads the value
  // there. A uuid, a timestamp or a random number would leave the document
  // sparse, and every later write from a client already on someone's phone
  // would read as a change rather than an add and be refused -- silently.
  assert.equal(nextNotificationKey({}), '0');
  assert.equal(nextNotificationKey({0: {}}), '1');
  assert.equal(nextNotificationKey({0: {}, 1: {}, 2: {}}), '3');
});

test('nextNotificationKey treats a missing inbox as an empty one', () => {
  // The document only appears once something has been written to it, so a
  // brand new user has none.
  assert.equal(nextNotificationKey(undefined), '0');
  assert.equal(nextNotificationKey(null), '0');
});

test('nextNotificationKey and the rules agree on every dense document', () => {
  // The coupling stated as the rule states it: for any densely keyed inbox,
  // the key this function picks is exactly the one firestore.rules will look
  // under, appending there is safe, and the result is dense again.
  for (let size = 0; size < 25; size++) {
    const inbox = {};
    for (let i = 0; i < size; i++) inbox[String(i)] = {read: false};

    const key = nextNotificationKey(inbox);
    assert.equal(key, String(Object.keys(inbox).length));
    assert.equal(isDenselyKeyed(inbox), true);

    inbox[key] = {read: false};
    assert.equal(isDenselyKeyed(inbox), true, 'appending left a gap');
    assert.deepEqual(
      Object.keys(inbox).sort((a, b) => Number(a) - Number(b)),
      Array.from({length: size + 1}, (_, i) => String(i)),
    );
  }
});

test('isDenselyKeyed accepts an inbox with no gaps', () => {
  assert.equal(isDenselyKeyed({}), true);
  assert.equal(isDenselyKeyed({0: {}}), true);
  assert.equal(isDenselyKeyed({0: {}, 1: {}, 2: {}}), true);
  // Firestore hands back an object; key order is not part of density.
  assert.equal(isDenselyKeyed({2: {}, 0: {}, 1: {}}), true);
});

test('isDenselyKeyed treats a missing inbox as appendable', () => {
  // Nothing has ever been written, so '0' is free by definition.
  assert.equal(isDenselyKeyed(undefined), true);
  assert.equal(isDenselyKeyed(null), true);
});

test('isDenselyKeyed rejects every shape of gap, not just a collision', () => {
  // {0, 3} is the one a "does String(count) already exist?" check misses: the
  // count is 2, '2' is free, so that check writes -- and leaves {0, 2, 3},
  // whose dense key IS taken. An old client can append to {0, 3}; it can never
  // append to what that would have made of it.
  assert.equal(isDenselyKeyed({0: {}, 3: {}}), false);
  assert.equal(isDenselyKeyed({0: {}, 2: {}}), false);
  assert.equal(isDenselyKeyed({1: {}}), false);
  assert.equal(isDenselyKeyed({2: {}}), false);
});

test('isDenselyKeyed rejects keys the rules would never rebuild', () => {
  // string(size) produces '1', never '01', '1.0' or 'inbox'. A key of any
  // other shape means something other than an append has been here.
  assert.equal(isDenselyKeyed({0: {}, '01': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, '1.0': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, ' 1': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, '+1': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, '1e0': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, '-1': {}}), false);
  assert.equal(isDenselyKeyed({0: {}, latest: {}}), false);
  assert.equal(isDenselyKeyed('not a map'), false);
});

test('listsFriend reads the friends array of the document it is given', () => {
  assert.equal(listsFriend({friends: ['alice', 'bob']}, 'bob'), true);
  assert.equal(listsFriend({friends: ['alice']}, 'bob'), false);
});

test('listsFriend refuses anything that is not a friends array', () => {
  // A Friends document is created lazily, so a user who has never had a
  // friend request has none at all.
  assert.equal(listsFriend(undefined, 'bob'), false);
  assert.equal(listsFriend({}, 'bob'), false);
  assert.equal(listsFriend({friends: 'bob'}, 'bob'), false);
  assert.equal(listsFriend({friends: null}, 'bob'), false);
});

test('buildNotification produces the shape the rules validate', () => {
  const notification = buildNotification({
    id: '27205',
    type: 'movie',
    title: 'Inception',
    coverPhoto: '/cover.jpg',
    senderUid: 'alice',
    senderUsername: 'Alice',
  });

  assert.deepEqual(notification, {
    type: 'movie',
    id: '27205',
    title: 'Inception',
    coverPhoto: '/cover.jpg',
    sender: {username: 'Alice', uid: 'alice'},
    read: false,
  });
});

test('buildNotification always starts a notification unread', () => {
  // The inbox badge counts unread ones, so one that arrives read is one the
  // recipient never notices.
  assert.equal(buildNotification({senderUid: 'alice'}).read, false);
});

test('buildNotification bounds the username it copies out', () => {
  // It is read from the caller's own Settings document and fanned into up to
  // MAX_FRIENDS_PER_CALL other people's inboxes, so its size is the caller's
  // to choose unless something caps it.
  const notification = buildNotification({
    senderUid: 'alice',
    senderUsername: 'A'.repeat(MAX_USERNAME_LENGTH + 500),
  });

  assert.equal(notification.sender.username.length, MAX_USERNAME_LENGTH);
});

test('buildNotification falls back to an empty username', () => {
  // Settings is written lazily too, and notifications.dart interpolates the
  // username straight into the message rather than null-checking it.
  assert.equal(buildNotification({senderUid: 'alice'}).sender.username, '');
  assert.equal(
    buildNotification({senderUid: 'alice', senderUsername: 42}).sender.username,
    '',
  );
});
