import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/omdb_lookup.dart';

String _errorBody(String status) => jsonEncode({
  'error': {'status': status, 'message': 'ignored'},
});

void main() {
  group('OmdbLookup.endpoint', () {
    test('points at the callable for the configured region', () {
      const lookup = OmdbLookup();
      expect(
        lookup.endpoint('actordb-cf981').toString(),
        'https://us-central1-actordb-cf981.cloudfunctions.net/omdbLookup',
      );
    });

    test('honours a non-default region', () {
      const lookup = OmdbLookup(region: 'europe-west1');
      expect(
        lookup.endpoint('proj').toString(),
        'https://europe-west1-proj.cloudfunctions.net/omdbLookup',
      );
    });
  });

  group('OmdbLookup.interpretResponse', () {
    test('returns trimmed data from a successful lookup', () {
      final body = jsonEncode({
        'result': {'Response': 'True', 'imdbRating': '8.8', 'Year': '2010'},
      });
      final result = OmdbLookup.interpretResponse(200, body);

      expect(result.outcome, OmdbLookupOutcome.found);
      expect(result.isSuccess, isTrue);
      expect(result.data['imdbRating'], '8.8');
      expect(result.data['Year'], '2010');
    });

    test('maps callable errors to outcomes', () {
      expect(
        OmdbLookup.interpretResponse(404, _errorBody('NOT_FOUND')).outcome,
        OmdbLookupOutcome.notFound,
      );
      expect(
        OmdbLookup.interpretResponse(
          400,
          _errorBody('INVALID_ARGUMENT'),
        ).outcome,
        OmdbLookupOutcome.invalidInput,
      );
      expect(
        OmdbLookup.interpretResponse(
          401,
          _errorBody('UNAUTHENTICATED'),
        ).outcome,
        OmdbLookupOutcome.notSignedIn,
      );
      expect(
        OmdbLookup.interpretResponse(503, _errorBody('UNAVAILABLE')).outcome,
        OmdbLookupOutcome.unavailable,
      );
    });

    test('treats a false OMDB result as not found', () {
      final body = jsonEncode({
        'result': {'Response': 'False'},
      });

      expect(
        OmdbLookup.interpretResponse(200, body).outcome,
        OmdbLookupOutcome.notFound,
      );
    });

    test('falls back for malformed callable bodies', () {
      expect(
        OmdbLookup.interpretResponse(200, '{}').outcome,
        OmdbLookupOutcome.failed,
      );
      expect(
        OmdbLookup.interpretResponse(200, '[]').outcome,
        OmdbLookupOutcome.failed,
      );
      expect(
        OmdbLookup.interpretResponse(502, '<html>bad</html>').outcome,
        OmdbLookupOutcome.failed,
      );
      expect(
        OmdbLookup.interpretResponse(500, jsonEncode({'error': {}})).outcome,
        OmdbLookupOutcome.failed,
      );
    });
  });
}
