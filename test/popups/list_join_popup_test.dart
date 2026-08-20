/// Tests for the join-a-playlist dialogue.
///
/// The join itself goes through a Cloud Function with a Firebase ID token, so
/// it cannot run here. What can be checked is the form around it: that both
/// fields the function needs are asked for, that they are localized, and that
/// backing out costs nothing.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/popups/list_join_popup.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = installFakeFirestore();
    installTestUser();
  });

  Future<void> openDialog(WidgetTester tester,
      {Locale locale = const Locale('en')}) async {
    // Wider than a phone: the Cancel/Add row overflows a 400pt dialogue,
    // which is a real layout problem here but not what these tests measure.
    usePhoneSurface(tester, size: const Size(560, 900));
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ListJoinDialogue(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the two things the server needs to match a list',
      (tester) async {
    await openDialog(tester);

    expect(find.text('Join List'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'List Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Access Code'), findsOneWidget);
  });

  testWidgets('is offered in Spanish too', (tester) async {
    // Every string here comes from the arb files. A hardcoded label would
    // still be English on a Spanish device, and this is what would catch it.
    await openDialog(tester, locale: const Locale('es'));

    expect(find.text('Join List'), findsNothing);
    expect(find.text('Unirse a Lista'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nombre de la Lista'),
        findsOneWidget);
  });

  testWidgets('cancelling closes without joining anything', (tester) async {
    await openDialog(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'List Name'), 'Film club');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Access Code'), 'sesame');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ListJoinDialogue), findsNothing);
    expect((await firestore.collection('Watchlists').get()).docs, isEmpty);
  });
}
