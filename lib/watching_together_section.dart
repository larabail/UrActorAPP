import 'dart:convert';

import 'package:flutter/material.dart';

import 'common/api/http_client.dart';
import 'common/constants.dart';
import 'common/continue_watching.dart';
import 'common/firebase/friends_service.dart';
import 'common/firebase/progress_service.dart';
import 'common/item_container.dart';
import 'common/layout/responsive.dart';
import 'common/layout/two_pane.dart';
import 'common/media_pair_membership.dart';
import 'common/watching_together.dart';
import 'l10n/l10n.dart';
import 'main.dart';
import 'objects/tv_show.dart';
import 'tvshow_result.dart';

/// The room a tile's caption is given under it.
///
/// Matches Continue watching, so the two rows line up when a screen shows
/// both. Two lines is enough for either the episode pointer or a pair of
/// friends' names at this size, and the caption is clipped rather than allowed
/// to push the row taller than it was told to be.
const double _kCaptionHeight = 38;

/// One resolved tile: the shared show, what TMDB says about it, and where to
/// pick it back up.
class WatchingTogetherTile {
  const WatchingTogetherTile({
    required this.show,
    required this.media,
    this.nextEpisode,
  });

  final WatchingTogetherShow show;
  final ContinueWatchingMedia media;

  /// Null for a show whose seasons could not be read.
  final WatchProgressEpisode? nextEpisode;
}

/// The Watching together row.
///
/// Shows the series that are started, unfinished, and recorded as watched with
/// a friend — the ones people lose track of between episodes — most recent
/// activity first, with the episode to play next written under each.
///
/// The section removes itself when there is nothing shared and unfinished
/// rather than drawing a heading over an empty strip. The friends page is
/// otherwise a plain list, and a permanent blank row on it would be a standing
/// advertisement for a feature the user may never use.
class WatchingTogetherSection extends StatefulWidget {
  const WatchingTogetherSection({
    super.key,
    this.friendUids,
    this.showFriendNames = true,
  });

  /// The section as it appears on one friend's own profile.
  ///
  /// Scoped to them, and without the "With ..." caption: the page already says
  /// whose it is, so repeating the name under every poster says nothing. This
  /// is a separate constructor rather than inferred from a single uid, because
  /// a user with exactly one friend is still on the friends page and still
  /// wants to be told who a show is shared with.
  WatchingTogetherSection.forFriend(String friendUid, {super.key})
      : friendUids = <String>[friendUid],
        showFriendNames = false;

  /// Which friends to draw shared shows for. Null means every friend, in the
  /// order the user arranged their friends list in.
  final List<String>? friendUids;

  /// Whether a tile says who the show is being watched with.
  final bool showFriendNames;

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

  /// Resolved once for the whole row, because several shared shows usually
  /// mean the same one or two friends and a lookup per tile would read the
  /// same Settings documents over and over.
  late Future<Map<String, String>> _names;

  @override
  void initState() {
    super.initState();
    _shows = _loadShows();
    _names = _loadNames();
  }

