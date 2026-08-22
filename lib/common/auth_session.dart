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
    await clearPerUserCaches();
  }

  /// Clears caches that are scoped to the signed-in user.
  ///
  /// Async because the media sort cache is now also kept on disk, and a file
  /// left behind is exactly the leak this exists to prevent. Callers must
  /// await it before another account can sign in.
  /// @return Completes once every per-user cache is gone.
  static Future<void> clearPerUserCaches() async {
    FriendsService.clearCache();
    await MediaSortLoader.clearCache();
  }

  @visibleForTesting
  static void setAuthSignOutForTest(Future<void> Function() authSignOut) {
    _authSignOut = authSignOut;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _authSignOut = () => FirebaseAuth.instance.signOut();
    await clearPerUserCaches();
  }
}
