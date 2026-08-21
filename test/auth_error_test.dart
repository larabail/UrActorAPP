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
