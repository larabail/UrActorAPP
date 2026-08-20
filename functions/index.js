const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Push notifications were removed: the Flutter client never registers an
// `fcmToken` (no `firebase_messaging` dependency anywhere in lib/), so the
// previous `sendFriendRequestNotification` trigger always read an undefined
// token and never sent anything. It also called `admin.messaging()
// .sendToDevice(...)`, which used the legacy FCM API decommissioned by
// Google in June 2024, so it would have thrown even if a token existed.
//
// A future implementation must first add `firebase_messaging` on the
// client, persist a real token to Firestore, and then use
// `admin.messaging().send(...)` (the current FCM API) here.
