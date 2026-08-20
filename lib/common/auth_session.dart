import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase/friends_service.dart';
import 'media_sort_loader.dart';

/// Owns auth-session exits that must also clear per-user in-memory state.
class AuthSession {
  static Future<void> Function() _authSignOut =
      () => FirebaseAuth.instance.signOut();

  /// Signs out of Firebase and drops data cached for the previous user.
  static Future<void> signOut() async {
    await _authSignOut();
    clearPerUserCaches();
  }

  /// Clears caches that are scoped to the signed-in user.
  static void clearPerUserCaches() {
    FriendsService.clearCache();
    MediaSortLoader.clearCache();
  }

  @visibleForTesting
  static void setAuthSignOutForTest(Future<void> Function() authSignOut) {
    _authSignOut = authSignOut;
  }

  @visibleForTesting
  static void resetForTest() {
    _authSignOut = () => FirebaseAuth.instance.signOut();
    clearPerUserCaches();
  }
}
