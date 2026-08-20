import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/l10n/l10n.dart';

void main() {
  testWidgets('runVisibleAsyncAction surfaces a failed awaited action', (
    tester,
  ) async {
    bool? saved;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await runVisibleAsyncAction(
                  context,
                  () async => throw StateError('write failed'),
                  S.of(context)!.genericAuthError,
                );
              },
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pump();

    expect(saved, isFalse);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('runVisibleAsyncAction returns success for completed action', (
    tester,
  ) async {
    bool? saved;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await runVisibleAsyncAction(
                  context,
                  () async {},
                  S.of(context)!.genericAuthError,
                );
              },
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pump();

    expect(saved, isTrue);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });
}
