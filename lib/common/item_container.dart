import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/l10n/l10n.dart';

import 'layout/breakpoints.dart';
import 'layout/responsive.dart';
import 'media_pair_membership.dart';
import 'user_media_lists.dart';

/// The shared media tile.
///
/// [mediaPair] is the `[type, id]` pair the tile stands for, as produced by
/// `mediaPairForData`. Handing it over opts the tile into the favourite and
/// watchlist badges, which are then resolved against the lists already held in
/// memory — no tile ever triggers a fetch of its own. Tiles that are not
/// tracked media (people, seasons) leave it null and get no badges.
///
/// [showFavoriteBadge] and [showWatchlistBadge] let a screen suppress a badge
/// that would say nothing there: every tile on the Favorites page is a
/// favourite, and every tile on the Watchlist page is on the watchlist.
///
/// [favoriteBadgeSemanticLabel] and [watchlistBadgeSemanticLabel] override the
/// resolution entirely, for callers that already know the answer.
///
/// The tile is a fixed 2:3 — the shape TMDB actually serves artwork in — and
/// takes its width in logical pixels from the size class of the space it is
/// drawn in. It used to take a fraction of the window in each axis instead,
/// which tied the tile's proportions to the *window's* proportions: correct on
/// a phone held upright, and increasingly wrong as the window got wider, up to
/// a tile four times too wide on a 1080p monitor.
///
/// [scale] multiplies the width for tiles that should read as larger than the
/// standard one, and [width] overrides it outright in logical pixels. Neither
/// affects the aspect ratio, which is not a matter of taste.
Widget getItemContainer(
  BuildContext context,
  dynamic item,
  String type, {
  double scale = 1.0,
  double? width,
  String? favoriteBadgeSemanticLabel,
  String? watchlistBadgeSemanticLabel,
  List<dynamic>? mediaPair,
  bool showFavoriteBadge = true,
  bool showWatchlistBadge = true,
}) {
  String imagePath = "";
  if (item!["poster_path"] != null) {
    imagePath = IMG_LINK + item!["poster_path"];
  } else if (item!["profile_path"] != null) {
    imagePath = IMG_LINK + item!["profile_path"];
  } else {
    if (type == "media") {
      imagePath = UNKNOWN_COVER;
    } else {
      imagePath = UNKNOWN_PERSON;
    }
  }

  final String? favoriteLabel = favoriteBadgeSemanticLabel ??
      (mediaPair != null &&
              shouldShowFavoriteBadge(
                showFavoriteBadge: showFavoriteBadge,
                favoriteItems: userFavoriteItemsFor(mediaPair),
                item: mediaPair,
              )
          ? S.of(context)!.favoriteBadge
          : null);

  final String? watchlistLabel = watchlistBadgeSemanticLabel ??
      (mediaPair != null &&
              shouldShowWatchlistBadge(
                showWatchlistBadge: showWatchlistBadge,
                watchlistItems: userWatchlistItemsFor(mediaPair),
                item: mediaPair,
              )
          ? S.of(context)!.watchlistBadge
          : null);

  final double tileWidth = width ?? context.posterWidth * scale;

  return Container(
    margin: const EdgeInsets.fromLTRB(
      kPosterTileMarginLeft,
      kPosterTileMarginTop,
      kPosterTileMarginRight,
      0,
    ),
    width: tileWidth,
    height: posterHeightFor(tileWidth),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: CachedNetworkImageProvider(imagePath),
              // The tile is already the shape of a poster, so covering it
              // fills the corners without distorting the artwork. Fitting to
              // the width instead left a gap whenever the two disagreed, which
              // on a wide window was most of the tile.
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (imagePath == UNKNOWN_COVER || imagePath == UNKNOWN_PERSON)
          Container(
            alignment: Alignment.center,
            child: Text(
              "${item!.containsKey("name") ? item!['name'] : item!['title']}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (favoriteLabel != null)
          Positioned(
            left: 10,
            bottom: 10,
            child: _badge(
              semanticLabel: favoriteLabel,
              icon: Icons.favorite,
              iconKey: const ValueKey('favoriteBadge'),
              color: const Color.fromARGB(248, 241, 105, 56),
            ),
          ),
        if (watchlistLabel != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: _badge(
              semanticLabel: watchlistLabel,
              icon: Icons.bookmark,
              iconKey: const ValueKey('watchlistBadge'),
              color: const Color.fromARGB(250, 224, 190, 78),
            ),
          ),
      ],
    ),
  );
}

Widget _badge({
  required String semanticLabel,
  required IconData icon,
  required Key iconKey,
  required Color color,
}) {
  return IgnorePointer(
    child: Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: Icon(
          icon,
          key: iconKey,
          color: color,
          size: 18,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The same tile, with a selection border, for the pickers that let a title be
/// added to a list or a calendar entry. Sized on the same rules as
/// [getItemContainer] so a picker and the list it feeds look alike.
Widget getItemSelectableContainer(
    BuildContext context, dynamic item, String type, bool isSelected,
    {double scale = 1.0, double? width}) {
  final double tileWidth = width ?? context.posterWidth * scale;

  return SizedBox(
    width: tileWidth,
    height: posterHeightFor(tileWidth),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: CachedNetworkImageProvider(
                item!["poster_path"] != null
                    ? IMG_LINK + item!["poster_path"]
                    : type == "media"
                        ? UNKNOWN_COVER
                        : UNKNOWN_PERSON,
              ),
              fit: BoxFit.cover,
            ),
            border: isSelected
                ? Border.all(
                    color: const Color.fromARGB(250, 224, 190, 78), width: 3)
                : null,
          ),
        ),
        if (item!['poster_path'] == null)
          Container(
            alignment: Alignment.center,
            child: Text(
              "${item!.containsKey("name") ? item!['name'] : item!['title']}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}
