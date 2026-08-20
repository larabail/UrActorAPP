/// What recording a day on the calendar means for watch progress.
///
/// The calendar and the progress model were built separately and used to
/// contradict each other: an entry marked a title seen, and `ProgressService`
/// reads anything in a Seen list as finished, so logging "I finished episode 3
/// today" claimed you had finished the whole show. This decides what an entry
/// should actually do instead.
///
/// Kept free of Firestore and Flutter so the rule can be tested without a
/// network call or a pumped frame; `ProgressService` carries the decision out.
library;

import 'calendar_episode.dart';

/// What a calendar entry does to the logging user's own tracking.
enum CalendarProgressAction {
  /// Mark the title seen, which the progress model reads as finished. This is
  /// what every entry did before episodes were recordable, and what an entry
  /// that records no season still does.
  markSeen,

  /// Tick every episode through the one named, leaving the show in progress
  /// unless that completes it.
  markWatchedThrough,

  /// Leave tracking exactly as it is and only log the day.
  none,
}

/// The decision for one calendar entry.
class CalendarProgressIntent {
  const CalendarProgressIntent({
    required this.action,
    required this.marksFriendsSeen,
    this.season,
    this.episode,
  });

  final CalendarProgressAction action;

  /// Whether the friends tagged on this entry should have the title added to
  /// their own Seen lists.
  ///
  /// Separate from [action] because it answers a different question. The
  /// logging user's state depends on what they had already recorded; a
  /// friend's cannot, because `firestore.rules` lets a client write its own
  /// `Progress` document and nobody else's. So the only honest signal to send
  /// a friend is the entry itself: one that names a part of a show is not a
  /// claim that either of you finished it.
  final bool marksFriendsSeen;

  /// The season to tick through, set only for [CalendarProgressAction.markWatchedThrough].
  final int? season;

  /// The episode to tick through, or null when the entry named a whole season.
  final int? episode;

  bool get marksSelfSeen => action == CalendarProgressAction.markSeen;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarProgressIntent &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          marksFriendsSeen == other.marksFriendsSeen &&
          season == other.season &&
          episode == other.episode;

  @override
  int get hashCode => Object.hash(action, marksFriendsSeen, season, episode);

  @override
  String toString() =>
      'CalendarProgressIntent($action, season: $season, episode: $episode, '
      'marksFriendsSeen: $marksFriendsSeen)';
}

class CalendarProgress {
  /// What logging [episode] of a [type] title on a day should do.
  ///
  /// [type] is the value the entry stores, so `movie` for a film and anything
  /// else for a show — entries written before the field existed are read as
  /// films everywhere else in the app and are read that way here too.
  ///
  /// [alreadyFinished] is whether the logging user has the title recorded as
  /// finished. A finished title stays finished: the app already has an
  /// explicit way to say you are watching something again, and deriving that
  /// from a log entry would quietly pull a title out of the Seen list the user
  /// curates and that drives their badges and counts. Logging what you watched
  /// is not a state change.
  static CalendarProgressIntent intentFor({
    required String type,
    CalendarEpisode? episode,
    required bool alreadyFinished,
  }) {
    // A film has no parts to record, so an episode on one is meaningless and
    // is ignored rather than allowed to change what the entry means.
    final bool namesPart = type != calendarMovieType && episode != null;

    if (!namesPart) {
      return const CalendarProgressIntent(
        action: CalendarProgressAction.markSeen,
        marksFriendsSeen: true,
      );
    }
    if (alreadyFinished) {
      return const CalendarProgressIntent(
        action: CalendarProgressAction.none,
        marksFriendsSeen: false,
      );
    }
    return CalendarProgressIntent(
      action: CalendarProgressAction.markWatchedThrough,
      marksFriendsSeen: false,
      season: episode.season,
      episode: episode.episode,
    );
  }
}
