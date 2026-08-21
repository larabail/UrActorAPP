import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'calendar_episode.dart';

/// The season and episode a calendar entry recorded, shown under its poster.
///
/// Renders nothing at all when the entry recorded none, which is every entry
/// written before this feature existed and every entry a friend on an older
/// build writes. Those days have to keep looking exactly as they did, so the
/// absent case is a zero-size widget rather than an empty line or a dash.
class CalendarEpisodeBadge extends StatelessWidget {
  const CalendarEpisodeBadge({super.key, required this.entry});

  /// The entry as it reaches the screen: the TMDB payload with whatever the
  /// stored calendar entry recorded carried onto it.
  final Map entry;

  @override
  Widget build(BuildContext context) {
    final CalendarEpisode? episode = CalendarEpisode.fromEntry(entry);
    if (episode == null) return const SizedBox.shrink();
    final String label = episode.hasEpisode
        ? S.of(context)!.calendarSeasonEpisodeBadge(
              episode.season,
              episode.episode!,
            )
        : S.of(context)!.calendarSeasonBadge(episode.season);
    return Padding(
      key: const ValueKey('calendarEpisodeBadge'),
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
