import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCore {
  static FirebaseFirestore? _db;

  /// The Firestore instance every service reads and writes through.
  ///
  /// Services used to name `FirebaseFirestore.instance` directly, which
  /// requires a live Firebase app and so could not run under `flutter test`.
  /// Routing through here lets tests substitute an in-memory instance.
  ///
  /// Resolved lazily: touching `FirebaseFirestore.instance` at field
  /// initialisation would throw in a test binding before a fake is installed.
  static FirebaseFirestore get db => _db ??= FirebaseFirestore.instance;

  static set db(FirebaseFirestore value) {
    _db = value;
  }

  /// Drops the override so the next read resolves the real instance again.
  static void resetDb() {
    _db = null;
  }

  /// Retrieves a Firestore document's reference, snapshot, and data for a given user and document name.
  /// @param uid The user ID whose document is being retrieved.
  /// @param docName The name of the document.
  /// @return A map containing the document's reference, snapshot, and data.
  static Future<Map> getDocumentData(String uid, String docName) async {
    var snapshot = FirebaseFirestore.instance.collection(uid).doc(docName);
    DocumentSnapshot doc = await snapshot.get();
    Map data = {};
    if (doc.exists) {
      data = doc.data() as Map;
    }
    return {"snapshot": snapshot, "doc": doc, "data": data};
  }

  /// Returns a Firestore document reference for a specific user and document name.
  /// @param uid The user ID.
  /// @param docName The document name.
  /// @return The Firestore document reference.
  static Future<DocumentReference> getDocument(
      String uid, String docName) async {
    DocumentReference userDoc =
        FirebaseFirestore.instance.collection(uid).doc(docName);
    return userDoc;
  }

  /// Updates a specified document in Firestore with new data.
  /// @param uid The user ID whose document is being updated.
  /// @param docName The name of the document.
  /// @param data The data to update in the document.
  static Future<void> updateDocument(String uid, String docName, data) async {
    DocumentReference doc = await getDocument(uid, docName);
    await doc.update(data);
  }
}
