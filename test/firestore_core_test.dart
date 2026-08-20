import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/firestore_core.dart';

void main() {
  group('FirestoreCore.updateDocument', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirestoreCore.db = fakeFirestore;
      addTearDown(FirestoreCore.resetDb);
    });

    test('creates the document when it does not exist', () async {
      final doc = fakeFirestore.collection('some-uid').doc('Calendar');
      expect((await doc.get()).exists, isFalse);

      await FirestoreCore.updateDocument(
          'some-uid', 'Calendar', {'2025-06-14': 'movie night'});

      final snapshot = await doc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), equals({'2025-06-14': 'movie night'}));
    });

    test('merges into an existing document, leaving other fields untouched',
        () async {
      final doc = fakeFirestore.collection('some-uid').doc('Settings');
      await doc.set({'username': 'existing', 'profile_photo': 'old.png'});

      await FirestoreCore.updateDocument(
          'some-uid', 'Settings', {'profile_photo': 'new.png'});

      final snapshot = await doc.get();
      final data = snapshot.data() as Map<String, dynamic>;
      // The regression this guards against: someone "simplifying"
      // updateDocument back to a plain (non-merging) set would wipe
      // 'username' out here instead of leaving it alone.
      expect(data['username'], equals('existing'));
      expect(data['profile_photo'], equals('new.png'));
    });

    test('FieldValue.arrayUnion against a missing document creates a '
        'single-element array', () async {
      final doc = fakeFirestore.collection('some-uid').doc('Favorites');
      expect((await doc.get()).exists, isFalse);

      await FirestoreCore.updateDocument('some-uid', 'Favorites', {
        'Movies': FieldValue.arrayUnion(['12345'])
      });

      final snapshot = await doc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), equals({
        'Movies': ['12345']
      }));
    });
  });

  group('FirestoreCore.mergeInto', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirestoreCore.db = fakeFirestore;
      addTearDown(FirestoreCore.resetDb);
    });

    test('creates the document when given a raw DocumentReference', () async {
      final doc = fakeFirestore.collection('Watchlists').doc('12345');
      expect((await doc.get()).exists, isFalse);

      await FirestoreCore.mergeInto(doc, {'Name': 'My List'});

      final snapshot = await doc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), equals({'Name': 'My List'}));
    });
  });
}
