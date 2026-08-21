/// Turning a sign in failure into something a person can act on.
///
/// Kept apart from the screens so the mapping can be tested without a widget
/// or a live Firebase, and so the sign in and sign up forms cannot drift into
/// describing the same failure differently.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// The kinds of sign in failure the app has something specific to say about.
enum AuthFailure {
  /// No account exists for the email given.
  noUser,

  /// The account exists and the password was wrong.
  wrongPassword,

  /// The email was not a valid address.
  invalidEmail,

  /// The account has been disabled.
  userDisabled,

  /// Too many attempts; the account is temporarily locked out.
  tooManyRequests,

  /// The device could not reach Firebase at all.
  network,

  /// Anything else.
  ///
  /// This is not a rare case to be ignored. Firebase adds error codes over
  /// time, and returns codes that depend on how the project is configured —
  /// with email enumeration protection turned on, a wrong password and an
  /// unknown account both come back as `invalid-credential` rather than as
  /// the two codes the app used to check for. A platform can produce its own
  /// failures too: on macOS the keychain is unreachable unless the app is
  /// signed and entitled for it, and Firebase reports that here.
  ///
  /// Whatever the cause, the person in front of the app has to be told that
  /// something failed. Saying nothing is the one response that is always
  /// wrong.
  unknown,
}

/// Classifies [error] from a sign in or sign up attempt.
AuthFailure classifyAuthError(Object error) {
  if (error is! FirebaseAuthException) return AuthFailure.unknown;

  switch (error.code) {
    case 'user-not-found':
      return AuthFailure.noUser;
    case 'wrong-password':
      return AuthFailure.wrongPassword;
    case 'invalid-email':
      return AuthFailure.invalidEmail;
    case 'user-disabled':
      return AuthFailure.userDisabled;
    case 'too-many-requests':
      return AuthFailure.tooManyRequests;
    case 'network-request-failed':
      return AuthFailure.network;
    default:
      return AuthFailure.unknown;
  }
}

/// What to tell the user about [failure].
///
/// Every case returns something. There is no path here that leaves the user
/// looking at a button that appears not to work.
String authFailureMessage(BuildContext context, AuthFailure failure) {
  switch (failure) {
    case AuthFailure.noUser:
      return S.of(context)!.noUserFoundError;
    case AuthFailure.wrongPassword:
      return S.of(context)!.wrongPasswordError;
    case AuthFailure.invalidEmail:
      return S.of(context)!.invalidEmailError;
    case AuthFailure.userDisabled:
      return S.of(context)!.userDisabledError;
    case AuthFailure.tooManyRequests:
      return S.of(context)!.tooManyRequestsError;
    case AuthFailure.network:
      return S.of(context)!.networkError;
    case AuthFailure.unknown:
      return S.of(context)!.genericAuthError;
  }
}
