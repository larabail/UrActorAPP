/// Holds the ticked-episode state for one show while its season and episode
/// screens are open.
///
/// The season list and the episode list are separate routes, and a tick made on
/// one has to be visible on the other the moment the user navigates back. A
/// controller shared between them is the smallest thing that keeps both honest
/// without either screen re-reading Firestore on every rebuild.
library;

import 'package:flutter/foundation.dart';

import 'firebase/progress_service.dart';
import 'watch_progress_view.dart';

class ShowProgressController extends ChangeNotifier {
  ShowProgressController({required String showId, required this.seasons})
      : showId = showId.toString();

  final String showId;
  final List<SeasonEpisodeCount> seasons;

  final Map<int, Set<int>> _watched = <int, Set<int>>{};
  WatchProgressState _state = WatchProgressState.notStarted;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;

  /// True until the first read lands. Screens draw a placeholder tick rather
  /// than an unticked one, so an already-watched episode never flashes as
  /// unwatched before the read returns.
  bool get loading => _loading;

  /// True while a write is in flight. Toggles are refused meanwhile, because
  /// two overlapping writes to the same show both merge the episode map they
  /// read at the start and the later one silently drops the earlier tick.
  bool get busy => _busy;

  WatchProgressState get state => _state;

  Set<int> watchedIn(int seasonNumber) =>
      _watched[seasonNumber] ?? const <int>{};

  bool isWatched(int seasonNumber, int episodeNumber) =>
      watchedIn(seasonNumber).contains(episodeNumber);

  int episodeCountOf(int seasonNumber) {
    for (final season in seasons) {
      if (season.seasonNumber == seasonNumber) return season.episodeCount;
    }
    return 0;
  }

  int watchedCountOf(int seasonNumber) => WatchProgressView.watchedInSeason(
        episodeCount: episodeCountOf(seasonNumber),
        watched: watchedIn(seasonNumber),
      );

  SeasonTickState seasonTickState(int seasonNumber) =>
      WatchProgressView.seasonTickState(
        episodeCount: episodeCountOf(seasonNumber),
        watched: watchedIn(seasonNumber),
      );

  Future<void> load() async {
    _loading = true;
    await _refresh();
    _loading = false;
    _notify();
  }

  Future<void> toggleEpisode(int seasonNumber, int episodeNumber) async {
    if (!WatchProgressView.isTickableSeason(seasonNumber)) return;
    await _write(() async {
      if (isWatched(seasonNumber, episodeNumber)) {
        await ProgressService.unmarkEpisodeWatched(
          showId,
          seasonNumber,
          episodeNumber,
        );
      } else {
        await ProgressService.markEpisodeWatched(
          showId,
          seasonNumber,
          episodeNumber,
          seasons,
        );
      }
    });
  }

  /// Ticks a whole season, or clears it when it is already complete.
  ///
  /// A part-watched season fills up rather than clearing: the user who has seen
  /// half a season and reaches for the season control is far more likely to
  /// mean "I finished this" than "throw away what I recorded".
  Future<void> toggleSeason(int seasonNumber) async {
    if (!WatchProgressView.isTickableSeason(seasonNumber)) return;
    final episodeCount = episodeCountOf(seasonNumber);
    if (episodeCount <= 0) return;
    final complete = seasonTickState(seasonNumber) == SeasonTickState.all;
    await _write(() async {
      if (complete) {
        await ProgressService.unmarkSeasonWatched(showId, seasonNumber);
      } else {
        await ProgressService.markSeasonWatched(
          showId,
          seasonNumber,
          episodeCount,
          seasons,
        );
      }
    });
  }

  Future<void> _write(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      await action();
      await _refresh();
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _refresh() async {
    final bySeason = await ProgressService.watchedEpisodesBySeason(showId);
    _watched
      ..clear()
      ..addEntries(
        bySeason.entries
            .map((entry) => MapEntry(entry.key, entry.value.toSet())),
      );
    _state = await ProgressService.showState(showId);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
