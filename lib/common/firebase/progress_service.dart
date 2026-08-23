import 'package:cloud_firestore/cloud_firestore.dart';

import '../../main.dart';
import 'firestore_core.dart';

const String progressMoviesKey = 'Movies';
const String progressTVShowsKey = 'TVShows';

/// The watch state exposed to UI consumers.
enum WatchProgressState { notStarted, inProgress, finished }

/// TMDB season metadata needed to reason about completion.
class SeasonEpisodeCount {
  const SeasonEpisodeCount({
    required this.seasonNumber,
    required this.episodeCount,
  });

  final int seasonNumber;
  final int episodeCount;
}

/// A concrete episode pointer.
class WatchProgressEpisode {
  const WatchProgressEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
  });

  final int seasonNumber;
  final int episodeNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchProgressEpisode &&
          runtimeType == other.runtimeType &&
          seasonNumber == other.seasonNumber &&
          episodeNumber == other.episodeNumber;

  @override
  int get hashCode => Object.hash(seasonNumber, episodeNumber);

  @override
  String toString() => 'S$seasonNumber E$episodeNumber';
}

/// The dates recorded against a title, as stored: `yyyy-MM-dd` strings, or null
/// when nothing has been recorded yet.
class WatchProgressDates {
  const WatchProgressDates({this.started, this.finished});

  final String? started;
  final String? finished;
}

/// An item for a later Continue watching surface.
class WatchProgressListItem {
  const WatchProgressListItem({
    required this.type,
    required this.id,
    required this.started,
    required this.updated,
  });

  final String type;
  final String id;
  final String started;
  final String updated;
}

class ProgressService {
  static String formatDate(DateTime date) =>
      date.toIso8601String().split('T')[0];

  static Future<WatchProgressState> movieState(String id) =>
      stateFor(progressMoviesKey, id);

  static Future<WatchProgressState> showState(String id) =>
      stateFor(progressTVShowsKey, id);

  static Future<WatchProgressState> stateFor(String type, String id) async {
    id = id.toString();
    if (_isSeen(type, id)) return WatchProgressState.finished;

    final entry = await _entry(type, id);
    if (entry == null) return WatchProgressState.notStarted;
    return entry['finished'] == null
        ? WatchProgressState.inProgress
        : WatchProgressState.notStarted;
  }

  static Future<void> startMovie(String id, {DateTime? date}) async {
    id = id.toString();
    if (_isSeen(progressMoviesKey, id)) {
      throw StateError('Finished movies cannot be reopened into progress.');
    }
    await _start(progressMoviesKey, id, date: date);
  }

  static Future<void> startShow(String id, {DateTime? date}) async {
    id = id.toString();
    await _removeSeen(progressTVShowsKey, id);
    await _start(progressTVShowsKey, id, date: date);
  }

  static Future<void> startItem(
    String type,
    String id, {
    DateTime? date,
  }) async {
    if (type == progressMoviesKey) {
      await startMovie(id, date: date);
    } else if (type == progressTVShowsKey) {
      await startShow(id, date: date);
    } else {
      throw ArgumentError.value(type, 'type', 'Use Movies or TVShows.');
    }
  }

  static Future<void> finishMovie(String id, {DateTime? date}) =>
      finishItem(progressMoviesKey, id, date: date);

  static Future<void> finishShow(String id, {DateTime? date}) =>
      finishItem(progressTVShowsKey, id, date: date);

  static Future<void> finishItem(
    String type,
    String id, {
    DateTime? date,
  }) async {
    id = id.toString();
    _requireType(type);
    final today = formatDate(date ?? DateTime.now());
    final existing = await _entry(type, id) ?? <String, dynamic>{};
    final started = existing['started']?.toString() ?? today;
    await _writeEntry(type, id, {
      ...existing,
      'started': started,
      'finished': today,
      'updated': today,
    });
    await _addSeen(type, id);
  }

  static Future<void> reopenShow(String id, {DateTime? date}) =>
      startShow(id, date: date);

  static Future<void> reopenMovie(String id) async {
    throw StateError('Finished movies cannot be reopened into progress.');
  }

  static Future<void> markEpisodeWatched(
    String showId,
    int seasonNumber,
    int episodeNumber,
    List<SeasonEpisodeCount> seasons, {
    DateTime? date,
  }) async {
    if (seasonNumber == 0) return;
    final today = formatDate(date ?? DateTime.now());
    final entry = await _showEntryInProgress(showId, today);
    final episodes = _episodesFrom(entry);
    final watched = _watchedSet(episodes, seasonNumber)..add(episodeNumber);
    episodes[seasonNumber.toString()] = _sortedEpisodes(watched);
    await _writeEntry(progressTVShowsKey, showId.toString(), {
      ...entry,
      'finished': null,
      'updated': today,
      'episodes': episodes,
    });
    if (_allNonSpecialEpisodesWatched(episodes, seasons)) {
      await finishShow(showId, date: date);
    }
  }

