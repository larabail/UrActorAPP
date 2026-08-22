/// One save at a time, and something on screen that says so.
///
/// Logging a title is not one write. It fans out to the user's calendar, to
/// every tagged friend's calendar, to both seen lists, to the rewatch counter,
/// to the seen-with record and to progress -- a dozen round trips, each waiting
/// on the last. On a phone that is comfortably several seconds during which the
/// dialogue looks exactly as it did before the tap, so the obvious reading is
/// that the tap missed. Tapping again ran the whole fan-out a second time and
/// the day ended up with the same title logged twice.
///
/// Kept apart from the widgets so the rule -- a second call while one is in
/// flight does nothing -- can be tested without a dialogue around it.
library;

import 'package:flutter/material.dart';

import 'async_action.dart';

/// Gives a [State] a single in-flight submission and a flag describing it.
///
/// Read [submitting] when building, to disable whatever started the save and
/// to show that it is running.
mixin SingleSubmission<T extends StatefulWidget> on State<T> {
  bool _submitting = false;

  /// Whether a submission is running right now.
  bool get submitting => _submitting;

  /// Runs [action] unless one is already running, in which case this does
  /// nothing at all and returns false.
  ///
  /// Returns true when [action] finished without throwing, which is the
  /// caller's cue to close the dialogue. A failure is reported the way
  /// [runVisibleAsyncAction] reports it, with [errorMessage], and returns
  /// false -- the dialogue stays open so the user can try again rather than
  /// being dropped back to a screen that never gained their entry.
  Future<bool> submit(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    if (_submitting) return false;
    setState(() => _submitting = true);
    try {
      return await runVisibleAsyncAction(context, action, errorMessage);
    } finally {
      // Cleared even when the widget has gone, so an unmounted state is never
      // left claiming a submission is still running.
      _submitting = false;
      if (mounted) setState(() {});
    }
  }
}
