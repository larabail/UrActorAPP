import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// A single line of text that scrolls itself when it is too long to fit.
///
/// A line that is simply clipped tells the reader there is more and then
/// refuses to show it. Scrolling it costs no extra room in the layout, which
/// matters where the line is a subtitle under something else and any second
/// row would push the thing above it around.
///
/// Text that already fits is drawn as ordinary [Text]. A marquee that scrolls
/// when it does not need to is a distraction, and a static line can be read at
/// a glance rather than waited for.
///
/// One consequence worth knowing: while it is scrolling, this never stops
/// animating, so `pumpAndSettle` in a widget test will time out on a screen
/// that contains one. Pump fixed durations instead.
class ScrollingLine extends StatelessWidget {
  const ScrollingLine({
    super.key,
    required this.text,
    required this.style,
    required this.height,
    this.velocity = 25.0,
  });

  final String text;
  final TextStyle style;

  /// The room the line is given. Fixed rather than measured, because the
  /// scrolling case has to be given a bounded height and the two cases must
  /// occupy the same space or the layout jumps when a title resolves.
  final double height;

  /// Logical pixels per second. Slow enough to read at a glance; the default
  /// matches the carousel on the home page.
  final double velocity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);

          if (!painter.didExceedMaxLines) {
            return Text(text, style: style, maxLines: 1);
          }

          return Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: 30.0,
            velocity: velocity,
            // A beat at the start of each round, so the beginning of the line
            // can be read without chasing it.
            pauseAfterRound: const Duration(seconds: 1),
            startPadding: 0.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          );
        },
      ),
    );
  }
}
