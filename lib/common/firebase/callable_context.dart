import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Runtime context needed by HTTPS callable wrappers.
///
/// Screens should not fetch Firebase globals themselves when the call is buried
/// in reusable logic. Keeping these providers overridable gives tests the same
/// seam as `AppHttp.client` and `FirestoreCore.db`.
class CallableContext {
  static Future<String?> Function() idToken = _defaultIdToken;
  static String Function() projectId = _defaultProjectId;

  static Future<String?> _defaultIdToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static String _defaultProjectId() => Firebase.app().options.projectId;

  static void reset() {
    idToken = _defaultIdToken;
    projectId = _defaultProjectId;
  }
}
