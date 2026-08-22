import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/calendar.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart';

import 'support/harness.dart';

/// The calendar page laying out in the space it is actually given.
///
/// Two boxes on this page were sized as a fraction of the window: the month
/// grid at 57% of its height, and the sheet a day opens at 37.5%. Both hold
/// content with a height of its own -- a grid is a header, a day-of-week strip
/// and four to six week rows; the sheet is a row of cards as tall as a poster,
/// an episode badge and a delete button -- and neither fraction is that
/// height. The app bar and, on a desktop window, the navigation rail take
/// their share of the window before the page sees any of it.
///
/// Every case here asserts on [WidgetTester.takeException], because that is
/// how the failure showed up: a `RenderFlex` overflow is reported as a
/// `FlutterError` and the frame is still painted, so a test that only looked
/// at what was on screen would pass while the app drew warning stripes.
///
/// The windows below are all at least 560 wide, deliberately. At the 400 the
/// harness usually gives, the row of monthly stats overflows *horizontally* --
/// a separate defect, and one largely produced by the test font, whose glyphs
/// are a full em wide where a real one's are about half that. Pumping at 400
/// would fail these tests for a reason that has nothing to do with the height
/// they are about.

/// Pumps the calendar into a window [size] logical pixels across.
Future<void> _pumpCalendar(WidgetTester tester, Size size) async {
  usePhoneSurface(tester, size: size);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: const Calendar(),
    ),
  );
  await tester.pumpAndSettle();
}

/// How many week rows the month on screen is drawing.
///
/// The grid is a [Table] whose rows are the day-of-week strip followed by one
/// per week, and `table_calendar` does not export the widget that builds it.
/// Counting the rows it produced is the closest a test can get to the number
/// that decides how tall the calendar has to be.
int _weekRows(WidgetTester tester) {
  final tables = tester.widgetList<Table>(find.byType(Table));
  expect(tables, hasLength(1), reason: 'expected exactly one month grid');
  return tables.single.children.length - 1;
}

/// Steps the calendar forward a month and settles the resize animation.
Future<void> _nextMonth(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right));
  await tester.pumpAndSettle();
}

/// The 15th of the month the calendar opens on.
///
/// The grid pads the month out with the end of the previous one and the start
/// of the next, so a day number near either edge can appear twice. The middle
/// of the month never can: the leading days are always the twenties or later
/// and the trailing days never reach a fortnight.
DateTime _midMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 15);
}

/// Puts one film on [day], as the day sheet needs something to show.
///
/// The stats the page works out on build read `runtime` and `rating` off the
/// stored entry without a null check, and the sheet re-fetches the title from
/// TMDB before drawing it, so both the entry and the response have to be here.
void _seedOneFilmOn(DateTime day) {
  currentUser.calendar = {
    day.toIso8601String().split('T')[0]: [
      {
        'id': '603',
        'title': 'The Matrix',
        'type': 'movie',
        'runtime': 136,
        'rating': 8.2,
      }
    ]
  };
}

void main() {
  late HttpStub http;

  setUp(() {
    installTestUser();
    installFakeFirestore();
    http = installHttpStub();
    http.on('movie/', json: {
      'id': 603,
      'title': 'The Matrix',
      'poster_path': null,
      'runtime': 136,
      'vote_average': 8.2,
    });
  });

  // A phone, where navigation is a bottom bar. 57% of 600 is 342, and the grid
  // needs more than that whatever the month.
  testWidgets('lays out on a short phone window', (tester) async {
    await _pumpCalendar(tester, const Size(560, 600));

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a tall phone window', (tester) async {
    await _pumpCalendar(tester, const Size(560, 1000));

    expect(tester.takeException(), isNull);
  });

  // The shape the overflow was reported in: a desktop window, where the rail
  // spends width but the fraction is still taken from the full height.
  testWidgets('lays out in a desktop window with a navigation rail',
      (tester) async {
    await _pumpCalendar(tester, const Size(1280, 640));

    expect(tester.takeException(), isNull);
  });

  // Six week rows is the worst case, and the one actually reported -- at 640
  // tall a five row month fitted the old box and a six row month did not,
  // which is what made the bug look intermittent. Which months need six
  // depends on the day the suite runs, so this walks a year forward rather
  // than naming one, and fails if it never met a six row month: a green run
  // that quietly skipped the case would be worse than a red one.
  testWidgets('lays out every month of the coming year, six week rows included',
      (tester) async {
    await _pumpCalendar(tester, const Size(1280, 640));
    expect(tester.takeException(), isNull);

    var sawSixRows = _weekRows(tester) == 6;
    for (var month = 1; month <= 12; month++) {
      await _nextMonth(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflowed $month month(s) on from today');
      sawSixRows = sawSixRows || _weekRows(tester) == 6;
    }

    expect(sawSixRows, isTrue,
        reason: 'no month in the coming year needed six week rows');
  });

  // The stats are what was being pushed off the bottom, so reaching them is
  // the user-visible half of this. On a window too short for the grid and the
  // stats together they are below the fold, which is what the scroll view they
  // were always inside is for.
  testWidgets('the monthly stats can be scrolled to on a short window',
      (tester) async {
    await _pumpCalendar(tester, const Size(560, 600));

    await tester.scrollUntilVisible(
      find.byIcon(Icons.timer),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.movie).hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.timer).hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.star).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the day sheet lays out on a short window', (tester) async {
    final day = _midMonth();
    _seedOneFilmOn(day);
    ignoreNetworkImageFailures();

    await _pumpCalendar(tester, const Size(560, 600));
    expect(find.text('${day.day}'), findsOneWidget);
    await tester.tap(find.text('${day.day}'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The other half of the same claim: the sheet is as tall as what is in it,
  // so the window can change size underneath it without changing the answer.
  // It used to be 37.5% of whatever the window was -- too little to draw a
  // card on a short window, and a band of empty sheet under one on a tall.
  testWidgets('the day sheet is sized by its contents, not by the window',
      (tester) async {
    final day = _midMonth();
    _seedOneFilmOn(day);
    ignoreNetworkImageFailures();

    await _pumpCalendar(tester, const Size(560, 600));
    await tester.tap(find.text('${day.day}'));
    await tester.pumpAndSettle();
    final double onShortWindow = tester.getSize(find.byType(BottomSheet)).height;

    tester.view.physicalSize = const Size(560, 1000);
    await tester.pumpAndSettle();
    final double onTallWindow = tester.getSize(find.byType(BottomSheet)).height;

    expect(onTallWindow, onShortWindow);
    expect(tester.takeException(), isNull);
  });
}

