import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../movie_result.dart';
import '../objects/media.dart';
import '../objects/movie.dart';
import '../objects/tv_show.dart';
import '../tvshow_result.dart';
import 'item_container.dart';
import 'layout/responsive.dart';
import 'media_pair_membership.dart';

/// One of the home page's list previews: watchlist, favourites or seen.
///
/// Lifted out of `main.dart` so the badge rules below can be tested. While it
/// lived inside the home page's State there was no way to build it without the
/// whole page, and the page needs a signed-in user and a live Firestore.
class HomeMediaSection extends StatelessWidget {
  const HomeMediaSection({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.page,
    this.showFavoriteBadge = true,
    this.showWatchlistBadge = true,
  });

  /// The watchlist preview: no bookmark, because every tile here has one.
  const HomeMediaSection.watchlist({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.page,
  })  : showFavoriteBadge = true,
        showWatchlistBadge = false;

  /// The favourites preview: no heart, for the mirror of the reason above.
  const HomeMediaSection.favorites({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.page,
  })  : showFavoriteBadge = false,
        showWatchlistBadge = true;

  /// The seen preview, which keeps both. This is the case that shows the rule
  /// is about the section and not a blanket suppression: a seen title may or
  /// may not be a favourite, and may or may not still be on the watchlist.
  const HomeMediaSection.seen({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.page,
  })  : showFavoriteBadge = true,
        showWatchlistBadge = true;

  /// The section heading, and the name the "see all" count is attached to.
  final String title;

  /// The `[type, id]` pairs this section previews, newest last.
  final List<dynamic> content;

  final IconData icon;

  /// The full page this section previews, pushed when "see all" is tapped.
  final Widget page;

  /// Whether a favourite heart says anything here.
  ///
  /// False on the favourites section, where every tile is a favourite by
  /// definition, so the badge marks all of them and distinguishes none. The
  /// watchlist bookmark still earns its place there, because a favourite may
  /// or may not also be on the watchlist.
  final bool showFavoriteBadge;

  /// Whether a watchlist bookmark says anything here. False on the watchlist
  /// section, for the mirror of the reason above.
  final bool showWatchlistBadge;

  /// At most this many tiles are previewed before "see all" takes over.
  static const int previewLimit = 10;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> preview = content.reversed
        .take(previewLimit)
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(5.0),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(
                S.of(context)!.yourSection(title),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => page),
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      S.of(context)!.seeAll(content.length),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (preview.isEmpty) Text(S.of(context)!.emptySection),
          if (preview.isEmpty) const SizedBox(height: 10),
          if (preview.isNotEmpty)
            SizedBox(
              height: posterRowHeight(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: preview.length,
                itemBuilder: (context, index) {
                  final entry = preview[index];
                  final MediaItem tempMedia = entry[0] == "Movies"
                      ? Movie(
                          id: entry[1],
                          title: "title",
                          coverPhoto: "coverPhoto",
                        )
                      : TVShow(
                          id: entry[1],
                          title: "title",
                          coverPhoto: "coverPhoto",
                        );

                  return FutureBuilder<Map>(
                    future: tempMedia.getData(),
                    builder:
                        (BuildContext context, AsyncSnapshot<Map> snapshot) {
                      if (snapshot.hasData) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => entry[0] == "Movies"
                                    ? MovieResult(movie: tempMedia as Movie)
                                    : TVShowResult(tvshow: tempMedia as TVShow),
                              ),
                            );
                          },
                          child: getItemContainer(
                            context,
                            snapshot.data,
                            "media",
                            mediaPair: mediaPairForData(snapshot.data),
                            showFavoriteBadge: showFavoriteBadge,
                            showWatchlistBadge: showWatchlistBadge,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(S.of(context)!.errorFailedToLoadDetails),
                        );
                      } else {
                        return const PosterPlaceholder(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
