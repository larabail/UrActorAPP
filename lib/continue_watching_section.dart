import 'dart:convert';

import 'package:flutter/material.dart';

import 'common/api/http_client.dart';
import 'common/constants.dart';
import 'common/continue_watching.dart';
import 'common/firebase/progress_service.dart';
import 'common/item_container.dart';
import 'common/media_pair_membership.dart';
import 'common/watch_progress_view.dart';
import 'common/watch_progress_widgets.dart';
import 'l10n/l10n.dart';
import 'movie_result.dart';
import 'objects/movie.dart';
import 'objects/tv_show.dart';
import 'tvshow_result.dart';
import 'common/layout/responsive.dart';
import 'common/layout/two_pane.dart';

/// One resolved row: the progress entry, what TMDB says about it, and where to
/// pick the show back up.
class ContinueWatchingTile {
  const ContinueWatchingTile({
    required this.item,
    required this.media,
    this.resume = const ResumePoint.unknown(),
  });

  final WatchProgressListItem item;
  final ContinueWatchingMedia media;

  /// Always unknown for movies, and for a show whose seasons could not be read.
  final ResumePoint resume;
}

/// The home page's Continue watching row.
///
/// Shows what has been started and not finished, most recent activity first,
/// with the episode to play next written under each show.
///
/// The section removes itself when there is nothing to resume rather than
/// drawing a heading over an empty strip: a user who has never used progress
/// tracking should not be told about it by a permanent blank row, and the home
/// page already has three sections that say "Nothing here yet".
class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({super.key});

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  late final Future<List<WatchProgressListItem>> _items;

  /// One future per title, kept so a rebuild — a scroll, a locale change, the
  /// parent's `setState` — reuses the answer instead of asking TMDB again.
  final Map<String, Future<ContinueWatchingTile>> _tiles =
      <String, Future<ContinueWatchingTile>>{};

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
  }

  /// A progress document that cannot be read is treated as nothing to resume.
  /// The alternative is an error state on the home page for a section that is
  /// optional to begin with.
  Future<List<WatchProgressListItem>> _loadItems() async {
    try {
      return continueWatchingEntries(await ProgressService.inProgressItems());
    } catch (_) {
      return const <WatchProgressListItem>[];
    }
  }

  Future<ContinueWatchingTile> _tileFor(WatchProgressListItem item) {
    return _tiles.putIfAbsent('${item.type}:${item.id}', () async {
      final media = await _fetchMedia(item.type, item.id);
      var resume = const ResumePoint.unknown();
      if (media.isShow && media.seasons.isNotEmpty) {
        try {
          resume = WatchProgressView.resumeFrom(
            seasons: media.seasons,
            watched: await ProgressService.watchedEpisodesBySeason(item.id),
          );
        } catch (_) {
          resume = const ResumePoint.unknown();
        }
      }
      return ContinueWatchingTile(item: item, media: media, resume: resume);
    });
  }

  /// Fetches the TMDB detail for one title, and never throws.
  ///
  /// The show payload carries its season list, so this single request covers
  /// both the artwork and the season counts the resume point needs.
  Future<ContinueWatchingMedia> _fetchMedia(String type, String id) async {
    final link = type == progressTVShowsKey ? TV_SHOW_LINK : MOVIE_LINK;
    try {
      final response = await AppHttp.client.get(Uri.parse('$link$id$API_KEY'));
      if (response.statusCode != 200) {
        return ContinueWatchingMedia.missing(type, id);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return ContinueWatchingMedia.missing(type, id);
      return ContinueWatchingMedia.fromTmdb(type, id, decoded);
    } catch (_) {
      return ContinueWatchingMedia.missing(type, id);
    }
  }

  void _openDetails(ContinueWatchingMedia media, String title) {
    final cover = media.posterPath ?? '';
    openDetail(
        context,
        media.isShow
            ? TVShowResult(
                tvshow: TVShow(id: media.id, title: title, coverPhoto: cover),
              )
            : MovieResult(
                movie: Movie(id: media.id, title: title, coverPhoto: cover),
              ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WatchProgressListItem>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <WatchProgressListItem>[];
        // Also covers the still-loading case, so the home page does not shift
        // under a heading that may turn out to have nothing beneath it.
        if (items.isEmpty) return const SizedBox.shrink();
        return _buildSection(context, items);
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    List<WatchProgressListItem> items,
  ) {
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
              const Icon(Icons.play_circle_outline),
              const SizedBox(width: 10),
              Text(
                S.of(context)!.continueWatching,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            // Sized from the tile rather than from the window. A fraction of
            // the window height was only ever the height of a row of posters
            // on a phone held upright; on a short window it clipped the tiles
            // and on a tall one it left a band of dead space beneath them.
            height: posterRowHeight(context) + kResumeCaptionHeight,
            // Builds lazily, so the titles scrolled past never cost a request.
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildTile(context, items[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, WatchProgressListItem item) {
    return FutureBuilder<ContinueWatchingTile>(
      future: _tileFor(item),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPlaceholder(context);
        final tile = snapshot.data!;
        final media = tile.media;
        final title = media.title ?? S.of(context)!.unknown;
        final itemData = media.itemData(title);

        return GestureDetector(
          key: ValueKey('continueWatching-${item.type}-${item.id}'),
          onTap: media.missing ? null : () => _openDetails(media, title),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The progress entry already knows the type, so the pair is
              // taken from it rather than inferred from the item map: a title
              // TMDB would not resolve renders through
              // `ContinueWatchingMedia.missing`, where there is no name to
              // infer from. Such a tile still gets its badges — it is no
              // longer reachable, but whether it is a favorite or on the
              // watchlist remains true and is the more useful thing to say.
              getItemContainer(
                context,
                itemData,
                'media',
                mediaPair: mediaPairForData(
                  itemData,
                  containerType: item.type,
                ),
              ),
              ResumeCaption(tile.resume),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return const PosterPlaceholder(child: CircularProgressIndicator());
  }
}
