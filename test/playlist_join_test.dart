import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/playlist_join.dart';

String _errorBody(String status) => jsonEncode({
      'error': {'status': status, 'message': 'ignored'}
    });

void main() {
  group('PlaylistJoiner.endpoint', () {
    test('points at the callable for the configured region', () {
      const joiner = PlaylistJoiner();
      expect(
        joiner.endpoint('actordb-cf981').toString(),
        'https://us-central1-actordb-cf981.cloudfunctions.net/joinPlaylist',
      );
    });

    test('honours a non-default region', () {
      const joiner = PlaylistJoiner(region: 'europe-west1');
      expect(
        joiner.endpoint('proj').toString(),
        'https://europe-west1-proj.cloudfunctions.net/joinPlaylist',
      );
    });
  });

  group('PlaylistJoiner.interpretResponse', () {
    test('reports a successful join and returns the playlist id', () {
      final body = jsonEncode({
        'result': {'id': 'abc123', 'alreadyMember': false}
      });
      final result = PlaylistJoiner.interpretResponse(200, body);

      expect(result.outcome, JoinPlaylistOutcome.joined);
      expect(result.playlistId, 'abc123');
      expect(result.isSuccess, isTrue);
    });

    test('treats an existing membership as success, not an error', () {
      // Joining a list you are already in should open it, not show a failure.
      final body = jsonEncode({
        'result': {'id': 'abc123', 'alreadyMember': true}
      });
      final result = PlaylistJoiner.interpretResponse(200, body);

      expect(result.outcome, JoinPlaylistOutcome.alreadyMember);
      expect(result.isSuccess, isTrue);
    });

    test('maps each error status to its own outcome', () {
      expect(
        PlaylistJoiner.interpretResponse(404, _errorBody('NOT_FOUND')).outcome,
        JoinPlaylistOutcome.notFound,
      );
      expect(
        PlaylistJoiner.interpretResponse(429, _errorBody('RESOURCE_EXHAUSTED'))
            .outcome,
        JoinPlaylistOutcome.tooManyAttempts,
      );
      expect(
        PlaylistJoiner.interpretResponse(400, _errorBody('INVALID_ARGUMENT'))
            .outcome,
        JoinPlaylistOutcome.invalidInput,
      );
      expect(
        PlaylistJoiner.interpretResponse(401, _errorBody('UNAUTHENTICATED'))
            .outcome,
        JoinPlaylistOutcome.notSignedIn,
      );
    });

    test('falls back to a generic failure for an unknown status', () {
      final result =
          PlaylistJoiner.interpretResponse(500, _errorBody('INTERNAL'));
      expect(result.outcome, JoinPlaylistOutcome.failed);
      expect(result.isSuccess, isFalse);
    });

    test('does not throw on a body that is not JSON', () {
      // A proxy or captive portal can return HTML with any status code.
      final result =
          PlaylistJoiner.interpretResponse(502, '<html>Bad Gateway</html>');
      expect(result.outcome, JoinPlaylistOutcome.failed);
    });

    test('does not throw on JSON that is not an object', () {
      expect(PlaylistJoiner.interpretResponse(200, '[]').outcome,
          JoinPlaylistOutcome.failed);
      expect(PlaylistJoiner.interpretResponse(200, '"text"').outcome,
          JoinPlaylistOutcome.failed);
    });

    test('rejects a 200 whose result is missing or malformed', () {
      expect(PlaylistJoiner.interpretResponse(200, '{}').outcome,
          JoinPlaylistOutcome.failed);
      expect(
        PlaylistJoiner.interpretResponse(200, jsonEncode({'result': 'yes'}))
            .outcome,
        JoinPlaylistOutcome.failed,
      );
    });

    test('accepts a success that omits the id', () {
      final body = jsonEncode({
        'result': {'alreadyMember': false}
      });
      final result = PlaylistJoiner.interpretResponse(200, body);

      expect(result.outcome, JoinPlaylistOutcome.joined);
      expect(result.playlistId, isNull);
    });

    test('treats an error payload without a status as a generic failure', () {
      expect(
        PlaylistJoiner.interpretResponse(500, jsonEncode({'error': {}})).outcome,
        JoinPlaylistOutcome.failed,
      );
      expect(
        PlaylistJoiner.interpretResponse(500, jsonEncode({'error': 'boom'}))
            .outcome,
        JoinPlaylistOutcome.failed,
      );
    });
  });
}
