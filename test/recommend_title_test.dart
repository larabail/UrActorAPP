/// Tests for the client half of `recommendTitle`.
///
/// The call itself needs a Firebase ID token, so what is testable here is the
/// wire format it sends and how it reads what comes back. Both matter: the
/// payload is what the server refuses to trust, and the response is the only
/// thing that decides whether the user is told anything.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/http_client.dart';
import 'package:uractor/common/firebase/recommend_title.dart';

import 'support/harness.dart';

String _errorBody(String status) => jsonEncode({
      'error': {'status': status, 'message': 'ignored'}
    });

String _resultBody({required int delivered, List<String> skipped = const []}) =>
    jsonEncode({
      'result': {'delivered': delivered, 'skipped': skipped}
    });

void main() {
  group('TitleRecommender.endpoint', () {
    test('points at the callable for the configured region', () {
      expect(
        const TitleRecommender().endpoint('actordb-cf981').toString(),
        'https://us-central1-actordb-cf981.cloudfunctions.net/recommendTitle',
      );
    });

    test('honours a non-default region', () {
      expect(
        const TitleRecommender(region: 'europe-west1').endpoint('p').toString(),
        'https://europe-west1-p.cloudfunctions.net/recommendTitle',
      );
    });
  });

  group('TitleRecommender.recommend', () {
    late HttpStub http;

    setUp(() {
      http = installHttpStub();
    });

    Future<RecommendTitleResult> send({List<String> friends = const ['a']}) {
      return const TitleRecommender().recommend(
        client: AppHttp.client,
        projectId: 'actordb-cf981',
        idToken: 'token',
        id: '27205',
        type: 'movie',
        title: 'Inception',
        coverPhoto: '/cover.jpg',
        friends: friends,
      );
    }

    test('sends what the title needs and nothing about the sender', () async {
      // A `sender` in the payload is ignored by the function, but sending one
      // would tell the next reader of this file that it is believed.
      http.on('recommendTitle', body: _resultBody(delivered: 1));

      await send(friends: const ['friend-a', 'friend-b']);

      final sent = jsonDecode(http.requestBodies.single) as Map<String, dynamic>;
      expect(sent['data'], {
        'id': '27205',
        'type': 'movie',
        'title': 'Inception',
        'coverPhoto': '/cover.jpg',
        'friends': ['friend-a', 'friend-b'],
      });
      expect((sent['data'] as Map).containsKey('sender'), isFalse);
    });

    test('reports a network failure rather than throwing', () async {
      // MockClient throws for an unstubbed URL, which stands in for the DNS,
      // TLS and offline failures a phone actually hits.
      final result = await send();

      expect(result.outcome, RecommendTitleOutcome.failed);
    });
  });

  group('TitleRecommender.interpretResponse', () {
    test('counts a delivery to everyone as a plain success', () {
      final result =
          TitleRecommender.interpretResponse(200, _resultBody(delivered: 2));

      expect(result.outcome, RecommendTitleOutcome.sent);
      expect(result.delivered, 2);
      expect(result.skipped, isEmpty);
      expect(result.isSuccess, isTrue);
    });

    test('separates a partial delivery from a complete one', () {
      // The server drops a target who has not listed the caller as a friend
      // rather than failing the call, so this is the case where some friends
      // got it and the user still needs telling.
      final result = TitleRecommender.interpretResponse(
        200,
        _resultBody(delivered: 1, skipped: ['friend-b']),
      );

      expect(result.outcome, RecommendTitleOutcome.partiallySent);
      expect(result.delivered, 1);
      expect(result.skipped, ['friend-b']);
      expect(result.isSuccess, isFalse,
          reason: 'a partial send is still worth a message');
    });

    test('treats reaching nobody as a failure, not a success', () {
      final result = TitleRecommender.interpretResponse(
        200,
        _resultBody(delivered: 0, skipped: ['friend-a']),
      );

      expect(result.outcome, RecommendTitleOutcome.noneSent);
      expect(result.isSuccess, isFalse);
    });

    test('maps each error status to its own outcome', () {
      expect(
        TitleRecommender.interpretResponse(400, _errorBody('INVALID_ARGUMENT'))
            .outcome,
        RecommendTitleOutcome.invalidInput,
      );
      expect(
        TitleRecommender.interpretResponse(401, _errorBody('UNAUTHENTICATED'))
            .outcome,
        RecommendTitleOutcome.notSignedIn,
      );
      expect(
        TitleRecommender.interpretResponse(500, _errorBody('INTERNAL')).outcome,
        RecommendTitleOutcome.failed,
      );
    });

    test('does not throw on a body that is not JSON', () {
      // A proxy or captive portal can return HTML with any status code.
      expect(
        TitleRecommender.interpretResponse(502, '<html>Bad Gateway</html>')
            .outcome,
        RecommendTitleOutcome.failed,
      );
    });

    test('does not throw on JSON that is not an object', () {
      expect(TitleRecommender.interpretResponse(200, '[]').outcome,
          RecommendTitleOutcome.failed);
      expect(TitleRecommender.interpretResponse(200, '"text"').outcome,
          RecommendTitleOutcome.failed);
    });

    test('rejects a 200 that does not say how many were delivered', () {
      expect(TitleRecommender.interpretResponse(200, '{}').outcome,
          RecommendTitleOutcome.failed);
      expect(
        TitleRecommender.interpretResponse(200, jsonEncode({'result': 'yes'}))
            .outcome,
        RecommendTitleOutcome.failed,
      );
      expect(
        TitleRecommender.interpretResponse(
                200, jsonEncode({'result': <String, dynamic>{}}))
            .outcome,
        RecommendTitleOutcome.failed,
      );
      expect(
        TitleRecommender.interpretResponse(
                200, jsonEncode({'result': {'delivered': '1'}}))
            .outcome,
        RecommendTitleOutcome.failed,
      );
    });

    test('accepts a success that omits or mistypes the skipped list', () {
      final missing = TitleRecommender.interpretResponse(
        200,
        jsonEncode({'result': {'delivered': 1}}),
      );
      expect(missing.outcome, RecommendTitleOutcome.sent);
      expect(missing.skipped, isEmpty);

      final wrongType = TitleRecommender.interpretResponse(
        200,
        jsonEncode({'result': {'delivered': 1, 'skipped': 'friend-a'}}),
      );
      expect(wrongType.outcome, RecommendTitleOutcome.sent);
      expect(wrongType.skipped, isEmpty);
    });

    test('keeps only the uids out of a mixed skipped list', () {
      final result = TitleRecommender.interpretResponse(
        200,
        jsonEncode({
          'result': {
            'delivered': 1,
            'skipped': ['friend-a', 7, null]
          }
        }),
      );

      expect(result.skipped, ['friend-a']);
      expect(result.outcome, RecommendTitleOutcome.partiallySent);
    });

    test('treats an error payload without a status as a generic failure', () {
      expect(
        TitleRecommender.interpretResponse(500, jsonEncode({'error': {}}))
            .outcome,
        RecommendTitleOutcome.failed,
      );
      expect(
        TitleRecommender.interpretResponse(500, jsonEncode({'error': 'boom'}))
            .outcome,
        RecommendTitleOutcome.failed,
      );
    });
  });
}
