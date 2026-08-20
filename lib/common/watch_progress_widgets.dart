/// The small controls that put watch progress on screen.
///
/// Everything here is deliberately icon-sized. A full-width row for each of
/// these would push the content a user actually came for off the bottom of the
/// screen, so the season and episode toggles sit inside the rows that already
/// exist and the detail-screen control rides along in the status icon row.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'firebase/progress_service.dart';
import 'watch_progress_controller.dart';
import 'watch_progress_view.dart';

/// Marks or clears a whole season.
///
/// Renders nothing for season 0: `ProgressService` ignores specials, so a
/// control there would be a button that does nothing.
class SeasonWatchToggle extends StatelessWidget {
  final ShowProgressController controller;
  final int seasonNumber;

  const SeasonWatchToggle({
    required this.controller,
    required this.seasonNumber,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!WatchProgressView.isTickableSeason(seasonNumber)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tick = controller.seasonTickState(seasonNumber);
        final complete = tick == SeasonTickState.all;
        final enabled =
            !controller.loading &&
            !controller.busy &&
            controller.episodeCountOf(seasonNumber) > 0;
        return _ToggleButton(
          key: ValueKey('seasonWatchToggle-$seasonNumber'),
          icon: switch (tick) {
            SeasonTickState.all => Icons.check_circle,
            SeasonTickState.partial => Icons.adjust,
            SeasonTickState.none => Icons.radio_button_unchecked,
          },
          color: switch (tick) {
            SeasonTickState.all => Colors.green,
            SeasonTickState.partial => Colors.amber,
            SeasonTickState.none => null,
          },
          tooltip: complete
              ? S.of(context)!.watchProgressUnmarkSeason
              : S.of(context)!.watchProgressMarkSeason,
          onPressed: enabled
              ? () => controller.toggleSeason(seasonNumber)
              : null,
        );
      },
    );
  }
}

/// Marks or clears a single episode.
class EpisodeWatchToggle extends StatelessWidget {
  final ShowProgressController controller;
  final int seasonNumber;
  final int episodeNumber;

  const EpisodeWatchToggle({
    required this.controller,
    required this.seasonNumber,
    required this.episodeNumber,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!WatchProgressView.isTickableSeason(seasonNumber)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final watched = controller.isWatched(seasonNumber, episodeNumber);
        final enabled = !controller.loading && !controller.busy;
        return _ToggleButton(
          key: ValueKey('episodeWatchToggle-$seasonNumber-$episodeNumber'),
          icon: watched ? Icons.check_circle : Icons.radio_button_unchecked,
          color: watched ? Colors.green : null,
          tooltip: watched
              ? S.of(context)!.watchProgressUnmarkEpisode
              : S.of(context)!.watchProgressMarkEpisode,
          onPressed: enabled
              ? () => controller.toggleEpisode(seasonNumber, episodeNumber)
              : null,
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToggleButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      iconSize: 26,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

enum _ProgressMenuAction { start, finish, reopen }

/// The watch-progress control on a movie or TV show detail screen.
///
/// One icon that shows which of the three states the title is in, opening a
/// menu with whatever move follows from that state. A finished movie has no
/// move: `ProgressService.reopenMovie` throws, so the control stays purely
/// informational rather than offering something that would fail.
class MediaProgressControl extends StatefulWidget {
  final String id;

  /// `progressMoviesKey` or `progressTVShowsKey`.
  final String type;

  /// Bumped by the host screen when something outside this widget could have
  /// changed the state — marking a title seen finishes it, and the control
  /// would otherwise keep showing the state it read when it was built.
  final int refreshToken;

  /// Called after a successful change, so the host can redraw anything else
  /// that depends on the title's state.
  final VoidCallback? onChanged;

  const MediaProgressControl({
    required this.id,
    required this.type,
    this.refreshToken = 0,
    this.onChanged,
    super.key,
  });

  @override
  State<MediaProgressControl> createState() => _MediaProgressControlState();
}

class _MediaProgressControlState extends State<MediaProgressControl> {
  WatchProgressState? _state;
  WatchProgressDates _dates = const WatchProgressDates();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaProgressControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.id != widget.id ||
        oldWidget.type != widget.type) {
      _load();
    }
  }

  Future<void> _load() async {
    final state = await ProgressService.stateFor(widget.type, widget.id);
    final dates = await ProgressService.datesFor(widget.type, widget.id);
    if (!mounted) return;
    setState(() {
      _state = state;
      _dates = dates;
    });
  }

  Future<void> _run(_ProgressMenuAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (action) {
        case _ProgressMenuAction.start:
        case _ProgressMenuAction.reopen:
          await ProgressService.startItem(widget.type, widget.id);
        case _ProgressMenuAction.finish:
          await ProgressService.finishItem(widget.type, widget.id);
      }
    } on StateError {
      // The only StateError the service throws here is "a finished movie
      // cannot be reopened", which means the record moved on since this
      // control last read it. Reloading below shows the truth.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
    if (mounted) widget.onChanged?.call();
  }

  String _statusText(BuildContext context) {
    switch (_state) {
      case null:
      case WatchProgressState.notStarted:
        return S.of(context)!.watchProgressNotStarted;
      case WatchProgressState.inProgress:
        final started = _dates.started;
        return started == null
            ? S.of(context)!.watchProgressInProgress
            : S.of(context)!.watchProgressStartedOn(started);
      case WatchProgressState.finished:
        final finished = _dates.finished;
        return finished == null
            ? S.of(context)!.watchProgressFinished
            : S.of(context)!.watchProgressFinishedOn(finished);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state ?? WatchProgressState.notStarted;
    final actions = WatchProgressView.actionsForType(state, widget.type);
    final status = _statusText(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
      child: PopupMenuButton<_ProgressMenuAction>(
        key: const ValueKey('watchProgressControl'),
        tooltip: '${S.of(context)!.watchProgress}: $status',
        padding: EdgeInsets.zero,
        iconSize: 40,
        enabled: !_busy,
        icon: Icon(
          switch (state) {
            WatchProgressState.notStarted => Icons.play_circle_outline,
            WatchProgressState.inProgress => Icons.play_circle,
            WatchProgressState.finished => Icons.check_circle,
          },
          color: switch (state) {
            WatchProgressState.notStarted => null,
            WatchProgressState.inProgress => Colors.amber,
            WatchProgressState.finished => Colors.green,
          },
        ),
        onSelected: _run,
        itemBuilder: (context) => <PopupMenuEntry<_ProgressMenuAction>>[
          PopupMenuItem<_ProgressMenuAction>(
            enabled: false,
            child: Text(status),
          ),
          if (!actions.isEmpty) const PopupMenuDivider(),
          if (actions.canStart)
            PopupMenuItem<_ProgressMenuAction>(
              value: _ProgressMenuAction.start,
              child: Text(S.of(context)!.watchProgressStart),
            ),
          if (actions.canFinish)
            PopupMenuItem<_ProgressMenuAction>(
              value: _ProgressMenuAction.finish,
              child: Text(S.of(context)!.watchProgressFinish),
            ),
          if (actions.canReopen)
            PopupMenuItem<_ProgressMenuAction>(
              value: _ProgressMenuAction.reopen,
              child: Text(S.of(context)!.watchProgressReopen),
            ),
        ],
      ),
    );
  }
}
