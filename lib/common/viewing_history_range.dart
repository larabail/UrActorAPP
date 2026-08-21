/// When a title was watched, as a range a screen can show.
///
/// The viewing history used to be drawn only for titles in a Seen list, which
/// meant ticking a single episode — which takes a show out of Seen and into
/// progress — hid every date the user had ever logged for it. The dates were
/// never lost; they come from the calendar and nothing touched them. This
/// works out what to draw from the data an account already has, so an account
/// with no `Progress` document keeps showing exactly what it showed before.
///
/// Kept free of Firestore and Flutter so the derivation can be tested without
/// a network call or a pumped frame.
library;

/// When watching a title started, and when it stopped if it has.
class ViewingHistoryRange {
  const ViewingHistoryRange({required this.start, this.end});

  final DateTime start;

  /// Null while the title is still being watched, which a screen renders as
  /// "present" rather than inventing a finish date.
  final DateTime? end;

  bool get isOpen => end == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewingHistoryRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ViewingHistoryRange($start - ${end ?? 'present'})';
}

class ViewingHistory {
  /// The range to show for a title, or null when nothing has been recorded.
  ///
  /// [seenDates] is what `ApiUtils.processSeenDates` returns: a list of
  /// `[date, friends]` pairs read out of the calendar. [progressStarted] and
  /// [progressFinished] are the stored `yyyy-MM-dd` strings, both absent for
  /// an account that has never written a progress document.
  ///
  /// [seen] closes the range for those accounts. Someone who marked a show
  /// seen years ago and logged four days against it has no finish date stored
  /// anywhere, but the app does know they finished it, and the last day they
  /// logged is the only defensible answer. Without that, every pre-existing
  /// show would read as still being watched.
  static ViewingHistoryRange? rangeFor({
    required List<dynamic> seenDates,
    required bool seen,
    String? progressStarted,
    String? progressFinished,
  }) {
    final dates = _calendarDates(seenDates);
    final started = _parse(progressStarted);
    final finished = _parse(progressFinished);

    DateTime? start = dates.isEmpty ? null : dates.first;
    if (started != null && (start == null || started.isBefore(start))) {
      start = started;
    }
    if (start == null) return null;

    DateTime? end = finished;
    if (end == null && seen && dates.isNotEmpty) end = dates.last;
    // A finish date before the start is a record that cannot be drawn as a
    // range. Collapsing it to a single day says what is known without
    // pretending time ran backwards.
    if (end != null && end.isBefore(start)) end = start;

    return ViewingHistoryRange(start: start, end: end);
  }

  /// Whether the viewing history section has anything to say.
  ///
  /// Deliberately not "is this title seen". The dates come from the calendar,
  /// so asking a Seen list whether to draw them is what made a whole history
  /// disappear the moment a show moved into progress.
  static bool hasAnything({
    required List<dynamic> seenDates,
    required bool seen,
    required bool hasProgress,
  }) => seenDates.isNotEmpty || seen || hasProgress;

  /// Whether a stored progress map holds an entry for [id] of [type].
  ///
  /// Reads the cached map rather than the document, so a screen can decide
  /// whether to draw the section without waiting on a network call.
  static bool hasProgressEntry(Map progress, String type, String id) {
    final typeMap = progress[type];
    if (typeMap is! Map) return false;
    final wanted = id.toString();
    return typeMap.keys.any((key) => key.toString() == wanted);
  }

  /// Every parseable calendar date, oldest first.
  static List<DateTime> _calendarDates(List<dynamic> seenDates) {
    final dates = <DateTime>[];
    for (final entry in seenDates) {
      // Entries are written by several client versions and by friends, so a
      // malformed one is dropped rather than allowed to throw on a screen the
      // user is already looking at.
      if (entry is List) {
        if (entry.isEmpty) continue;
        final parsed = _parse(entry[0]);
        if (parsed != null) dates.add(parsed);
      } else {
        final parsed = _parse(entry);
        if (parsed != null) dates.add(parsed);
      }
    }
    dates.sort();
    return dates;
  }

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
