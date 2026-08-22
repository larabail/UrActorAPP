/// Tests for `PeopleScoresService`, which asks the server for a first
/// favourite-people recompute on an account that predates the server doing it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/people_scores_service.dart';
import 'package:uractor/common/firebase/firestore_core.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeopleScoresService.requestInitialBuild', () {
    test('queues a rebuild when the server has never scored the user', () async {
      final firestore = installFakeFirestore();

      await PeopleScoresService.requestInitialBuild('user-1');

      final job = await firestore
          .collection(PeopleScoresService.collection)
          .doc('user-1')
          .get();
      expect(job.exists, isTrue);
      expect(job.data()!['dirty'], isTrue);
    });

    test('leaves an existing job alone', () async {
      // The worker clears the flag when it finishes. Setting it again on every
      // launch would rescore an unchanged library for as long as the app is
      // opened.
      final firestore = installFakeFirestore();
      await firestore
          .collection(PeopleScoresService.collection)
          .doc('user-1')
          .set({'dirty': false, 'lastRunAt': DateTime(2024)});

      await PeopleScoresService.requestInitialBuild('user-1');

      final job = await firestore
          .collection(PeopleScoresService.collection)
          .doc('user-1')
          .get();
      expect(job.data()!['dirty'], isFalse);
    });

    test('does nothing without a uid', () async {
      final firestore = installFakeFirestore();

      await PeopleScoresService.requestInitialBuild('');

      final jobs =
          await firestore.collection(PeopleScoresService.collection).get();
      expect(jobs.docs, isEmpty);
    });

    test('does not throw when Firestore refuses the write', () async {
      // This runs while the home page is loading. A ranking that stays stale
      // is not a reason to fail a sign in.
      FirestoreCore.resetDb();

      await expectLater(
        PeopleScoresService.requestInitialBuild('user-1'),
        completes,
      );
    });
  });
}
