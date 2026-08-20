// Unit tests for the credit helpers in `lib/common/api/apiutils.dart`.
//
// These are pure functions over plain maps, so they need no Firebase or
// platform setup. They guard three bugs, all of which reached the screen as
// missing or broken credits: a job string rendered as a literal template
// placeholder, a lookup that threw on a typed list, and a show's cast arriving
// in a shape no screen could read.

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/apiutils.dart';

void main() {
  group('ApiUtils.normalizeCredits', () {
    // `/tv/{id}/aggregate_credits` is the only endpoint that returns a show's
    // full cast, but it reports a person once with a `roles` or `jobs` array
    // rather than the flat `character`/`job` every screen reads. These cover
    // the flattening, which is what keeps the rest of the app unaware that a
    // show and a film are fetched from differently shaped endpoints.

    test('returns empty lists for a payload with no credits', () {
      final result = ApiUtils.normalizeCredits({});
      expect(result['cast'], isEmpty);
      expect(result['crew'], isEmpty);
    });

    test('flattens a single role into a character', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'name': 'Alice',
            'roles': [
              {'credit_id': 'c1', 'character': 'Captain', 'episode_count': 5}
            ],
            'total_episode_count': 5,
          }
        ]
      });

      expect(result['cast'].single['character'], 'Captain');
      expect(result['cast'].single['credit_id'], 'c1');
      expect(result['cast'].single.containsKey('roles'), isFalse);
    });

    test('joins a renamed character with the biggest part first', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'name': 'Alice',
            'roles': [
              {'credit_id': 'c1', 'character': 'Cadet', 'episode_count': 2},
              {'credit_id': 'c2', 'character': 'Captain', 'episode_count': 9},
            ],
            'total_episode_count': 11,
          }
        ]
      });

      expect(result['cast'].single['character'], 'Captain / Cadet');
      expect(result['cast'].single['credit_id'], 'c2');
    });

    test('does not repeat a character credited twice', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'roles': [
              {'character': 'Captain', 'episode_count': 4},
              {'character': 'Captain', 'episode_count': 2},
            ],
          }
        ]
      });

      expect(result['cast'].single['character'], 'Captain');
    });

    test('leaves an unnamed role as an empty character, never "null"', () {
      // The screens interpolate this straight into "as {character}", so a
      // missing name has to read as nothing rather than as the word null.
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'roles': [
              {'character': null, 'episode_count': 3}
            ],
          }
        ]
      });

      expect(result['cast'].single['character'], '');
    });

    test('derives the episode total when tmdb omits it', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'roles': [
              {'character': 'Captain', 'episode_count': 4},
              {'character': 'Cadet', 'episode_count': 3},
            ],
          }
        ]
      });

      expect(result['cast'].single['total_episode_count'], 7);
    });

    test('prefers the total tmdb reports over the sum of the roles', () {
      // An episode where a person is credited in two roles counts once in
      // TMDB's total but twice in the sum, so the reported total wins.
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {
            'id': 1,
            'roles': [
              {'character': 'Captain', 'episode_count': 4},
              {'character': 'Cadet', 'episode_count': 3},
            ],
            'total_episode_count': 5,
          }
        ]
      });

      expect(result['cast'].single['total_episode_count'], 5);
    });

    test('ranks cast by episodes, then by billing within a tie', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {'id': 1, 'name': 'Guest', 'order': 0, 'total_episode_count': 1},
          {'id': 2, 'name': 'Second lead', 'order': 4,
              'total_episode_count': 40},
          {'id': 3, 'name': 'Lead', 'order': 2, 'total_episode_count': 40},
        ]
      });

      expect(result['cast'].map((person) => person['name']).toList(),
          ['Lead', 'Second lead', 'Guest']);
    });

    test('keeps equally ranked credits in the order tmdb sent them', () {
      // Dart's sort is not stable, and a cast reshuffling itself between
      // rebuilds would look like the list was loading wrong.
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {'id': 1, 'name': 'First'},
          {'id': 2, 'name': 'Second'},
          {'id': 3, 'name': 'Third'},
        ]
      });

      expect(result['cast'].map((person) => person['name']).toList(),
          ['First', 'Second', 'Third']);
    });

    test('sorts a credit with no billing order after one that has it', () {
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {'id': 1, 'name': 'Unbilled'},
          {'id': 2, 'name': 'Billed', 'order': 7},
        ]
      });

      expect(result['cast'].map((person) => person['name']).toList(),
          ['Billed', 'Unbilled']);
    });

    test('expands a crew member into one entry per job, as /credits does', () {
      // mergeCrewJobs already collapses a person's jobs, and reusing it is
      // what makes a person credited in two departments merge correctly.
      final result = ApiUtils.normalizeCredits({
        'crew': [
          {
            'id': 10,
            'name': 'Rae',
            'department': 'Directing',
            'jobs': [
              {'credit_id': 'j1', 'job': 'Co-Producer', 'episode_count': 2},
              {'credit_id': 'j2', 'job': 'Director', 'episode_count': 8},
            ],
            'total_episode_count': 10,
          }
        ]
      });

      expect(result['crew'], hasLength(2));
      expect(result['crew'].map((person) => person['job']).toList(),
          ['Director', 'Co-Producer']);
      expect(result['crew'][0]['credit_id'], 'j2');
      expect(result['crew'][0]['episode_count'], 8);
      expect(result['crew'][0]['department'], 'Directing');
      expect(result['crew'][0].containsKey('jobs'), isFalse);
    });

    test('merges into one crew entry once mergeCrewJobs has run', () {
      final normalized = ApiUtils.normalizeCredits({
        'crew': [
          {
            'id': 10,
            'name': 'Rae',
            'department': 'Directing',
            'jobs': [
              {'job': 'Director', 'episode_count': 8}
            ],
            'total_episode_count': 8,
          },
          {
            'id': 10,
            'name': 'Rae',
            'department': 'Production',
            'jobs': [
              {'job': 'Executive Producer', 'episode_count': 20}
            ],
            'total_episode_count': 20,
          },
        ]
      });
      final merged =
          ApiUtils.mergeCrewJobs(List<Map>.from(normalized['crew']));

      expect(merged, hasLength(1));
      expect(merged.single['job'], 'Executive Producer / Director');
    });

    test('passes a /credits payload through unchanged', () {
      // Films still use `/credits`, and the same normalising runs over both so
      // there is only one path to keep working.
      final result = ApiUtils.normalizeCredits({
        'cast': [
          {'id': 1, 'name': 'Cobb', 'character': 'Cobb', 'order': 0},
          {'id': 2, 'name': 'Arthur', 'character': 'Arthur', 'order': 1},
        ],
        'crew': [
          {'id': 10, 'name': 'Nolan', 'job': 'Director'},
          {'id': 11, 'name': 'Zimmer', 'job': 'Original Music Composer'},
        ],
      });

      expect(result['cast'], [
        {'id': 1, 'name': 'Cobb', 'character': 'Cobb', 'order': 0},
        {'id': 2, 'name': 'Arthur', 'character': 'Arthur', 'order': 1},
      ]);
      expect(result['crew'], [
        {'id': 10, 'name': 'Nolan', 'job': 'Director'},
        {'id': 11, 'name': 'Zimmer', 'job': 'Original Music Composer'},
      ]);
    });

    test('ignores entries that are not credits at all', () {
      final result = ApiUtils.normalizeCredits({
        'cast': 'not a list',
        'crew': [
          'nonsense',
          {
            'id': 10,
            'jobs': 'not a list',
          },
        ],
      });

      expect(result['cast'], isEmpty);
      expect(result['crew'], hasLength(1));
      expect(result['crew'].single['id'], 10);
    });
  });

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

  group('ApiUtils.findCrewMember', () {
    // mergeCrewJobs returns a typed List<Map>. Calling firstWhere on that with
    // `orElse: () => null` throws a TypeError on every lookup, which is what
    // previously replaced the whole Director/Writer block with an error box.
    test('finds a director on the typed list mergeCrewJobs returns', () {
      final crew = ApiUtils.mergeCrewJobs([
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
        {'id': 2, 'name': 'Bob', 'job': 'Screenplay'},
      ]);
      final director = ApiUtils.findCrewMember(
          crew, (job) => job.split('/').any((role) => role.trim() == 'Director'));
      expect(director, isNotNull);
      expect(director!['name'], 'Alice');
    });

    test('returns null instead of throwing when no crew member matches', () {
      final crew = ApiUtils.mergeCrewJobs([
        {'id': 1, 'name': 'Alice', 'job': 'Producer'},
      ]);
      expect(ApiUtils.findCrewMember(crew, (job) => job == 'Director'), isNull);
    });

    test('matches a role inside a merged multi-role job string', () {
      final crew = ApiUtils.mergeCrewJobs([
        {'id': 1, 'name': 'Alice', 'job': 'Screenplay'},
        {'id': 1, 'name': 'Alice', 'job': 'Director'},
      ]);
      final director = ApiUtils.findCrewMember(
          crew, (job) => job.split('/').any((role) => role.trim() == 'Director'));
      expect(director, isNotNull);
      expect(director!['name'], 'Alice');
    });

    test('skips crew members with a missing job', () {
      final crew = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob', 'job': 'Director'},
      ];
      final director =
          ApiUtils.findCrewMember(crew, (job) => job == 'Director');
      expect(director, isNotNull);
      expect(director!['name'], 'Bob');
    });

    test('returns null for a non-list input', () {
      expect(ApiUtils.findCrewMember(null, (job) => true), isNull);
    });
  });
}