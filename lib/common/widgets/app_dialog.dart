/// The shell every popup is built from.
///
/// Twelve files used to each grow their own: three different container types,
/// a panel colour written out thirty times, an action label that was 12, 13 or
/// 16 point depending on which file you opened. Because each one re-derived
/// the same layout, each one got it slightly differently wrong -- one pinned
/// itself to the framework's minimum width and threw away a third of the
/// screen, three had no scroll view and clipped in landscape, and four sized a
/// friend list to a fixed 125 logical pixels while sitting in 866 of empty
/// space.
///
/// Putting the inset, the panel, the scrolling and the action row in one place
/// is what stops that recurring: a popup supplies its content and nothing else.
library;

import 'package:flutter/material.dart';

/// The panel colour, previously written as `Colors.grey[900]` in thirty places.
const Color kAppDialogPanelColor = Color(0xFF212121);

/// The corner radius. Popups used 10 or 15 more or less at random.
const double kAppDialogRadius = 15.0;

/// The gap between the panel and the edge of the screen.
///
/// [Dialog] defaults to 40 on each side, so 80 of a 411pt phone was margin
/// before a popup's own padding was counted.
///
/// [AppDialog] passes this itself rather than trusting the ambient theme,
/// because a shell that silently reverts to the framework default under a
/// theme that forgot to set it is the same class of bug it exists to prevent.
/// It is *also* installed through [DialogThemeData.insetPadding] in the app
/// theme, which is what reaches the dialogues the framework builds for itself
/// -- the delete confirmation, the sign-in errors, the calendar prompts --
/// since those are `AlertDialog`s rather than [AppDialog]s.
const EdgeInsets kAppDialogInset = EdgeInsets.symmetric(
  horizontal: 16.0,
  vertical: 24.0,
);

/// How an action reads, which decides its colours.
enum AppDialogTone {
  /// Neither confirms nor discards. Renders in white.
  neutral,

  /// The action the dialogue exists to perform. Green tick.
  confirm,

  /// Backing out without doing anything. Red cross, white label.
  cancel,

  /// Something the user cannot undo. Red throughout, so it does not read as
  /// just another button next to the one beside it.
  destructive,
}

/// One button in a dialogue's action row.
@immutable
class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = AppDialogTone.neutral,
    this.busy = false,
  });

  /// Already localized by the caller. The shell has no opinion about text.
  final String label;

  final IconData? icon;

  /// Null disables the button, which is how a dialogue mid-submit stops a
  /// second tap.
  final VoidCallback? onPressed;

  final AppDialogTone tone;

  /// Whether this action is running right now.
  ///
  /// A busy action shows a spinner where its icon was and refuses taps. Both
  /// halves matter: the spinner is the only thing telling the user their tap
  /// registered, and refusing further taps is what stops the same write being
  /// started three times while the first one is still travelling.
  final bool busy;

  /// What the button is actually given, so a caller cannot leave a busy
  /// action live by forgetting to null its handler as well.
  VoidCallback? get _handler => busy ? null : onPressed;

  Color get _iconColor => switch (tone) {
        AppDialogTone.neutral => Colors.white,
        AppDialogTone.confirm => Colors.green,
        AppDialogTone.cancel => Colors.red,
        AppDialogTone.destructive => Colors.red,
      };

  Color get _labelColor =>
      tone == AppDialogTone.destructive ? Colors.red : Colors.white;
}

/// A dialogue with a pinned title, a scrolling body and a pinned action row.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.child,
    this.actions = const <AppDialogAction>[],
    this.maxWidth = 560.0,
    this.padding = const EdgeInsets.all(20.0),
    this.dismissible = true,
  });

  /// Sits above the body and does not scroll with it. Already localized.
  final String? title;

  /// The body. Scrolls on its own when it does not fit, which leaves [title]
  /// and [actions] where the user last saw them.
  final Widget child;

  /// Laid out in an [OverflowBar], so when the labels grow past the width --
  /// at a large text scale, or in a language whose words are longer -- the row
  /// stacks instead of clipping. That is what makes the action row structurally
  /// unable to overflow rather than merely wide enough today.
  final List<AppDialogAction> actions;

  /// A ceiling on the panel width, not a size.
  ///
  /// The dialogue otherwise takes everything it is offered, which is the point:
  /// popups used to sit at the framework's 280pt minimum. On a phone that is
  /// edge to edge less [kAppDialogInset]. In landscape or on a tablet it would
  /// be 880pt, and a column of text fields that wide is worse to read than one
  /// that stops. Narrow windows are unaffected by this.
  final double maxWidth;

  /// Space between the panel edge and the content.
  final EdgeInsetsGeometry padding;

  /// Whether the user may back out of the dialogue without pressing anything.
  ///
  /// False closes the two other ways out -- the system back gesture and a tap
  /// on the barrier -- which a dialogue does while its save is in flight.
  /// Disabling the buttons alone is not enough: leaving by the back gesture
  /// disposes the dialogue with the write half done and nothing left on screen
  /// to say whether it landed.
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: dismissible,
      child: Dialog(
        // The panel is the Dialog's own Material rather than a Container
        // painted on top of one. A Container leaves the nearest Material
        // *above* the list tiles, so their ink splashes have no surface to
        // land on and the framework reports that on every frame.
        backgroundColor: kAppDialogPanelColor,
        surfaceTintColor: Colors.transparent,
        insetPadding: kAppDialogInset,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(kAppDialogRadius)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Stretch is what makes the panel fill the width it is given.
              // Without it the Column shrinks to its widest child and the
              // dialogue lands back on the 280pt minimum.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Flexible(child: SingleChildScrollView(child: child)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.center,
                    spacing: 8,
                    overflowSpacing: 4,
                    children: [
                      for (final action in actions)
                        _ActionButton(action: action),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final AppDialogAction action;

  /// The spinner that stands in for the icon while the action runs.
  ///
  /// Sized to the icon it replaces so the row does not jump on the tap, which
  /// would move the neighbouring button out from under the user's finger.
  Widget get _spinner => SizedBox.square(
        dimension: 24.0,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: action._iconColor,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final label = Text(
      action.label,
      style: TextStyle(
        color: action._labelColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    final style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    // An action with no icon still has to show it is running, so it grows one
    // for as long as it is busy rather than looking untouched.
    if (action.icon == null && !action.busy) {
      return TextButton(
        onPressed: action._handler,
        style: style,
        child: label,
      );
    }
    return TextButton.icon(
      onPressed: action._handler,
      style: style,
      icon: action.busy ? _spinner : Icon(action.icon, color: action._iconColor),
      label: label,
    );
  }
}
