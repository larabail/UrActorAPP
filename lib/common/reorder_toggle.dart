import 'package:flutter/material.dart';

/// The app bar icon that turns drag-to-rearrange on and off.
///
/// This started as a labelled button on its own row, which cost a full row of
/// vertical space on every visit for a control that is used rarely. As an app
/// bar icon it costs nothing and sits in the same place on every page that
/// offers rearranging.
///
/// The icon carries the state on its own: a check means "done", which reads as
/// the way out of rearrange mode without needing a label to say so.
class ReorderToggle extends StatelessWidget {
  const ReorderToggle({
    super.key,
    required this.isReordering,
    required this.onPressed,
    required this.enterTooltip,
    required this.exitTooltip,
  });

  final bool isReordering;
  final VoidCallback onPressed;

  /// Kept as tooltips rather than dropped entirely, so the meaning of the icon
  /// is still discoverable now that it has no visible label.
  final String enterTooltip;
  final String exitTooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isReordering ? exitTooltip : enterTooltip,
      child: InkWell(
        onTap: onPressed,
        child: Icon(
          isReordering ? Icons.check : Icons.swap_vert,
          // Green while active, matching the accent the rest of the app uses
          // for a confirming action, so it is obvious the mode is on.
          color: isReordering ? Colors.green : null,
        ),
      ),
    );
  }
}
