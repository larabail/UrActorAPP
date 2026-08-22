import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uractor/common/firebase/firestore_core.dart';

/// Asks the server to (re)compute the favourite actor, director and writer
/// scores.
///
/// Normally nothing here is needed: `markPeopleScoresDirty` in
/// `functions/index.js` notices every write to a library document and queues
/// the work by itself.
///
/// The gap it fills is the first run for an account that already exists. Those
/// users have scores left behind by the old person-page computation and no job
/// record, so without a nudge nothing would rescore them until they next
/// watched, favourited or listed something -- which for a dormant account
/// could be never, leaving them looking at a ranking of whoever they happened
/// to tap months ago.
class PeopleScoresService {
  static const String collection = 'PeopleScoreJobs';

  /// Queues a first recompute for [uid] when the server has never scored them.
  ///
  /// The job record's existence is the marker. The worker creates it on the
  /// first run and never deletes it, so this asks for a rebuild exactly once
  /// per account however often it is called, and costs one document read
  /// afterwards.
  ///
  /// Failures are swallowed on purpose. This runs as part of loading the home
  /// page, and a ranking that stays stale for now is not a reason to fail a
  /// sign in.
  static Future<void> requestInitialBuild(String uid) async {
    if (uid.isEmpty) return;
    try {
      final job = FirestoreCore.db.collection(collection).doc(uid);
      if ((await job.get()).exists) return;
      await job.set({'dirty': true, 'dirtyAt': FieldValue.serverTimestamp()});
    } catch (error) {
      debugPrint('Could not request a people score rebuild: $error');
    }
  }
}
