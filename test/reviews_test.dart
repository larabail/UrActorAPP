import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/reviews.dart';

import 'support/harness.dart';

void main() {
  late HttpStub http;

  setUp(() {
    final user = installTestUser();
    user.settings['profile_photo'] = '';
    http = installHttpStub();
  });

  Future<void> pumpReviews(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Reviews(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a review whose media id 404s keeps its text readable',
      (tester) async {
    app.currentUser.reviews = {
      '404': {'Opinion': 'My saved review', 'Rating': '4'}
    };
    http.on('/3/movie/404', status: 404, body: '');

    await pumpReviews(tester);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('My saved review'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(http.countFor('/3/movie/404'), 1);
    expect(http.countFor('/3/tv/404'), 0);
  });

  testWidgets('a media item with a null poster_path uses the placeholder',
      (tester) async {
    app.currentUser.reviews = {
      '1': {'Opinion': 'No poster review', 'Rating': '3'}
    };
    http.on('/3/movie/1', json: {
      'title': 'Posterless Movie',
      'poster_path': null,
      'id': 1,
    });

    await pumpReviews(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Posterless Movie'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final image = decoration.image?.image;
      return image != null && (image as dynamic).url == UNKNOWN_COVER;
    }), findsOneWidget);
  });

  testWidgets('a normal review still renders its title and review text',
      (tester) async {
    app.currentUser.reviews = {
      '27205': {'Opinion': 'Dreams within dreams', 'Rating': '5'}
    };
    http.on('/3/movie/27205', json: {
      'title': 'Inception',
      'poster_path': '/inception.jpg',
      'id': 27205,
    });

    await pumpReviews(tester);

    expect(tester.takeException(), isNull);
    expect(http.countFor('/3/movie/27205'), 1);
    expect(find.text('Inception'), findsOneWidget);

    await tester.tap(find.text('Inception'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dreams within dreams'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final image = decoration.image?.image;
      return image != null &&
          (image as dynamic).url == '$IMG_LINK/inception.jpg';
    }), findsOneWidget);
  });
}
