import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/calendar_episode_badge.dart';
import 'package:uractor/l10n/l10n.dart';

Future<void> _pump(WidgetTester tester, Map entry, {Locale? locale}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: CalendarEpisodeBadge(entry: entry)),
    ),
  );
}

void main() {
  testWidgets('shows the season and episode an entry recorded', (tester) async {
    await _pump(tester, {'name': 'Thrones', 'season': 2, 'episode': 9});

    expect(find.text('S2 E9'), findsOneWidget);
  });

  testWidgets('shows the season alone when no episode was recorded',
      (tester) async {
    await _pump(tester, {'name': 'Thrones', 'season': 3});

    expect(find.text('S3'), findsOneWidget);
  });

  testWidgets('renders nothing for an entry that recorded nothing',
      (tester) async {
    // The shape of every entry in the wild today, and of everything a friend
    // running an older build writes. It has to look untouched.
    await _pump(tester, {'title': 'Inception', 'id': 27205});

    expect(find.byKey(const ValueKey('calendarEpisodeBadge')), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders nothing for a season that is not a part number',
      (tester) async {
    await _pump(tester, {'name': 'Thrones', 'season': 0, 'episode': 4});

    expect(find.byKey(const ValueKey('calendarEpisodeBadge')), findsNothing);
  });

  testWidgets('translates the badge', (tester) async {
    // Spanish abbreviates temporada, so the badge is not the same string with
    // the numbers swapped in -- a hardcoded "S" would be wrong there.
    await _pump(
      tester,
      {'name': 'Thrones', 'season': 2, 'episode': 9},
      locale: const Locale('es'),
    );

    expect(find.text('T2 E9'), findsOneWidget);
  });
}
