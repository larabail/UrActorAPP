/// The date range shown on a title's viewing history.
///
/// Small and self-contained on purpose. The history lives inside two detail
/// screens that each fetch a TMDB payload and half a dozen images before they
/// draw anything, and neither can be pumped in a test cheaply. Keeping the
/// label a widget of its own means the thing that decides what a user reads
/// can be covered without any of that.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../l10n/l10n.dart';
import 'firebase/progress_service.dart';
import 'viewing_history_range.dart';

/// Reads when a title was started and finished and renders it as a range.
///
/// Renders nothing at all when there is nothing recorded, so a title with no
/// history looks exactly as it did before this existed.
class ViewingHistoryRangeLabel extends StatefulWidget {
  /// `progressMoviesKey` or `progressTVShowsKey`.
  final String type;

  final String id;

  /// The `[date, friends]` pairs `ApiUtils.processSeenDates` read out of the
  /// calendar, which is where the dates come from for accounts that have never
  /// written a progress document.
  final List<dynamic> seenDates;

  /// Whether the title is in a Seen list. Closes the range for those accounts:
  /// they finished it, the app just never recorded the day.
  final bool seen;

  /// Bumped by the host screen when something outside this widget could have
  /// changed the record, the same way `MediaProgressControl` is refreshed.
  final int refreshToken;

  const ViewingHistoryRangeLabel({
    required this.type,
    required this.id,
    required this.seenDates,
    required this.seen,
    this.refreshToken = 0,
    super.key,
  });

  @override
  State<ViewingHistoryRangeLabel> createState() =>
      _ViewingHistoryRangeLabelState();
}

class _ViewingHistoryRangeLabelState extends State<ViewingHistoryRangeLabel> {
  WatchProgressDates _dates = const WatchProgressDates();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ViewingHistoryRangeLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.id != widget.id ||
        oldWidget.type != widget.type) {
      _load();
    }
  }

  Future<void> _load() async {
    final dates = await ProgressService.datesFor(widget.type, widget.id);
    if (!mounted) return;
    setState(() => _dates = dates);
  }

  @override
  Widget build(BuildContext context) {
    final range = ViewingHistory.rangeFor(
      seenDates: widget.seenDates,
      seen: widget.seen,
      progressStarted: _dates.started,
      progressFinished: _dates.finished,
    );
    if (range == null) return const SizedBox.shrink();

    // The same format the dates inside the history already use, so the header
    // and the rows below it do not read as two different records.
    final format = intl.DateFormat('dd MMMM, yyyy');
    final start = format.format(range.start);
    final text = range.isOpen
        ? S.of(context)!.viewingHistoryRangeOpen(start)
        : S.of(context)!.viewingHistoryRange(start, format.format(range.end!));

    return Text(
      text,
      key: const ValueKey('viewingHistoryRange'),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
    );
  }
}
