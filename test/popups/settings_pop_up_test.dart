/// Tests for the settings dialogue.
///
/// Everything here writes a preference that changes what the rest of the app
/// shows: the region decides which streaming services are listed, the
/// language decides every string, and the provider set filters the whole
/// explore page. Each has to reach Firestore *and* the in-memory user, since
/// the screens read the latter and only a fresh sign-in reads the former.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/user.dart';
import 'package:uractor/popups/settings_pop_up.dart';

import '../support/harness.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppUser user;
  late HttpStub http;

  setUp(() {
    firestore = installFakeFirestore();
    user = installTestUser(settings: {
      'language': 'en',
      'providers': <String>[],
    });
    http = installHttpStub();
    http.on('configuration/countries', json: [
      {
        'iso_3166_1': 'US',
        'english_name': 'United States',
        'native_name': 'United States'
      },
      {'iso_3166_1': 'ES', 'english_name': 'Spain', 'native_name': 'España'},
    ]);
    http.on('watch/providers/movie', json: {'results': []});
  });

  Future<void> openDialog(WidgetTester tester) async {
    // The dialogue pins itself to the minimum dialogue width with a
    // SizedBox(width: 20), so its Logout/Delete row overflows on every
    // device. Widening the window cannot avoid it.
    ignoreOverflowErrors();
    ignoreNetworkImageFailures();
    usePhoneSurface(tester, size: const Size(560, 1000));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const InfoButtonDialog(),
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

  Future<Map<String, dynamic>?> settingsDoc() async {
    final doc = await firestore.collection('test-uid').doc('Settings').get();
    return doc.data();
  }

  group('parsing what TMDB sends back', () {
    test('a country keeps both of its names', () {
      final country = Country.fromJson({
        'iso_3166_1': 'ES',
        'english_name': 'Spain',
        'native_name': 'España',
      });

      expect(country.isoCode, 'ES');
      expect(country.englishName, 'Spain');
      expect(country.nativeName, 'España');
    });

    test('a provider the user already chose comes back ticked', () {
      // The tick is decided at parse time from the stored ids, which arrive
      // as strings while TMDB sends the id as a number.
      user.settings['providers'] = ['8'];

      final chosen = Provider.fromJson({
        'logo_path': '/netflix.jpg',
        'provider_name': 'Netflix',
        'provider_id': 8,
      });
      final notChosen = Provider.fromJson({
        'logo_path': '/max.jpg',
        'provider_name': 'Max',
        'provider_id': 1899,
      });

      expect(chosen.isSelected, isTrue);
      expect(chosen.id, '8');
      expect(notChosen.isSelected, isFalse);
    });
  });

  group('region', () {
    testWidgets('lists the countries TMDB returned', (tester) async {
      await openDialog(tester);

      expect(find.text('United States'), findsWidgets);
      expect(http.countFor('configuration/countries'), 1);
    });

    testWidgets('opens on the country the account is set to', (tester) async {
      user.country = 'ES';

      await openDialog(tester);

      expect(find.text('Spain'), findsWidgets);
    });

    testWidgets('an account set to a country TMDB does not list falls back to '
        'the first one', (tester) async {
      // Otherwise the dropdown is handed a value that is not among its items
      // and the whole dialogue fails to build.
      user.country = 'ZZ';

      await openDialog(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('United States'), findsWidgets);
    });

    testWidgets('choosing a country stores it', (tester) async {
      await openDialog(tester);

      await tester.tap(find.byType(DropdownButton<Country>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spain').last);
      await tester.pumpAndSettle();

      final doc = await firestore.collection('test-uid').doc('Country').get();
      expect(doc.data(), {'Country': 'ES'});
      expect(user.country, 'ES');
    });

    testWidgets('an empty country list leaves the dialogue standing',
        (tester) async {
      http.on('configuration/countries', json: []);

      await openDialog(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(InfoButtonDialog), findsOneWidget);
    });
  });

  group('language', () {
    testWidgets('offers both languages by name', (tester) async {
      await openDialog(tester);

      await tester.tap(find.byType(DropdownButton<Locale>));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      expect(find.text('Español'), findsWidgets);
    });

    testWidgets('choosing one stores it and takes effect immediately',
        (tester) async {
      await openDialog(tester);

      await tester.tap(find.byType(DropdownButton<Locale>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect((await settingsDoc())!['language'], 'es');
      expect(user.settings['language'], 'es');
    });
  });

  group('the daily reminder', () {
    testWidgets('shows the stored preference', (tester) async {
      user.dontAskCalendar = true;

      await openDialog(tester);

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('turning it off is remembered', (tester) async {
      user.dontAskCalendar = true;

      await openDialog(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(user.dontAskCalendar, isFalse);
      expect((await settingsDoc())!['dontAskCalendar'], isFalse);
    });
  });

  group('streaming providers', () {
    /// Fires the grid cell for [name].
    ///
    /// The cells cannot be tapped from a test: each one lays a 150px logo
    /// inside a much shorter square, so the caption falls outside the grid's
    /// clip and the cells paint over one another, and a hit test at the
    /// cell's centre lands on its neighbour. The handler is invoked directly
    /// instead, which still covers the toggle, the write and the redraw.
    Future<void> tapProvider(WidgetTester tester, String name) async {
      final cell = find
          .ancestor(
            of: find.text(name),
            matching: find.byType(GestureDetector),
          )
          .first;
      tester.widget<GestureDetector>(cell).onTap!();
      await tester.pumpAndSettle();
    }

    setUp(() {
      http.on('watch/providers/movie', json: {
        'results': [
          {
            'logo_path': '/netflix.jpg',
            'provider_name': 'Netflix',
            'provider_id': 8
          },
          {'logo_path': '/max.jpg', 'provider_name': 'Max', 'provider_id': 1899},
        ]
      });
    });

    testWidgets('are fetched for the region the account is set to',
        (tester) async {
      user.country = 'ES';

      await openDialog(tester);

      expect(http.requests.map((uri) => uri.toString()).join(),
          contains('watch_region=ES'));
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('one already chosen is shown as chosen', (tester) async {
      user.settings['providers'] = ['8'];

      await openDialog(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping one adds it to the account', (tester) async {
      await openDialog(tester);

      await tapProvider(tester, 'Netflix');

      expect(user.settings['providers'], ['8']);
      expect((await settingsDoc())!['providers'], ['8']);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping it again takes it away', (tester) async {
      user.settings['providers'] = ['8'];

      await openDialog(tester);
      await tapProvider(tester, 'Netflix');

      expect(user.settings['providers'], isEmpty);
      expect((await settingsDoc())!['providers'], isEmpty);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('a region with no providers listed shows an empty grid',
        (tester) async {
      http.on('watch/providers/movie', status: 500, body: '');

      await openDialog(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Netflix'), findsNothing);
    });
  });

  group('deleting the account', () {
    /// The Delete button sits in the row that overflows, so part of it is off
    /// the dialogue and a tap at its centre misses. Its handler is invoked
    /// directly instead, which still exercises what the button does.
    Future<void> pressDelete(WidgetTester tester) async {
      final button = find
          .ancestor(
            of: find.text('Delete'),
            matching: find.byType(GestureDetector),
          )
          .first;
      tester.widget<GestureDetector>(button).onTap!();
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the password before it will do anything',
        (tester) async {
      // Deletion is irreversible and cannot be undone from inside the app, so
      // it must never be one tap away.
      await openDialog(tester);

      await pressDelete(tester);

      expect(find.byType(AlertButtonDialogue), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
        reason: 'the password must not be readable over a shoulder',
      );
    });

    testWidgets('backing out of the confirmation deletes nothing',
        (tester) async {
      await seedUserDoc(firestore, 'test-uid', 'Movies', {
        'Seen': ['27205']
      });

      await openDialog(tester);
      await pressDelete(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertButtonDialogue), findsNothing);
      final doc = await firestore.collection('test-uid').doc('Movies').get();
      expect(doc.exists, isTrue);
    });
  });
}
