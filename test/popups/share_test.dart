/// Tests for the share sheet.
///
/// Recommending a title used to be the one place in the app where a client
/// wrote into another person's Firestore document. It now goes through the
/// `recommendTitle` Cloud Function, so what is worth pinning here is what the
/// sheet asks the server for, that it asks for nothing about the sender, and
/// that a recommendation which does not arrive is no longer silent.
library;

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/callable_context.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/share.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late HttpStub http;
  late AppUser user;

  setUp(() {
    firestore = installFakeFirestore();
    http = installHttpStub();
    installFakeCallableContext();
    user = installTestUser();
    user.settings['username'] = 'Tester';
  });

  /// Registers [uid] as a friend with a display name and no avatar, so the
  /// row renders from the bundled placeholder rather than reaching out for a
  /// profile photo.
  Future<void> addFriend(String uid, String username) async {
    user.friends = [...user.friends, uid];
    await seedUserDoc(firestore, uid, 'Settings', {
      'username': username,
      'profile_photo': '',
    });
  }

  void stubRecommend({
    int delivered = 1,
    List<String> skipped = const [],
    int status = 200,
    String? errorStatus,
  }) {
    http.on(
      'recommendTitle',
      status: status,
      body: errorStatus == null
          ? jsonEncode({
              'result': {'delivered': delivered, 'skipped': skipped}
            })
          : jsonEncode({
              'error': {'status': errorStatus, 'message': 'ignored'}
            }),
    );
  }

  Future<void> openShare(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            // A dialogue is how the media page opens this. It used to be a
            // modal bottom sheet, which capped itself at 9/16 of the screen
            // and gave the friend list 233pt of the 500 it asked for.
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => Share(
                  item: Movie(
                    id: '27205',
                    title: 'Inception',
                    coverPhoto: '/cover.jpg',
                  ),
                  type: 'movie',
                ),
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

  Future<void> tick(WidgetTester tester, String username) async {
    await tester.tap(find.widgetWithText(CheckboxListTile, username));
    await tester.pumpAndSettle();
  }

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
  }

  /// The `data` object of the single call the sheet made.
  Map<String, dynamic> sentPayload() {
    final body = jsonDecode(http.requestBodies.single) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  testWidgets('lists every friend by name', (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');

    await openShare(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('a user with no friends gets no list at all', (tester) async {
    await openShare(tester);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('asks the server for the friends that were ticked, once',
      (tester) async {
    // One call carrying both uids rather than one call each: the server does
    // the fan-out, and the friendship check costs a read per recipient.
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');
    stubRecommend(delivered: 2);

    await openShare(tester);
    await tick(tester, 'Ana');
    await tick(tester, 'Bruno');
    await accept(tester);

    expect(http.countFor('recommendTitle'), 1);
    expect(sentPayload()['friends'], ['friend-a', 'friend-b']);
  });

  testWidgets('sends what the recipient needs to render the notification',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    stubRecommend();

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    final payload = sentPayload();
    expect(payload['id'], '27205');
    expect(payload['type'], 'movie');
    expect(payload['title'], 'Inception');
    expect(payload['coverPhoto'], '/cover.jpg');
  });

  testWidgets('says nothing about who is recommending', (tester) async {
    // The defect this whole path exists to fix: `sender` was built here and
    // believed by everyone downstream, so a friend could file a
    // recommendation in someone's inbox under a third party's name. The
    // server derives it from the caller's token now.
    await addFriend('friend-a', 'Ana');
    stubRecommend();

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(sentPayload().containsKey('sender'), isFalse);
    expect(http.requestBodies.single, isNot(contains('test-uid')));
  });

  testWidgets('a friend ticked and then unticked is not sent anything',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');
    stubRecommend();

    await openShare(tester);
    await tick(tester, 'Ana');
    await tick(tester, 'Ana');
    await tick(tester, 'Bruno');
    await accept(tester);

    expect(sentPayload()['friends'], ['friend-b']);
  });

  testWidgets('accepting with nobody ticked calls nothing at all',
      (tester) async {
    await addFriend('friend-a', 'Ana');

    await openShare(tester);
    await accept(tester);

    expect(http.requests, isEmpty);
    expect(find.byType(Share), findsNothing);
  });

  testWidgets('cancel sends nothing even after ticking someone',
      (tester) async {
    await addFriend('friend-a', 'Ana');

    await openShare(tester);
    await tick(tester, 'Ana');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(http.requests, isEmpty);
    expect(find.byType(Share), findsNothing);
  });

  testWidgets('a delivery to everyone closes the sheet and says nothing',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    stubRecommend(delivered: 1);

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(find.byType(Share), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a recommendation that reaches nobody is no longer silent',
      (tester) async {
    // The old code swallowed every failure into a debugPrint, so a
    // recommendation that never arrived looked exactly like one that did.
    await addFriend('friend-a', 'Ana');
    stubRecommend(delivered: 0, skipped: ['friend-a']);

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(
      find.text('Could not send your recommendation. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a partial delivery says so rather than claiming success',
      (tester) async {
    // A friend who has since removed you is dropped by the server without
    // failing the call for the others.
    await addFriend('friend-a', 'Ana');
    await addFriend('friend-b', 'Bruno');
    stubRecommend(delivered: 1, skipped: ['friend-b']);

    await openShare(tester);
    await tick(tester, 'Ana');
    await tick(tester, 'Bruno');
    await accept(tester);

    expect(
      find.text('Some of your friends could not be sent this.'),
      findsOneWidget,
    );
  });

  testWidgets('a refusal from the server is reported too', (tester) async {
    await addFriend('friend-a', 'Ana');
    stubRecommend(status: 400, errorStatus: 'INVALID_ARGUMENT');

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(
      find.text('Could not send your recommendation. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a signed-out user is told, not left guessing', (tester) async {
    installFakeCallableContext(idToken: null);
    await addFriend('friend-a', 'Ana');

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(http.requests, isEmpty);
    expect(
      find.text('Could not send your recommendation. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a thrown token lookup is reported, not left unhandled',
      (tester) async {
    // Fetching the ID token reaches into Firebase and can throw. Letting that
    // escape would close the sheet with nothing said and no idea whether
    // anything was sent.
    installFakeCallableContext();
    CallableContext.idToken = () async => throw StateError('no token');
    addTearDown(CallableContext.reset);
    await addFriend('friend-a', 'Ana');

    await openShare(tester);
    await tick(tester, 'Ana');
    await accept(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('Could not send your recommendation. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('backing out mid-send does not pop the page underneath',
      (tester) async {
    // Cancel is disabled while a call is in flight, but the system back
    // gesture and a barrier tap are not. Popping again when the answer arrives
    // would take the page below with it.
    await addFriend('friend-a', 'Ana');
    stubRecommend(delivered: 1);
    http.on('recommendTitle',
        body: jsonEncode({
          'result': {'delivered': 1, 'skipped': <String>[]}
        }),
        delay: const Duration(seconds: 1));

    await openShare(tester);
    await tick(tester, 'Ana');
    await tester.tap(find.text('Accept'));
    await tester.pump();

    // Dismiss the dialogue while the call is still in flight.
    Navigator.of(tester.element(find.byType(Share))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(Share), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // The button that opened the sheet is still there, which it would not be
    // if the second pop had gone through.
    expect(tester.takeException(), isNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('cancel is disabled while a recommendation is in flight',
      (tester) async {
    await addFriend('friend-a', 'Ana');
    http.on('recommendTitle',
        body: jsonEncode({
          'result': {'delivered': 1, 'skipped': <String>[]}
        }),
        delay: const Duration(seconds: 1));

    await openShare(tester);
    await tick(tester, 'Ana');
    await tester.tap(find.text('Accept'));
    await tester.pump();

    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('both buttons are localized', (tester) async {
    // They were hardcoded English, which the Spanish build showed as-is.
    await openShare(tester);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });
}
