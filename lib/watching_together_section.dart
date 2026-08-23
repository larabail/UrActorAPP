import 'dart:convert';

import 'package:flutter/material.dart';

import 'common/api/http_client.dart';
import 'common/constants.dart';
import 'common/continue_watching.dart';
import 'common/firebase/progress_service.dart';
import 'common/item_container.dart';
import 'common/layout/responsive.dart';
import 'common/layout/two_pane.dart';
import 'common/media_pair_membership.dart';
import 'common/watch_progress_view.dart';
import 'common/watch_progress_widgets.dart';
import 'common/watching_together.dart';
import 'l10n/l10n.dart';
import 'main.dart';
import 'objects/tv_show.dart';
import 'tvshow_result.dart';

/// One resolved tile: the shared show, what TMDB says about it, and where to
/// pick it back up.
class WatchingTogetherTile {
  const WatchingTogetherTile({
    required this.show,
    required this.media,
    this.resume = const ResumePoint.unknown(),
  });

  final WatchingTogetherShow show;
  final ContinueWatchingMedia media;

  /// Always unknown for a show whose seasons could not be read.
  final ResumePoint resume;
}

/// The Watching together row on a friend's profile.
///
/// Shows the series that are started, unfinished, and recorded as watched with
/// this friend — the ones people lose track of between episodes — most recent
/// activity first, with the episode to play next written under each.
///
/// It draws posters because a profile is a page someone opened in order to
/// browse. The friends list says the same thing as one scrolling line of
/// titles under each name instead: there the point is to scan the friends, and
/// a row of artwork per friend would bury them.
///
/// The section removes itself when there is nothing shared and unfinished
/// rather than drawing a heading over an empty strip.
class WatchingTogetherSection extends StatefulWidget {
  const WatchingTogetherSection.forFriend(this.friendUid, {super.key});

  /// The friend whose shared shows this draws.
  final String friendUid;

  @override
  State<WatchingTogetherSection> createState() =>
      _WatchingTogetherSectionState();
}

class _WatchingTogetherSectionState extends State<WatchingTogetherSection> {
  late Future<List<WatchingTogetherShow>> _shows;

  /// One future per show, kept so a rebuild — a scroll, a locale change, the
  /// parent's `setState` — reuses the answer instead of asking TMDB again.
  final Map<String, Future<WatchingTogetherTile>> _tiles =
      <String, Future<WatchingTogetherTile>>{};

  @override
  void initState() {
    super.initState();
    _shows = _loadShows();
  }

  @override
  void didUpdateWidget(WatchingTogetherSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendUid != widget.friendUid) {
      _tiles.clear();
      _shows = _loadShows();
    }
  }

  /// A progress document that cannot be read is treated as nothing shared. The
  /// alternative is an error state on a profile for a section that is optional
  /// to begin with.
  Future<List<WatchingTogetherShow>> _loadShows() async {
    try {
      return watchingTogetherShows(
        await ProgressService.inProgressItems(),
        currentUser.seenWith,
        friends: <String>[widget.friendUid],
      );
    } catch (_) {
      return const <WatchingTogetherShow>[];
    }
  }

  Future<WatchingTogetherTile> _tileFor(WatchingTogetherShow show) {
    return _tiles.putIfAbsent(show.id, () async {
      final media = await _fetchShow(show.id);
      var resume = const ResumePoint.unknown();
      if (media.seasons.isNotEmpty) {
        try {
          resume = WatchProgressView.resumeFrom(
            seasons: media.seasons,
            watched: await ProgressService.watchedEpisodesBySeason(show.id),
          );
        } catch (_) {
          resume = const ResumePoint.unknown();
        }
      }
      return WatchingTogetherTile(show: show, media: media, resume: resume);
    });
  }

  /// Fetches the TMDB detail for one show, and never throws.
  ///
  /// The show payload carries its season list, so this single request covers
  /// both the artwork and the season counts the resume point needs.
  Future<ContinueWatchingMedia> _fetchShow(String id) async {
    try {
      final response =
          await AppHttp.client.get(Uri.parse('$TV_SHOW_LINK$id$API_KEY'));
      if (response.statusCode != 200) {
        return ContinueWatchingMedia.missing(progressTVShowsKey, id);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return ContinueWatchingMedia.missing(progressTVShowsKey, id);
      }
      return ContinueWatchingMedia.fromTmdb(progressTVShowsKey, id, decoded);
    } catch (_) {
      return ContinueWatchingMedia.missing(progressTVShowsKey, id);
    }
  }

  void _openDetails(ContinueWatchingMedia media, String title) {
    openDetail(
      context,
      TVShowResult(
        tvshow: TVShow(
          id: media.id,
          title: title,
          coverPhoto: media.posterPath ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WatchingTogetherShow>>(
      future: _shows,
      builder: (context, snapshot) {
        final shows = snapshot.data ?? const <WatchingTogetherShow>[];
        // Also covers the still-loading case, so the page does not shift under
        // a heading that may turn out to have nothing beneath it.
        if (shows.isEmpty) return const SizedBox.shrink();
        return _buildSection(context, shows);
      },
    );
  }

  Widget _buildSection(BuildContext context, List<WatchingTogetherShow> shows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(5.0),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups),
              const SizedBox(width: 10),
              Text(
                S.of(context)!.watchingTogether,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: posterRowHeight(context) + kResumeCaptionHeight,
            // Builds lazily, so the titles scrolled past never cost a request.
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: shows.length,
              itemBuilder: (context, index) =>
                  _buildTile(context, shows[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, WatchingTogetherShow show) {
    return FutureBuilder<WatchingTogetherTile>(
      future: _tileFor(show),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const PosterPlaceholder(child: CircularProgressIndicator());
        }
        final tile = snapshot.data!;
        final media = tile.media;
        final title = media.title ?? S.of(context)!.unknown;
        final itemData = media.itemData(title);

        return GestureDetector(
          key: ValueKey('watchingTogether-${show.id}'),
          onTap: media.missing ? null : () => _openDetails(media, title),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The type is known to be a show, so the pair is stated rather
              // than inferred from the item map: a title TMDB would not resolve
              // renders through `ContinueWatchingMedia.missing`, where there is
              // no name left to infer from. Such a tile still gets its badges —
              // it is no longer reachable, but whether it is a favorite or on
              // the watchlist remains true and is the more useful thing to say.
              getItemContainer(
                context,
                itemData,
                'media',
                mediaPair: mediaPairForData(
                  itemData,
                  containerType: progressTVShowsKey,
                ),
              ),
              ResumeCaption(tile.resume),
            ],
          ),
        );
      },
    );
  }
}
