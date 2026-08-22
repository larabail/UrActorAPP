/// Tests for how a sign in failure is classified.
///
/// The sign in button used to name exactly two error codes and do nothing at
/// all for anything else, so a failure outside those two looked like a button
/// that did not work. That is how `keychain-error` on macOS presented: correct
/// credentials, no message, no navigation, nothing in the interface to act on.
///
/// The point of these is the default case. Firebase adds codes over time and
/// returns different ones depending on how the project is configured, so the
/// mapping has to answer for a code it has never seen.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/auth_error.dart';

void main() {
  group('classifyAuthError', () {
    test('names the failures the app can be specific about', () {
      expect(
        classifyAuthError(FirebaseAuthException(code: 'user-not-found')),
        AuthFailure.noUser,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'wrong-password')),
        AuthFailure.wrongPassword,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'invalid-email')),
        AuthFailure.invalidEmail,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'user-disabled')),
        AuthFailure.userDisabled,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'too-many-requests')),
        AuthFailure.tooManyRequests,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'network-request-failed')),
        AuthFailure.network,
      );
    });

    test('still classifies the platform failure that started this', () {
      // macOS: Firebase Auth cannot reach the keychain unless the app is
      // signed and entitled for it. The credentials are irrelevant, and the
      // old code said nothing whatsoever.
      expect(
        classifyAuthError(FirebaseAuthException(code: 'keychain-error')),
        AuthFailure.unknown,
      );
    });

    test('names a caller the API key refuses, whatever code carries it', () {
      // What a macOS build actually gets today. It borrows the iOS Firebase
      // registration, and its bundle id is not on that key's iOS app list, so
      // Identity Toolkit answers 403 before looking at the password. The SDK
      // wraps that in a generic `internal-error`, so only the reason token
      // inside the message says what happened.
      expect(
        classifyAuthError(
          FirebaseAuthException(
            code: 'internal-error',
            message:
                'Error Domain=FIRAuthErrorDomain Code=17999 UserInfo={'
                'reason = "API_KEY_IOS_APP_BLOCKED"; status = "PERMISSION_DENIED"; '
                'message = "Requests from this iOS client application '
                'com.uractor.uractormacos are blocked.";}',
          ),
        ),
        AuthFailure.blockedApp,
      );

      // The same refusal on the other platforms the app ships to. None of
      // these has been met in the wild; they are the sibling reasons Google
      // documents for the identical cause, and cost nothing to answer for.
      for (final reason in <String>[
        'API_KEY_ANDROID_APP_BLOCKED',
        'API_KEY_HTTP_REFERRER_BLOCKED',
        'API_KEY_SERVICE_BLOCKED',
      ]) {
        expect(
          classifyAuthError(
            FirebaseAuthException(code: 'internal-error', message: reason),
          ),
          AuthFailure.blockedApp,
          reason: '$reason should be recognised as a blocked caller',
        );
      }
    });

    test('does not mistake an ordinary internal error for a blocked app', () {
      // The check is on the reason token, not on the code, so a genuine
      // server-side fault has to keep falling through to the generic message.
      // Reading `internal-error` itself as "blocked" would tell people to give
      // up on a failure that retrying may well clear.
      expect(
        classifyAuthError(FirebaseAuthException(code: 'internal-error')),
        AuthFailure.unknown,
      );
      expect(
        classifyAuthError(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'An internal error has occurred.',
          ),
        ),
        AuthFailure.unknown,
      );
    });

    test('a blocked caller outranks the code it arrived wrapped in', () {
      // The 403 is the real failure and the code is only its wrapper, so the
      // reason has to be read first. Were the switch consulted first this
      // would come back as `network` and invite a pointless retry.
      expect(
        classifyAuthError(
          FirebaseAuthException(
            code: 'network-request-failed',
            message: 'reason = "API_KEY_IOS_APP_BLOCKED"',
          ),
        ),
        AuthFailure.blockedApp,
      );
    });

    test('classifies a code it has never seen rather than giving up', () {
      // Firebase returns this instead of user-not-found and wrong-password
      // when email enumeration protection is on, which is the default for new
      // projects. Neither of the two codes the app used to check for is ever
      // sent in that configuration.
      expect(
        classifyAuthError(FirebaseAuthException(code: 'invalid-credential')),
        AuthFailure.unknown,
      );
      expect(
        classifyAuthError(FirebaseAuthException(code: 'not-a-real-code')),
        AuthFailure.unknown,
      );
    });

    test('classifies something that is not a Firebase error at all', () {
      expect(classifyAuthError(StateError('boom')), AuthFailure.unknown);
      expect(classifyAuthError('a bare string'), AuthFailure.unknown);
    });

    test('every failure is one the interface has a message for', () {
      // A value added here without a message would be a silent button again,
      // which is the whole defect. `authFailureMessage` switches exhaustively
      // over this enum, so the analyzer enforces the pair -- this asserts the
      // enum is not empty and that classification never returns null.
      for (final code in <String>[
        'user-not-found',
        'wrong-password',
        'invalid-email',
        'user-disabled',
        'too-many-requests',
        'network-request-failed',
        'keychain-error',
        'internal-error',
        'anything-else',
      ]) {
        expect(
          AuthFailure.values,
          contains(classifyAuthError(FirebaseAuthException(code: code))),
        );
      }
    });
  });
}
