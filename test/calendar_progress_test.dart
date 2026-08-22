/// Tests for what a calendar entry means for watch progress.
///
/// The calendar and the progress model used to contradict each other: logging
/// a day marked a title seen, and anything in a Seen list reads as finished,
/// so "I finished episode 3 today" claimed the whole show was done. These pin
/// the rule that replaced that, and — just as importantly — pin the entries
/// that must keep behaving exactly as they always have.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/calendar_episode.dart';
import 'package:uractor/common/calendar_progress.dart';

void main() {
  group('a film', () {
    test('marks itself and its friends seen', () {
      final intent = CalendarProgress.intentFor(
        type: calendarMovieType,
        alreadyFinished: false,
      );

      expect(intent.action, CalendarProgressAction.markSeen);
      expect(intent.marksSelfSeen, isTrue);
      expect(intent.marksFriendsSeen, isTrue);
    });

    test('ignores an episode it should never have carried', () {
      final intent = CalendarProgress.intentFor(
        type: calendarMovieType,
        episode: const CalendarEpisode(season: 2, episode: 5),
        alreadyFinished: false,
      );

      expect(intent.action, CalendarProgressAction.markSeen);
      expect(intent.marksFriendsSeen, isTrue);
    });

    test('is still marked seen once finished, as it always was', () {
      final intent = CalendarProgress.intentFor(
        type: calendarMovieType,
        alreadyFinished: true,
      );

      expect(intent.action, CalendarProgressAction.markSeen);
    });
  });

  group('a show entry that records no part', () {
    test('behaves exactly as it did before episodes were recordable', () {
      final intent = CalendarProgress.intentFor(
        type: 'series',
        alreadyFinished: false,
      );

      expect(intent.action, CalendarProgressAction.markSeen);
      expect(intent.marksSelfSeen, isTrue);
      expect(intent.marksFriendsSeen, isTrue);
      expect(intent.season, isNull);
    });

    test('is read as a film when it predates the type field', () {
      // An entry written before shows were loggable has no type at all, and
      // CalendarEpisode reads those as films. This has to agree.
      final intent = CalendarProgress.intentFor(
        type: calendarMovieType,
        alreadyFinished: false,
      );

      expect(intent.marksSelfSeen, isTrue);
    });
  });

  group('a show entry naming an episode', () {
    test('puts the show in progress rather than marking it seen', () {
      final intent = CalendarProgress.intentFor(
        type: 'series',
        episode: const CalendarEpisode(season: 2, episode: 5),
        alreadyFinished: false,
      );

      expect(intent.action, CalendarProgressAction.markWatchedThrough);
      expect(intent.marksSelfSeen, isFalse);
      expect(intent.season, 2);
      expect(intent.episode, 5);
    });

    test('does not claim a tagged friend finished the show', () {
      final intent = CalendarProgress.intentFor(
        type: 'series',
        episode: const CalendarEpisode(season: 1, episode: 1),
        alreadyFinished: false,
      );

      expect(intent.marksFriendsSeen, isFalse);
    });

    test('ticks the episodes but leaves a finished show finished', () {
      // The dialogue promises everything before the episode is marked as
      // watched, and the season guide draws only what is ticked, so skipping
      // this left the promise visibly false for every show the user had ever
      // logged without naming a part.
      final intent = CalendarProgress.intentFor(
        type: 'series',
        episode: const CalendarEpisode(season: 2, episode: 5),
        alreadyFinished: true,
      );

      expect(intent.action, CalendarProgressAction.markWatchedThrough);
      expect(intent.keepsFinished, isTrue);
      expect(intent.season, 2);
      expect(intent.episode, 5);
      expect(intent.marksSelfSeen, isFalse);
      expect(intent.marksFriendsSeen, isFalse);
    });

    test('does not claim to keep an unfinished show finished', () {
      final intent = CalendarProgress.intentFor(
        type: 'series',
        episode: const CalendarEpisode(season: 2, episode: 5),
        alreadyFinished: false,
      );

      expect(intent.keepsFinished, isFalse);
    });
  });

  group('a show entry naming only a season', () {
    test('is watched through that season, with no episode named', () {
      final intent = CalendarProgress.intentFor(
        type: 'series',
        episode: const CalendarEpisode(season: 3),
        alreadyFinished: false,
      );

      expect(intent.action, CalendarProgressAction.markWatchedThrough);
      expect(intent.season, 3);
      expect(intent.episode, isNull);
      expect(intent.marksFriendsSeen, isFalse);
    });
  });

  test('intents compare by value, so a test can assert on the whole thing', () {
    const one = CalendarProgressIntent(
      action: CalendarProgressAction.markWatchedThrough,
      marksFriendsSeen: false,
      season: 2,
      episode: 5,
    );
    const same = CalendarProgressIntent(
      action: CalendarProgressAction.markWatchedThrough,
      marksFriendsSeen: false,
      season: 2,
      episode: 5,
    );
    const other = CalendarProgressIntent(
      action: CalendarProgressAction.markSeen,
      marksFriendsSeen: true,
    );
    const kept = CalendarProgressIntent(
      action: CalendarProgressAction.markWatchedThrough,
      marksFriendsSeen: false,
      keepsFinished: true,
      season: 2,
      episode: 5,
    );

    expect(one, same);
    expect(one.hashCode, same.hashCode);
    expect(one, isNot(other));
    expect(one, isNot(kept),
        reason: 'whether the title stays finished is part of the decision');
    expect(one.toString(), contains('season: 2'));
  });
}
