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

  /// Opens the dialogue on a window of [size] at [textScale].
  ///
  /// The scale is injected through `MaterialApp.builder` rather than around
  /// `home`, because a dialogue is a route beside the home page rather than a
  /// widget inside it, so anything wrapped around `home` never reaches it.
  Future<void> openDialog(
    WidgetTester tester, {
    Size size = const Size(560, 1000),
    double textScale = 1.0,
  }) async {
    ignoreNetworkImageFailures();
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
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

  group('laying out', () {
    /// The panel the dialogue actually paints, as opposed to `Dialog` itself,
    /// which fills the screen and holds the inset.
    Finder panel() => find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;

    testWidgets(
        'takes the width the window offers rather than the framework '
        'minimum', (tester) async {
      // It used to wrap its column in SizedBox(width: 20). That does not make
      // anything 20pt wide: `Dialog` imposes a 280pt minimum, so the box was
      // clamped up to it and the dialogue rendered 280pt on every device,
      // discarding whatever else it was offered.
      await openDialog(tester);

      expect(
        tester.getSize(panel()).width,
        480.0,
        reason: 'a 560pt window leaves 480pt after the framework inset',
      );
    });

    testWidgets('stops widening once it is wide enough to read',
        (tester) async {
      await openDialog(tester, size: const Size(1200, 900));

      expect(
        tester.getSize(panel()).width,
        560.0,
        reason: 'a desktop window should not stretch the form across it',
      );
    });

    testWidgets(
        'keeps the account actions inside the panel at the text scale '
        "Android's font slider reaches", (tester) async {
      // At 1.1 the labels grow while the icons and paddings do not, so the row
      // used to overflow. A debug build draws a stripe over it; a release
      // build clips silently, which is how Logout and Delete were being cut
      // off with nobody able to report more than "the button is truncated".
      await openDialog(tester, size: const Size(360, 640), textScale: 1.3);

      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls its content in landscape instead of overflowing',
        (tester) async {
      // The column had no scroll view at all, so a short window overflowed it
      // vertically no matter what the text scale was.
      await openDialog(tester, size: const Size(900, 400));

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(InfoButtonDialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsWidgets,
      );
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

    testWidgets(
        'an account set to a country TMDB does not list falls back to '
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
          {
            'logo_path': '/max.jpg',
            'provider_name': 'Max',
            'provider_id': 1899
          },
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
    testWidgets('asks for the password before it will do anything',
        (tester) async {
      // Deletion is irreversible and cannot be undone from inside the app, so
      // it must never be one tap away.
      await openDialog(tester);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

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
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertButtonDialogue), findsNothing);
      final doc = await firestore.collection('test-uid').doc('Movies').get();
      expect(doc.exists, isTrue);
    });
  });
}