  @override
  void didUpdateWidget(WatchingTogetherSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameFriends(oldWidget.friendUids, widget.friendUids)) {
      _tiles.clear();
      _shows = _loadShows();
      _names = _loadNames();
    }
  }

  List<dynamic> get _friends => widget.friendUids ?? currentUser.friends;

  /// A progress document that cannot be read is treated as nothing shared. The
  /// alternative is an error state on the friends page for a section that is
  /// optional to begin with.
  Future<List<WatchingTogetherShow>> _loadShows() async {
    final friends = List<dynamic>.from(_friends);
    if (friends.isEmpty) return const <WatchingTogetherShow>[];
    try {
      return watchingTogetherShows(
        await ProgressService.inProgressItems(),
        currentUser.seenWith,
        friends: friends,
      );
    } catch (_) {
      return const <WatchingTogetherShow>[];
    }
  }

  /// Display names for the friends in scope, keyed by uid.
  ///
  /// A friend whose profile cannot be read has no name to write, and is left
  /// out of the map so the caption falls back to naming the others rather than
  /// showing a blank where a name should be.
  Future<Map<String, String>> _loadNames() async {
    // A surface that does not caption its tiles has no use for the names, and
    // reading a Settings document per friend to throw them away is a cost the
    // friend profile page should not pay.
    if (!widget.showFriendNames) return const <String, String>{};
    final friends = List<dynamic>.from(_friends);
    if (friends.isEmpty) return const <String, String>{};
    try {
      final profiles = await FriendsService.loadProfiles(friends);
      return <String, String>{
        for (final FriendProfileSummary profile in profiles)
          if (profile.userName.trim().isNotEmpty)
            profile.uid: profile.userName,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<WatchingTogetherTile> _tileFor(WatchingTogetherShow show) {
    return _tiles.putIfAbsent(show.id, () async {
      final media = await _fetchShow(show.id);
      WatchProgressEpisode? next;
      if (media.seasons.isNotEmpty) {
        try {
          next = await ProgressService.nextUnwatchedEpisode(
            show.id,
            media.seasons,
          );
        } catch (_) {
          next = null;
        }
      }
      return WatchingTogetherTile(show: show, media: media, nextEpisode: next);
    });
  }

  /// Fetches the TMDB detail for one show, and never throws.
  ///
  /// The show payload carries its season list, so this single request covers
  /// both the artwork and the season counts `nextUnwatchedEpisode` needs.
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

  /// The line naming who a show is shared with, or null when there is nobody
  /// left to name — an unreadable profile, or a surface that has already said
  /// whose shows these are.
  String? _withCaption(
    BuildContext context,
    WatchingTogetherShow show,
    Map<String, String> names,
  ) {
    if (!widget.showFriendNames) return null;
    final resolved = watchingTogetherNames(
      [
        for (final uid in show.friendUids)
          if (names[uid] != null) names[uid]!,
      ],
    );
    if (resolved.shown.isEmpty) return null;
    final joined = resolved.shown.join(', ');
    return resolved.othersCount == 0
        ? S.of(context)!.watchingWith(joined)
        : S.of(context)!.watchingWithMore(joined, resolved.othersCount);
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
            height: posterRowHeight(context) + _kCaptionHeight,
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
        final next = tile.nextEpisode;

        return FutureBuilder<Map<String, String>>(
          future: _names,
          builder: (context, namesSnapshot) {
            final withLine = _withCaption(
              context,
              show,
              namesSnapshot.data ?? const <String, String>{},
            );
            // Two lines at most, which is what the caption box is sized for:
            // where to resume, and who with. Both are worth saying — the point
            // of the row is that these are the shows someone else is waiting
            // on — and neither is worth a taller row than Continue watching.
            final lines = <String>[
              if (next != null)
                S.of(context)!.nextEpisode(
                      next.seasonNumber,
                      next.episodeNumber,
                    ),
              if (withLine != null) withLine,
            ];

            return GestureDetector(
              key: ValueKey('watchingTogether-${show.id}'),
              onTap: media.missing ? null : () => _openDetails(media, title),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The type is known to be a show, so the pair is stated
                  // rather than inferred from the item map: a title TMDB would
                  // not resolve renders through `ContinueWatchingMedia.missing`,
                  // where there is no name left to infer from. Such a tile
                  // still gets its badges — it is no longer reachable, but
                  // whether it is a favorite or on the watchlist remains true
                  // and is the more useful thing to say.
                  getItemContainer(
                    context,
                    itemData,
                    'media',
                    mediaPair: mediaPairForData(
                      itemData,
                      containerType: progressTVShowsKey,
                    ),
                  ),
                  if (lines.isNotEmpty)
                    SizedBox(
                      height: _kCaptionHeight,
                      child: Text(
                        lines.join('\n'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

bool _sameFriends(List<String>? a, List<String>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