  /// Ticks every episode in [bySeason] on top of whatever is already recorded.
  ///
  /// Additive on purpose: a season the caller did not mention keeps its ticks,
  /// so logging "I finished S2E5 today" cannot undo a season 3 already
  /// watched. An empty map still leaves the show in progress, which is what a
  /// calendar entry naming a season TMDB has no episode count for amounts to.
  ///
  /// Finishes the show when this completes every non-special episode, by the
  /// same check the season guide uses.
  ///
  /// [keepFinished] records the ticks against a show the user has already
  /// finished without disturbing that. Ticking normally moves a show into
  /// progress, which drops it from the Seen list that drives the user's badges
  /// and counts; naming an episode of a show you have already seen is not a
  /// request to undo any of that, but the episodes still have to be recorded
  /// or the season guide — which draws only what is ticked — shows nothing.
  static Future<void> markEpisodesWatched(
    String showId,
    Map<int, List<int>> bySeason,
    List<SeasonEpisodeCount> seasons, {
    DateTime? date,
    bool keepFinished = false,
  }) async {
    final today = formatDate(date ?? DateTime.now());
    final entry = keepFinished
        ? await _finishedShowEntry(showId, today)
        : await _showEntryInProgress(showId, today);
    final episodes = _episodesFrom(entry);
    for (final season in bySeason.entries) {
      if (season.key <= 0) continue;
      final watched = _watchedSet(episodes, season.key)
        ..addAll(season.value.where((episode) => episode > 0));
      episodes[season.key.toString()] = _sortedEpisodes(watched);
    }
    await _writeEntry(progressTVShowsKey, showId.toString(), {
      ...entry,
      'updated': today,
      'episodes': episodes,
    });
    if (!keepFinished && _allNonSpecialEpisodesWatched(episodes, seasons)) {
      await finishShow(showId, date: date);
    }
  }

  static Future<void> unmarkEpisodeWatched(
    String showId,
    int seasonNumber,
    int episodeNumber, {
    DateTime? date,
  }) async {
    if (seasonNumber == 0) return;
    final today = formatDate(date ?? DateTime.now());
    final entry = await _showEntryInProgress(showId, today);
    final episodes = _episodesFrom(entry);
    final watched = _watchedSet(episodes, seasonNumber)..remove(episodeNumber);
    episodes[seasonNumber.toString()] = _sortedEpisodes(watched);
    await _writeEntry(progressTVShowsKey, showId.toString(), {
      ...entry,
      'finished': null,
      'updated': today,
      'episodes': episodes,
    });
  }

  static Future<void> markSeasonWatched(
    String showId,
    int seasonNumber,
    int episodeCount,
    List<SeasonEpisodeCount> seasons, {
    DateTime? date,
  }) async {
    if (seasonNumber == 0) return;
    final today = formatDate(date ?? DateTime.now());
    final entry = await _showEntryInProgress(showId, today);
    final episodes = _episodesFrom(entry);
    episodes[seasonNumber.toString()] = List<int>.generate(
      episodeCount,
      (index) => index + 1,
    );
    await _writeEntry(progressTVShowsKey, showId.toString(), {
      ...entry,
      'finished': null,
      'updated': today,
      'episodes': episodes,
    });
    if (_allNonSpecialEpisodesWatched(episodes, seasons)) {
      await finishShow(showId, date: date);
    }
  }

  static Future<void> unmarkSeasonWatched(
    String showId,
    int seasonNumber, {
    DateTime? date,
  }) async {
    if (seasonNumber == 0) return;
    final today = formatDate(date ?? DateTime.now());
    final entry = await _showEntryInProgress(showId, today);
    final episodes = _episodesFrom(entry);
    episodes[seasonNumber.toString()] = <int>[];
    await _writeEntry(progressTVShowsKey, showId.toString(), {
      ...entry,
      'finished': null,
      'updated': today,
      'episodes': episodes,
    });
  }

  static Future<List<int>> watchedEpisodes(
    String showId,
    int seasonNumber,
  ) async {
    final entry = await _entry(progressTVShowsKey, showId.toString());
    if (entry == null) return <int>[];
    return _sortedEpisodes(_watchedSet(_episodesFrom(entry), seasonNumber));
  }

