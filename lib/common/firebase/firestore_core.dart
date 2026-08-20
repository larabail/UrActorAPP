import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCore {
  static FirebaseFirestore? _db;

  /// The Firestore instance used by this class, resolved lazily so tests can
  /// install a fake before it is ever touched. Resolving it eagerly (e.g. as
  /// a field initialiser) would call `FirebaseFirestore.instance` before a
  /// test gets a chance to swap it in, which throws outside a real app.
  static FirebaseFirestore get db => _db ??= FirebaseFirestore.instance;
  static set db(FirebaseFirestore value) => _db = value;

  /// Clears any injected test instance so a leaked fake cannot leak into a
  /// later test or into real app usage. Call this in test teardown.
  static void resetDb() => _db = null;

  /// Retrieves a Firestore document's reference, snapshot, and data for a given user and document name.
  /// @param uid The user ID whose document is being retrieved.
  /// @param docName The name of the document.
  /// @return A map containing the document's reference, snapshot, and data.
  static Future<Map> getDocumentData(String uid, String docName) async {
    var snapshot = db.collection(uid).doc(docName);
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
    DocumentReference userDoc = db.collection(uid).doc(docName);
    return userDoc;
  }

  /// Updates a specified document in Firestore with new data, creating it if
  /// it does not exist yet.
  ///
  /// This used `update()`, which fails with `not-found` when the document is
  /// missing rather than creating it. Nothing in the app creates the eighteen
  /// per-user documents up front -- they only appear once something is written
  /// to them -- so the first calendar entry, the first title marked seen and
  /// the first rewatch on a new account all threw instead of saving. Merging a
  /// set writes exactly the keys it is handed, like update did, and creates
  /// the document when it is absent.
  ///
  /// The one behavioural difference is that `set` treats a key containing a
  /// dot as a literal key where `update` would read it as a path into a nested
  /// map. Every caller here passes document names, dates, media ids or type
  /// names as keys, none of which contain dots, so nothing relies on that.
  ///
  /// @param uid The user ID whose document is being updated.
  /// @param docName The name of the document.
  /// @param data The data to update in the document.
  static Future<void> updateDocument(String uid, String docName, data) async {
    DocumentReference doc = await getDocument(uid, docName);
    await mergeInto(doc, data);
  }

  /// Writes [data] into [doc] as a merging set, creating the document if it
  /// does not exist instead of throwing `not-found` the way `update()` does.
  /// Use this for call sites that already hold a raw `DocumentReference`
  /// (rather than a `uid`/`docName` pair, which should go through
  /// [updateDocument] instead) so the same reasoning lives in one place.
  ///
  /// See [updateDocument] for the dotted-key caveat that applies here too.
  static Future<void> mergeInto(DocumentReference doc, data) async {
    await doc.set(Map<String, dynamic>.from(data), SetOptions(merge: true));
  }
}
