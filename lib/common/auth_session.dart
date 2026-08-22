import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase/account_deletion_service.dart';
import 'firebase/friends_service.dart';
import 'media_sort_loader.dart';

/// Owns auth-session exits that must also clear per-user in-memory state.
class AuthSession {
  static Future<void> Function() _authSignOut =
      () => FirebaseAuth.instance.signOut();

  static Future<void> Function(String password) _reauthenticate =
      _reauthWithFirebase;

  static Future<void> Function() _authDelete =
      () => FirebaseAuth.instance.currentUser!.delete();

  /// Signs out of Firebase and drops data cached for the previous user.
  static Future<void> signOut() async {
    await _authSignOut();
    await clearPerUserCaches();
  }

  /// Closes the account for good: proves the password, erases the data, then
  /// deletes the login.
  ///
  /// The order is the whole point of this being one function rather than four
  /// calls at a call site. It used to run the other way round -- the diary was
  /// deleted first and the password checked afterwards -- so a typo destroyed
  /// everything the account held and then failed to delete the account itself.
  /// That is the one outcome nobody would choose, and there is no way back
  /// from it.
  ///
  /// Erasing the data must also happen while the login still exists, because
  /// the security rules authorise every one of those deletes against
  /// `request.auth`. Deleting the Firebase user first would leave the client
  /// holding data it is no longer allowed to touch.
  ///
  /// @param uid The account being closed.
  /// @param password The account's current password, to re-authenticate with.
  static Future<void> deleteAccount({
    required String uid,
    required String password,
  }) async {
    await _reauthenticate(password);
    await AccountDeletionService.purge(uid);
    await _authDelete();
    await clearPerUserCaches();
  }

  static Future<void> _reauthWithFirebase(String password) async {
    final user = FirebaseAuth.instance.currentUser!;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
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
  static void setAccountDeletionForTest({
    Future<void> Function(String password)? reauthenticate,
    Future<void> Function()? authDelete,
  }) {
    if (reauthenticate != null) _reauthenticate = reauthenticate;
    if (authDelete != null) _authDelete = authDelete;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _authSignOut = () => FirebaseAuth.instance.signOut();
    _reauthenticate = _reauthWithFirebase;
    _authDelete = () => FirebaseAuth.instance.currentUser!.delete();
    await clearPerUserCaches();
  }
}