  /// Every season's watched episodes in one read.
  ///
  /// [watchedEpisodes] answers for a single season, which costs a document read
  /// each time; a screen showing a whole show would pay that per season on
  /// every tick. Same data, same shape, read once.
  static Future<Map<int, List<int>>> watchedEpisodesBySeason(
    String showId,
  ) async {
    final entry = await _entry(progressTVShowsKey, showId.toString());
    if (entry == null) return <int, List<int>>{};
    final episodes = _episodesFrom(entry);
    final bySeason = <int, List<int>>{};
    for (final key in episodes.keys) {
      final seasonNumber = int.tryParse(key);
      if (seasonNumber == null) continue;
      bySeason[seasonNumber] = _sortedEpisodes(
        _watchedSet(episodes, seasonNumber),
      );
    }
    return bySeason;
  }

  /// The start and finish dates recorded for a title, so a screen can show when
  /// something was watched without reaching into the stored entry shape itself.
  static Future<WatchProgressDates> datesFor(String type, String id) async {
    final entry = await _entry(type, id.toString());
    if (entry == null) return const WatchProgressDates();
    return WatchProgressDates(
      started: entry['started']?.toString(),
      finished: entry['finished']?.toString(),
    );
  }

  static Future<List<WatchProgressListItem>> inProgressItems() async {
    final progress = await _readProgress();
    final items = <WatchProgressListItem>[];
    for (final type in [progressMoviesKey, progressTVShowsKey]) {
      final typeMap = _typeMap(progress, type);
      for (final entry in typeMap.entries) {
        final id = entry.key.toString();
        final value = Map<String, dynamic>.from(entry.value as Map);
        if (_isSeen(type, id) || value['finished'] != null) continue;
        final started = value['started']?.toString();
        final updated = value['updated']?.toString() ?? started;
        if (started == null || updated == null) continue;
        items.add(
          WatchProgressListItem(
            type: type,
            id: id,
            started: started,
            updated: updated,
          ),
        );
      }
    }
    items.sort((a, b) => b.updated.compareTo(a.updated));
    return items;
  }

  static Future<void> _start(String type, String id, {DateTime? date}) async {
    final today = formatDate(date ?? DateTime.now());
    final existing = await _entry(type, id) ?? <String, dynamic>{};
    final entry = <String, dynamic>{
      ...existing,
      'started': existing['started']?.toString() ?? today,
      'finished': null,
      'updated': today,
    };
    if (type == progressTVShowsKey) {
      entry['episodes'] = _episodesFrom(existing);
    }
    await _writeEntry(type, id, entry);
  }

  static Future<Map<String, dynamic>> _showEntryInProgress(
    String showId,
    String today,
  ) async {
    await _removeSeen(progressTVShowsKey, showId.toString());
    final existing = await _entry(progressTVShowsKey, showId.toString()) ??
        <String, dynamic>{};
    return <String, dynamic>{
      ...existing,
      'started': existing['started']?.toString() ?? today,
      'finished': null,
      'episodes': _episodesFrom(existing),
    };
  }

  /// The stored entry for a show the user has already finished, left finished.
  ///
  /// The counterpart to [_showEntryInProgress], which exists to say "I am
  /// watching this" and so clears the Seen list membership and the finish
  /// date. Recording which episodes a finished show covers says nothing of the
  /// kind, so both survive.
  ///
  /// A show finished only by sitting in the Seen list has no stored entry at
  /// all, so one is invented dated today. That is the same convention
  /// [finishItem] uses for a missing start date, and it matters because the
  /// entry would otherwise read as in progress the moment anything removed the
  /// title from Seen.
  static Future<Map<String, dynamic>> _finishedShowEntry(
    String showId,
    String today,
  ) async {
    final existing = await _entry(progressTVShowsKey, showId.toString()) ??
        <String, dynamic>{};
    return <String, dynamic>{
      ...existing,
      'started': existing['started']?.toString() ?? today,
      'finished': existing['finished']?.toString() ?? today,
      'episodes': _episodesFrom(existing),
    };
  }

  static Future<Map<String, dynamic>?> _entry(String type, String id) async {
    _requireType(type);
    final progress = await _readProgress();
    final typeMap = _typeMap(progress, type);
    final entry = typeMap[id];
    if (entry is Map) return Map<String, dynamic>.from(entry);
    return null;
  }

  static Future<Map<String, dynamic>> _readProgress() async {
    final info = await FirestoreCore.getDocumentData(
      currentUser.uid,
      'Progress',
    );
    final data = Map<String, dynamic>.from(info['data'] as Map);
    currentUser.progress = data;
    return data;
  }

