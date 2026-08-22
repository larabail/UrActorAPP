/// Tests for the viewing history date range label.
///
/// The requirement is that a show reads as "started – present" while it is
/// being watched and "started – finished" once it is done, instead of its
/// history vanishing the moment it moves out of Seen. The derivation is
/// covered in `viewing_history_range_test.dart`; this covers what a user
/// actually reads.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/viewing_history_widgets.dart';
import 'package:uractor/l10n/l10n.dart';

import 'support/harness.dart';

void main() {
  setUp(() {
    installTestUser(uid: 'history-user');
    installFakeFirestore();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget label, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a show being watched reads as open ended', (tester) async {
    await ProgressService.startShow('1396', date: DateTime(2026, 3, 1));

    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: false,
      ),
    );

    expect(find.textContaining('01 March, 2026'), findsOneWidget);
    expect(find.textContaining('present'), findsOneWidget);
  });

  testWidgets('a finished show reads as a closed range', (tester) async {
    await ProgressService.startShow('1396', date: DateTime(2026, 3, 1));
    await ProgressService.finishShow('1396', date: DateTime(2026, 4, 9));

    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: true,
      ),
    );

    expect(find.textContaining('01 March, 2026'), findsOneWidget);
    expect(find.textContaining('09 April, 2026'), findsOneWidget);
    expect(find.textContaining('present'), findsNothing);
  });

  testWidgets('an account with no progress document still gets its range',
      (tester) async {
    // Seen plus calendar entries and nothing under Progress: every account
    // that existed before watch progress shipped.
    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [
          ['2024-11-02', <String>[]],
          ['2024-09-18', <String>[]],
        ],
        seen: true,
      ),
    );

    expect(find.textContaining('18 September, 2024'), findsOneWidget);
    expect(find.textContaining('02 November, 2024'), findsOneWidget);
  });

  testWidgets('a show that left Seen keeps showing its logged days',
      (tester) async {
    // The regression: ticking an episode takes a show out of Seen, and the
    // calendar entries it was logged against are untouched by that.
    await ProgressService.markEpisodeWatched('1396', 1, 1, const [
      SeasonEpisodeCount(seasonNumber: 1, episodeCount: 7),
    ], date: DateTime(2026, 3, 1));

    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [
          ['2026-02-14', <String>[]],
        ],
        seen: false,
      ),
    );

    expect(find.textContaining('14 February, 2026'), findsOneWidget);
    expect(find.textContaining('present'), findsOneWidget);
  });

  testWidgets('renders nothing when nothing was ever recorded', (tester) async {
    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: false,
      ),
    );

    expect(find.byKey(const ValueKey('viewingHistoryRange')), findsNothing);
  });

  testWidgets('is localized', (tester) async {
    await ProgressService.startShow('1396', date: DateTime(2026, 3, 1));

    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: false,
      ),
      locale: const Locale('es'),
    );

    expect(find.textContaining('presente'), findsOneWidget);
    expect(find.textContaining('present,'), findsNothing);
  });

  testWidgets('rereads the record when the host bumps its token',
      (tester) async {
    await ProgressService.startShow('1396', date: DateTime(2026, 3, 1));

    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: false,
      ),
    );
    expect(find.textContaining('present'), findsOneWidget);

    await ProgressService.finishShow('1396', date: DateTime(2026, 4, 9));
    await pump(
      tester,
      const ViewingHistoryRangeLabel(
        type: progressTVShowsKey,
        id: '1396',
        seenDates: [],
        seen: true,
        refreshToken: 1,
      ),
    );

    expect(find.textContaining('09 April, 2026'), findsOneWidget);
    expect(find.textContaining('present'), findsNothing);
  });

  group('a film has no range', () {
    testWidgets('nothing is drawn even with a start and a finish recorded',
        (tester) async {
      await ProgressService.startMovie('27205', date: DateTime(2026, 3, 1));
      await ProgressService.finishMovie('27205', date: DateTime(2026, 3, 1));

      await pump(
        tester,
        const ViewingHistoryRangeLabel(
          type: progressMoviesKey,
          id: '27205',
          seenDates: [],
          seen: true,
        ),
      );

      expect(find.byKey(const ValueKey('viewingHistoryRange')), findsNothing);
      expect(find.textContaining('01 March, 2026'), findsNothing);
    });

    testWidgets('rewatches are not drawn as one viewing spanning years',
        (tester) async {
      // The case that made this wrong rather than merely redundant: two
      // separate viewings six years apart read as a single watch that took
      // six years. The days themselves are still listed as rows underneath.
      await pump(
        tester,
        const ViewingHistoryRangeLabel(
          type: progressMoviesKey,
          id: '27205',
          seenDates: [
            ['2020-01-03', <String>[]],
            ['2026-08-15', <String>[]],
          ],
          seen: true,
        ),
      );

      expect(find.byKey(const ValueKey('viewingHistoryRange')), findsNothing);
      expect(find.textContaining('2020'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('the same record on a show still reads as a range',
        (tester) async {
      // The control: the data is identical, so the type is doing the work and
      // the section has not simply been broken for everything.
      await pump(
        tester,
        const ViewingHistoryRangeLabel(
          type: progressTVShowsKey,
          id: '1396',
          seenDates: [
            ['2020-01-03', <String>[]],
            ['2026-08-15', <String>[]],
          ],
          seen: true,
        ),
      );

      expect(find.byKey(const ValueKey('viewingHistoryRange')), findsOneWidget);
      expect(find.textContaining('03 January, 2020'), findsOneWidget);
      expect(find.textContaining('15 August, 2026'), findsOneWidget);
    });

    test('the rule is stated where a screen can ask it', () {
      expect(ViewingHistoryRangeLabel.appliesTo(progressTVShowsKey), isTrue);
      expect(ViewingHistoryRangeLabel.appliesTo(progressMoviesKey), isFalse);
    });
  });
}
