// Unit tests for the crew-credit helpers in `lib/common/api/apiutils.dart`.
//
// These are pure functions over plain maps, so they need no Firebase or
// platform setup. They guard two bugs that both surfaced as a broken
// Director/Writer block on the movie screen: a job string rendered as a
// literal template placeholder, and a lookup that threw on a typed list.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/apiutils.dart';

void main() {
  group('ApiUtils.mergeCrewJobs', () {
    test('returns an empty list for an empty crew list', () {
      expect(ApiUtils.mergeCrewJobs([]), isEmpty);
    });

    test('leaves a person appearing once unchanged', () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      expect(result.length, 1);
      expect(result[0]['job'], 'Director');
    });

    test('joins distinct jobs for a person appearing twice', () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
        {'id': 2, 'name': 'Bob', 'job': 'Actor'},
        {'id': 1, 'name': 'Alice', 'job': 'Writer'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      expect(result.length, 2);
      expect(result[0]['job'], 'Director / Writer');
      expect(result[1]['job'], 'Actor');
    });

    test('does not duplicate the same job appearing twice for one person',
        () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      expect(result.length, 1);
      expect(result[0]['job'], 'Director');
    });

    test('handles a null/missing job without producing "null"', () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': null},
        {'id': 1, 'name': 'Alice', 'job': 'Writer'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      expect(result.length, 1);
      expect(result[0]['job'], 'Writer');
      expect(result[0]['job'], isNot(contains('null')));
    });

    test('handles a duplicate entry whose job is entirely missing', () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
        {'id': 1, 'name': 'Alice'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      expect(result.length, 1);
      expect(result[0]['job'], 'Director');
    });

    test('output never contains literal template placeholder characters',
        () {
      final crew = [
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
        {'id': 2, 'name': 'Bob', 'job': null},
        {'id': 1, 'name': 'Alice', 'job': 'Writer'},
        {'id': 2, 'name': 'Bob', 'job': 'Producer'},
      ];
      final result = ApiUtils.mergeCrewJobs(crew);
      for (final credit in result) {
        final job = credit['job'] as String? ?? '';
        expect(job, isNot(contains(r'$')));
        expect(job, isNot(contains('{')));
        expect(job, isNot(contains('}')));
      }
    });
  });
}