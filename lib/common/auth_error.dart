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

  /// The email and password did not match an account, and which of the two
  /// was wrong is not something the app is allowed to know.
  ///
  /// This is [noUser] and [wrongPassword] collapsed into one answer, which is
  /// what Firebase sends once email enumeration protection is turned on for
  /// the project. It stops sending the two codes that tell them apart and
  /// sends `invalid-credential` for both, deliberately: a client that can say
  /// "no account exists for that address" is an oracle for whether a given
  /// person has one, and anybody holding the API key can ask it. Every
  /// Firebase client key ships inside a binary, so that is anybody who wants
  /// to.
  ///
  /// Both of those are kept, because the setting is per project and either
  /// answer is a valid thing for a server to send. This is the third case, not
  /// their replacement.
  ///
  /// The message for it cannot be more specific than the code is, and must not
  /// try. Naming the half that was wrong is exactly what the setting exists to
  /// prevent, so a message that guessed would hand back what the server
  /// withheld.
  invalidCredential,

  /// The email was not a valid address.
  invalidEmail,

  /// The account has been disabled.
  userDisabled,

  /// Too many attempts; the account is temporarily locked out.
  tooManyRequests,

  /// The device could not reach Firebase at all.
  network,

  /// Firebase refused the app rather than the credentials.
  ///
  /// A Google API key can be restricted to a list of callers, and Identity
  /// Toolkit rejects anything not on it with 403 before a password is ever
  /// looked at. Every account then fails, on every attempt, with a correct
  /// password — which is indistinguishable from the app being broken.
  ///
  /// This is worth separating from [unknown] because the advice is the
  /// opposite. Every other failure here is something the person can act on by
  /// trying again, or trying something else. This one cannot be: the app they
  /// are holding is not allowed to talk to the project, and nothing they do
  /// with the form will change that.
  blockedApp,

  /// Anything else.
  ///
  /// This is not a rare case to be ignored. Firebase adds error codes over
  /// time, and a platform can produce its own failures too: on macOS the
  /// keychain is unreachable unless the app is signed and entitled for it, and
  /// Firebase reports that here.
  ///
  /// Whatever the cause, the person in front of the app has to be told that
  /// something failed. Saying nothing is the one response that is always
  /// wrong.
  unknown,
}

/// The reasons Google gives for refusing a caller outright.
///
/// These arrive inside a generic `internal-error`, so the code alone cannot
/// tell this apart from any other server-side fault; the reason token is the
/// only thing that names it. They are matched rather than the prose beside
/// them because the prose is localized and rewordable and these are neither.
///
/// All four are the same failure wearing different clothes — the key does not
/// list this caller — and the app ships on every platform that can produce
/// one, so they are handled together rather than waiting to be met singly.
const _blockedCallerReasons = <String>[
  // The bundle id is not on the key's iOS app list. This is what a macOS
  // build hits when it borrows the iOS registration and is not itself on it.
  'API_KEY_IOS_APP_BLOCKED',
  // The package name and signing certificate are not on the Android list.
  'API_KEY_ANDROID_APP_BLOCKED',
  // The origin is not on the key's referrer list.
  'API_KEY_HTTP_REFERRER_BLOCKED',
  // The key is valid for this caller but not for Identity Toolkit.
  'API_KEY_SERVICE_BLOCKED',
];

/// Classifies [error] from a sign in or sign up attempt.
AuthFailure classifyAuthError(Object error) {
  if (error is! FirebaseAuthException) return AuthFailure.unknown;

  // Read before the code, because the code carrying this is whatever generic
  // fault the platform SDK wrapped the 403 in. Taking the code first would
  // file the failure under that generic name and lose what it actually was.
  final details = error.message?.toUpperCase();
  if (details != null &&
      _blockedCallerReasons.any(details.contains)) {
    return AuthFailure.blockedApp;
  }

  switch (error.code) {
    case 'user-not-found':
      return AuthFailure.noUser;
    case 'wrong-password':
      return AuthFailure.wrongPassword;
    case 'invalid-credential':
      return AuthFailure.invalidCredential;
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
    case AuthFailure.invalidCredential:
      return S.of(context)!.invalidCredentialError;
    case AuthFailure.invalidEmail:
      return S.of(context)!.invalidEmailError;
    case AuthFailure.userDisabled:
      return S.of(context)!.userDisabledError;
    case AuthFailure.tooManyRequests:
      return S.of(context)!.tooManyRequestsError;
    case AuthFailure.network:
      return S.of(context)!.networkError;
    case AuthFailure.blockedApp:
      return S.of(context)!.blockedAppError;
    case AuthFailure.unknown:
      return S.of(context)!.genericAuthError;
  }
}