  static Future<void> _writeEntry(
    String type,
    String id,
    Map<String, dynamic> entry,
  ) async {
    _requireType(type);
    final progressDoc =
        FirestoreCore.db.collection(currentUser.uid).doc('Progress');
    await FirestoreCore.mergeInto(progressDoc, {
      type: {id: entry},
    });
    await _readProgress();
  }

  static Map<String, dynamic> _typeMap(
    Map<String, dynamic> progress,
    String type,
  ) {
    final value = progress[type];
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _episodesFrom(Map entry) {
    final value = entry['episodes'];
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Set<int> _watchedSet(Map<String, dynamic> episodes, int seasonNumber) {
    final watched = episodes[seasonNumber.toString()];
    if (watched is! Iterable) return <int>{};
    return watched
        .map((episode) => int.tryParse(episode.toString()))
        .whereType<int>()
        .toSet();
  }

  static List<int> _sortedEpisodes(Set<int> watched) {
    final list = watched.where((episode) => episode > 0).toList()..sort();
    return list;
  }

  static bool _allNonSpecialEpisodesWatched(
    Map<String, dynamic> episodes,
    List<SeasonEpisodeCount> seasons,
  ) {
    final counted = seasons.where(
      (season) => season.seasonNumber != 0 && season.episodeCount > 0,
    );
    if (counted.isEmpty) return false;
    for (final season in counted) {
      final watched = _watchedSet(episodes, season.seasonNumber);
      for (var episode = 1; episode <= season.episodeCount; episode++) {
        if (!watched.contains(episode)) return false;
      }
    }
    return true;
  }

  static Future<void> _addSeen(String type, String id) async {
    await FirestoreCore.updateDocument(currentUser.uid, type, {
      'Seen': FieldValue.arrayUnion([id]),
    });
    await FirestoreCore.updateDocument(currentUser.uid, 'Seen', {
      type: FieldValue.arrayUnion([id]),
    });
    _addSeenLocal(type, id);
  }

  static Future<void> _removeSeen(String type, String id) async {
    final typeDoc = await FirestoreCore.getDocumentData(currentUser.uid, type);
    if ((typeDoc['doc'] as DocumentSnapshot).exists) {
      final data = typeDoc['data'] as Map;
      final items = List<dynamic>.from(
        data['Seen'] ?? data[type] ?? <dynamic>[],
      )..removeWhere((item) => item.toString() == id);
      await (typeDoc['snapshot'] as DocumentReference).set({
        'Seen': items,
      }, SetOptions(merge: true));
    }

    final seenDoc = await FirestoreCore.getDocumentData(
      currentUser.uid,
      'Seen',
    );
    if ((seenDoc['doc'] as DocumentSnapshot).exists) {
      final data = seenDoc['data'] as Map;
      final items = List<dynamic>.from(data[type] ?? <dynamic>[])
        ..removeWhere((item) => item.toString() == id);
      await (seenDoc['snapshot'] as DocumentReference).set({
        type: items,
      }, SetOptions(merge: true));
    }
    _removeSeenLocal(type, id);
  }

  static bool _isSeen(String type, String id) {
    final list = type == progressMoviesKey
        ? currentUser.seenMovies
        : currentUser.seenTVShows;
    return list.any(
      (pair) =>
          pair is List &&
          pair.length >= 2 &&
          pair[0] == type &&
          pair[1].toString() == id,
    );
  }

  static void _addSeenLocal(String type, String id) {
    final typed = [type, id];
    final list = type == progressMoviesKey
        ? currentUser.seenMovies
        : currentUser.seenTVShows;
    if (!_isSeen(type, id)) list.add(typed);
    final inCombined = currentUser.seen.any(
      (pair) =>
          pair is List &&
          pair.length >= 2 &&
          pair[0] == type &&
          pair[1].toString() == id,
    );
    if (!inCombined) currentUser.seen.add(typed);
  }

  static void _removeSeenLocal(String type, String id) {
    currentUser.seen.removeWhere(
      (pair) =>
          pair is List &&
          pair.length >= 2 &&
          pair[0] == type &&
          pair[1].toString() == id,
    );
    if (type == progressMoviesKey) {
      currentUser.seenMovies.removeWhere(
        (pair) => pair is List && pair.length >= 2 && pair[1].toString() == id,
      );
    } else {
      currentUser.seenTVShows.removeWhere(
        (pair) => pair is List && pair.length >= 2 && pair[1].toString() == id,
      );
    }
  }

  static void _requireType(String type) {
    if (type != progressMoviesKey && type != progressTVShowsKey) {
      throw ArgumentError.value(type, 'type', 'Use Movies or TVShows.');
    }
  }
}
