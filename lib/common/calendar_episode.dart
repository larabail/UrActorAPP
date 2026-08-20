/// The optional season and episode a calendar entry may carry.
///
/// A calendar entry is a loose map that several client versions have written
/// and that friends write into each other's calendars, so nothing here may
/// assume a field is present or well typed. Entries recorded before this
/// existed carry no season at all, and must keep reading and displaying
/// exactly as they did: every accessor below answers "not recorded" rather
/// than throwing or inventing a value.
///
/// Kept free of Flutter and Firestore on purpose so the parsing and the
/// display decisions can be tested without a widget or a network call.
library;

/// The key a calendar entry stores its season under.
const String calendarSeasonKey = 'season';

/// The key a calendar entry stores its episode under.
const String calendarEpisodeKey = 'episode';

/// The key a calendar entry stores its media type under.
const String calendarEpisodeTypeKey = 'type';

/// The value that type takes for a film.
const String calendarMovieType = 'movie';

class CalendarEpisode {
  const CalendarEpisode({required this.season, this.episode});

  /// Always at least 1. Season 0 is TMDB's specials bucket, which the watch
  /// progress model already refuses to track, so it is not recorded here
  /// either rather than shown as "S0".
  final int season;

  /// Null when the entry names a season but no particular episode, which is
  /// what someone who watched a whole season in a sitting records.
  final int? episode;

  bool get hasEpisode => episode != null;

  /// Reads the season and episode an entry recorded, or null when it recorded
  /// none.
  ///
  /// An episode without a season is dropped: "E5" of an unnamed season is not
  /// something that can be displayed usefully, and it is likelier to be
  /// corrupt data than a deliberate record.
  static CalendarEpisode? fromEntry(Map? entry) {
    if (entry == null) return null;
    return from(
      season: entry[calendarSeasonKey],
      episode: entry[calendarEpisodeKey],
    );
  }

  /// Builds an episode from raw values of unknown type.
  ///
  /// Firestore hands numbers back as `int`, but the same fields arrive as
  /// `String` from a text field and as `double` from JSON, so every shape a
  /// whole number can take is accepted and everything else is discarded.
  static CalendarEpisode? from({Object? season, Object? episode}) {
    final seasonNumber = parsePositiveInt(season);
    if (seasonNumber == null) return null;
    return CalendarEpisode(
      season: seasonNumber,
      episode: parsePositiveInt(episode),
    );
  }

  /// Parses a whole number of 1 or more, or null for anything else.
  ///
  /// Used for the text fields too, where an empty box means "not recorded"
  /// rather than an error.
  static int? parsePositiveInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value >= 1 ? value : null;
    if (value is num) {
      if (value != value.roundToDouble()) return null;
      final rounded = value.toInt();
      return rounded >= 1 ? rounded : null;
    }
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null) return null;
    return parsed >= 1 ? parsed : null;
  }

  /// Whether an entry is one that can record episode detail at all.
  ///
  /// Movies cannot, and neither can the entries written before entries had a
  /// `type` — those predate TV shows being loggable and are read as movies
  /// everywhere else in the app, so they are read as movies here too.
  static bool tracksEpisodes(Map? entry) {
    if (entry == null) return false;
    final type = entry[calendarEpisodeTypeKey];
    if (type == null) return false;
    return type.toString() != calendarMovieType;
  }

  /// The fields to merge into a calendar entry.
  ///
  /// Empty for a null episode, which is what keeps an entry with nothing
  /// recorded byte-identical to what earlier clients wrote.
  static Map<String, dynamic> fieldsFor(CalendarEpisode? episode) =>
      episode == null ? const {} : episode.toFields();

  Map<String, dynamic> toFields() => {
        calendarSeasonKey: season,
        if (episode != null) calendarEpisodeKey: episode,
      };

  /// Copies the season and episode of [source] onto [target], leaving
  /// [target] untouched when there is nothing to copy.
  ///
  /// The calendar screens display a TMDB payload rather than the stored
  /// entry, so the recorded detail has to be carried across the fetch the
  /// same way the watched-with friends are.
  static void copyOnto(Map source, Map target) {
    if (!tracksEpisodes(source)) return;
    final episode = fromEntry(source);
    if (episode == null) return;
    target.addAll(episode.toFields());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEpisode &&
          runtimeType == other.runtimeType &&
          season == other.season &&
          episode == other.episode;

  @override
  int get hashCode => Object.hash(season, episode);

  @override
  String toString() => episode == null ? 'S$season' : 'S$season E$episode';
}
