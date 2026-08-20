/// Tests for the rating dialogue.
///
/// Submitting a rating has to leave three things agreeing with each other:
/// the stored review, the in-memory map the reviews screen renders, and the
/// flat list behind the profile. They are rebuilt separately, so they can
/// drift, and a review that saves but does not appear looks like data loss.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/rating_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser();
    app.reviewId = '27205';
    app.reviewType = 'Movies';
    app.reviewInfo = {};
    myController.text = '';
  });

  tearDown(() {
    app.reviewId = '';
    app.reviewType = '';
    app.reviewInfo = {};
    app.reviewed = false;
    myController.text = '';
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const RatingDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// How many of the ten stars are lit, which is the only visible record of
  /// the score before it is submitted.
  int litStars(WidgetTester tester) {
    return tester
        .widgetList<Icon>(find.byIcon(Icons.star_rate_outlined))
        .where((icon) => icon.color == Colors.yellow[600])
        .length;
  }

  Future<List> storedReviews() async {
    final doc = await firestore.collection('test-uid').doc('Reviews').get();
    return (doc.data()?['Movies'] as List?) ?? [];
  }

  testWidgets('offers a score out of ten, none of it chosen yet',
      (tester) async {
    await openDialog(tester);

    expect(find.byIcon(Icons.star_rate_outlined), findsNWidgets(10));
    expect(litStars(tester), 0);
  });

  testWidgets('tapping a star lights it and everything before it',
      (tester) async {
    await openDialog(tester);

    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(6));
    await tester.pumpAndSettle();

    expect(litStars(tester), 7);
  });

  testWidgets('picking a lower star puts the score down again',
      (tester) async {
    await openDialog(tester);

    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(8));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(2));
    await tester.pumpAndSettle();

    expect(litStars(tester), 3);
  });

  testWidgets('submitting stores the opinion and the score against the title',
      (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Dreams within dreams');
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await storedReviews(), [
      {
        '27205': {'Opinion': 'Dreams within dreams', 'Rating': '5'}
      }
    ]);
  });

  testWidgets('the review is readable without reloading the account',
      (tester) async {
    // The reviews screen renders from these two, not from Firestore, so a
    // submit that only writes leaves the user staring at an unchanged screen.
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Solid');
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(user.reviews, {
      '27205': {'Opinion': 'Solid', 'Rating': '4'}
    });
    expect(user.allReviews, [
      [
        'Movies',
        '27205',
        {'Opinion': 'Solid', 'Rating': '4'}
      ]
    ]);
  });

  testWidgets('a review with no text still saves the score', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(9));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await storedReviews(), [
      {
        '27205': {'Opinion': '', 'Rating': '10'}
      }
    ]);
  });

  testWidgets('the dialogue closes once the review is saved', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingDialog), findsNothing);
  });

  testWidgets('not now closes without writing anything', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Never mind');
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingDialog), findsNothing);
    expect(await storedReviews(), isEmpty);
  });

  testWidgets('reopening an existing review shows what was written before',
      (tester) async {
    app.reviewInfo = {'Opinion': 'Dreams within dreams', 'Rating': '5'};

    await openDialog(tester);

    expect(find.text('Dreams within dreams'), findsOneWidget);
    expect(litStars(tester), 5);
  });

  testWidgets('editing a review replaces it rather than adding a second one',
      (tester) async {
    // Reviews are stored as a list, so an edit that only appends leaves the
    // title with two reviews and the screen showing the stale one.
    app.reviewInfo = {'Opinion': 'First thoughts', 'Rating': '5'};
    await seedUserDoc(firestore, 'test-uid', 'Reviews', {
      'Movies': [
        {
          '27205': {'Opinion': 'First thoughts', 'Rating': '5'}
        }
      ],
      'TVShows': [],
    });

    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Second thoughts');
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(await storedReviews(), [
      {
        '27205': {'Opinion': 'Second thoughts', 'Rating': '3'}
      }
    ]);
  });

  testWidgets('a review of a show is filed under shows, not films',
      (tester) async {
    app.reviewId = '1396';
    app.reviewType = 'TVShows';

    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'All hail the king');
    await tester.tap(find.byIcon(Icons.star_rate_outlined).at(9));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('test-uid').doc('Reviews').get();
    expect(doc.data()!['TVShows'], [
      {
        '1396': {'Opinion': 'All hail the king', 'Rating': '10'}
      }
    ]);
    expect(doc.data()!.containsKey('Movies'), isFalse);
    expect(user.tvShowReviews, {
      '1396': {'Opinion': 'All hail the king', 'Rating': '10'}
    });
    expect(user.reviews, isEmpty);
  });
}
