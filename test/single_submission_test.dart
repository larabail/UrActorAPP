/// Tests for the single-submission guard.
///
/// The rule it exists for is narrow and entirely about timing: a second call
/// arriving while the first is still running has to do nothing at all. A
/// [Completer] is what makes that observable -- it holds the first submission
/// open for as long as the test needs, rather than hoping a real write is slow
/// enough to catch in the act.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/single_submission.dart';
import 'package:uractor/l10n/l10n.dart';

import 'dart:async';

/// A widget whose button submits, so the mixin is exercised the way a dialogue
/// uses it: through a tap, with `setState` driving what is on screen.
class _Submitter extends StatefulWidget {
  const _Submitter({required this.action});

  final Future<void> Function() action;

  @override
  State<_Submitter> createState() => _SubmitterState();
}

class _SubmitterState extends State<_Submitter> with SingleSubmission {
  /// How many times the submission actually started.
  int started = 0;

  /// What each tap returned, in order.
  final List<bool> results = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final ok = await submit(() {
                started++;
                return widget.action();
              }, S.of(context)!.genericAuthError);
              results.add(ok);
            },
            child: const Text('save'),
          ),
          Text(submitting ? 'busy' : 'idle'),
        ],
      ),
    );
  }
}

void main() {
  Future<_SubmitterState> pump(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: _Submitter(action: action),
      ),
    );
    return tester.state<_SubmitterState>(find.byType(_Submitter));
  }

  testWidgets('a second tap during a submission is ignored', (tester) async {
    // The whole point. Logging a title takes a dozen round trips, and every
    // extra tap during them used to write the entry again.
    final gate = Completer<void>();
    final state = await pump(tester, () => gate.future);

    await tester.tap(find.text('save'));
    await tester.pump();
    await tester.tap(find.text('save'));
    await tester.tap(find.text('save'));
    await tester.pump();

    expect(state.started, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(state.started, 1, reason: 'the ignored taps never ran anything');
  });

  testWidgets('the flag is on for exactly as long as the work runs',
      (tester) async {
    final gate = Completer<void>();
    await pump(tester, () => gate.future);

    expect(find.text('idle'), findsOneWidget);

    await tester.tap(find.text('save'));
    await tester.pump();

    expect(find.text('busy'), findsOneWidget,
        reason: 'the screen has to say the tap registered');

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('an ignored tap reports failure rather than success',
      (tester) async {
    // The caller closes the dialogue on a true, so a tap that did nothing must
    // not come back saying it saved.
    final gate = Completer<void>();
    final state = await pump(tester, () => gate.future);

    await tester.tap(find.text('save'));
    await tester.pump();
    await tester.tap(find.text('save'));
    await tester.pump();

    expect(state.results, [false], reason: 'only the ignored tap has returned');

    gate.complete();
    await tester.pumpAndSettle();

    expect(state.results, [false, true]);
  });

  testWidgets('a failed submission is reported and lets the next one through',
      (tester) async {
    var attempts = 0;
    final state = await pump(tester, () async {
      attempts++;
      if (attempts == 1) throw StateError('write failed');
    });

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(state.results, [false]);
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('idle'), findsOneWidget,
        reason: 'a failure must not leave the dialogue stuck mid-save');

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(state.results, [false, true]);
  });
}
