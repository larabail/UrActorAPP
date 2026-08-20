import 'package:flutter/material.dart';

import 'package:uractor/common/firebase/firebaseutils.dart';
import 'package:uractor/common/firebase/playlist_service.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:uractor/main.dart';

/// A handful of widgets shared between the movie and TV show detail screens
/// (`movie_result.dart` / `tvshow_result.dart`) to remove copy-pasted UI code.
/// Only pieces of UI that were byte-identical (or identical apart from a
/// couple of clearly-parameterisable strings/callbacks) between the two
/// screens were extracted here; anything with meaningfully different
/// behaviour between the two screens was intentionally left duplicated.

/// The dark gradient scrim drawn over playlist cover images so that the
/// playlist name remains legible. Identical in both detail screens.
class GradientOverlay extends StatelessWidget {
  final BorderRadius borderRadius;

  const GradientOverlay({
    this.borderRadius = const BorderRadius.all(Radius.circular(27)),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small circular profile photo, falling back to the default profile
/// asset when no photo is available. Used across both detail screens
/// wherever a friend/user avatar is shown.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const ProfileAvatar({this.photoUrl, this.size = 25, super.key});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: (photoUrl != null && photoUrl != "")
          ? Image.network(
              photoUrl!,
              height: size,
              width: size,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/main_profile.png',
              height: size,
              width: size,
              fit: BoxFit.cover,
            ),
    );
  }
}

/// Renders the row of overlapping friend-avatar bubbles shown next to a
/// viewing-history date, once the list of friend uids who watched on that
/// date has been resolved to profile photo urls. Identical in both detail
/// screens.
class WatchedFriendsStack extends StatelessWidget {
  final List friendsWhoWatched;

  const WatchedFriendsStack({required this.friendsWhoWatched, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: FirebaseUtils.getProfilePhotos(friendsWhoWatched),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 32.0,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SizedBox(
            height: 32.0,
            child: Center(child: Text(S.of(context)!.errorLoadingImages)),
          );
        } else if (snapshot.hasData) {
          var images = snapshot.data!;
          return SizedBox(
            height: 32.0,
            child: Stack(
              children: List.generate(images.length, (index) {
                double offset = index * 10.0;
                return Positioned(
                  left: offset,
                  child: ProfileAvatar(photoUrl: images[index], size: 25),
                );
              }),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// The expandable synopsis text block shown near the top of both detail
/// screens. Manages its own "read all" expansion state, since that state
/// was purely local UI state on both screens.
class OverviewSection extends StatefulWidget {
  final String overview;

  const OverviewSection({required this.overview, super.key});

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            constraints: BoxConstraints(
              maxHeight: isExpanded ? double.infinity : 85,
            ),
            child: Text(
              widget.overview,
              textAlign: TextAlign.justify,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                fontSize: 15,
                wordSpacing: 2,
                height: 1.5,
              ),
            ),
          ),
          if (!isExpanded && widget.overview.length > 100)
            InkWell(
              onTap: () {
                setState(() {
                  isExpanded = true;
                });
              },
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  S.of(context)!.readAll,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The row of seen/watchlist/favorite/add-to-list icon buttons shown on
/// both detail screens. The two screens differ in what happens on tap
/// (movie also fires an extra `setState` after each tap; the id/title/
/// runtime/rating values passed through differ), so that behaviour is left
/// to the [onIconTap] callback supplied by the caller rather than being
/// baked into this widget.
class MediaStatusIconsRow extends StatelessWidget {
  final String seenImage;
  final String watchlistImage;
  final String favImage;
  final String listImage;
  final void Function(String type) onIconTap;

  const MediaStatusIconsRow({
    required this.seenImage,
    required this.watchlistImage,
    required this.favImage,
    required this.listImage,
    required this.onIconTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon(String type, String image) {
      return GestureDetector(
        onTap: () => onIconTap(type),
        child: Container(
          margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
          child: Image.asset(
            image,
            height: 40,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon('seen', seenImage),
        icon('watchlist', watchlistImage),
        icon('fav', favImage),
        icon('list', listImage),
      ],
    );
  }
}

/// The "your review" expandable panel with edit/delete actions, shown on
/// both detail screens once the user has reviewed the title. The two
/// screens differ only in the Firestore "type" string passed to
/// [ReviewService] and in the localized rating text (movies and TV shows
/// use different `S.of(context)!` calls to build it), both of which are
/// supplied by the caller.
class MediaReviewSection extends StatelessWidget {
  final Map data;
  final String reviewMediaType;
  final String opinionText;
  final String ratingText;
  final VoidCallback onChanged;

  const MediaReviewSection({
    required this.data,
    required this.reviewMediaType,
    required this.opinionText,
    required this.ratingText,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reviews),
          SizedBox(width: 8),
          Text(
            S.of(context)!.yourReview,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              wordSpacing: 2,
              height: 1.5,
            ),
          ),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Align(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 26, 25, 25),
                borderRadius: BorderRadius.circular(27),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Text(
                    opinionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      wordSpacing: 2,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    ratingText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      wordSpacing: 2,
                      height: 1.5,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          bool success = await ReviewService.editReview(
                              data["id"], reviewMediaType, context);
                          if (success) {
                            onChanged();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 10),
                              Text(
                                S.of(context)!.edit,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () async {
                          bool success = await ReviewService.deleteReview(
                              data["id"], reviewMediaType, context);
                          if (success) {
                            onChanged();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                S.of(context)!.delete,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The bottom-sheet grid used to add/remove a title from one of the
/// current user's playlists. Identical between the two detail screens
/// apart from which key of a playlist's contents is inspected
/// (`'Movies'` vs `'TV Shows'`) and which media type string is passed
/// through to [PlaylistService.updateList] (`'Movies'` vs `'TVShows'`).
class PlaylistPickerModal extends StatelessWidget {
  final String id;
  final String playlistMediaKey;
  final String serviceMediaType;

  const PlaylistPickerModal({
    required this.id,
    required this.playlistMediaKey,
    required this.serviceMediaType,
    super.key,
  });

  Widget _card(
    BuildContext context, {
    required EdgeInsets imageMargin,
    required EdgeInsets textMargin,
    required dynamic image,
    required dynamic value,
    required dynamic mediaList,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            margin: imageMargin,
            width: MediaQuery.of(context).size.width * 0.45,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: CachedNetworkImageProvider(image),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const GradientOverlay(),
          Container(
            margin: textMargin,
            width: MediaQuery.of(context).size.width * 0.45,
            height: MediaQuery.of(context).size.height * 0.18,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.25,
                    wordSpacing: 1.75,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (mediaList.contains(id))
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: (currentUser.playlists.length / 2).ceil(),
        itemBuilder: (context, index) {
          final leftMovieIndex = index * 2;
          final rightMovieIndex = index * 2 + 1;
          final keyLeft = (leftMovieIndex < currentUser.playlists.length)
              ? currentUser.playlists.keys.elementAt(leftMovieIndex)
              : null;
          final keyRight = (rightMovieIndex < currentUser.playlists.length)
              ? currentUser.playlists.keys.elementAt(rightMovieIndex)
              : null;
          dynamic valueLeft,
              imageLeft,
              moviesLeft,
              valueRight,
              imageRight,
              moviesRight;
          if (keyLeft != null) {
            valueLeft = currentUser.playlists[keyLeft]['Name'];
            imageLeft = currentUser.playlists[keyLeft]['CoverPhoto'];
            moviesLeft = currentUser.playlists[keyLeft][playlistMediaKey];
          }
          if (keyRight != null) {
            valueRight = currentUser.playlists[keyRight]['Name'];
            imageRight = currentUser.playlists[keyRight]['CoverPhoto'];
            moviesRight = currentUser.playlists[keyRight][playlistMediaKey];
          }
          return Row(
            children: [
              if (keyLeft != null)
                _card(
                  context,
                  imageMargin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
                  textMargin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                  image: imageLeft,
                  value: valueLeft,
                  mediaList: moviesLeft,
                  onTap: () {
                    PlaylistService.updateList(id, keyLeft, moviesLeft,
                        context, serviceMediaType, !moviesLeft.contains(id));
                  },
                ),
              if (keyRight != null)
                _card(
                  context,
                  imageMargin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                  textMargin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                  image: imageRight,
                  value: valueRight,
                  mediaList: moviesRight,
                  onTap: () {
                    PlaylistService.updateList(id, keyRight, moviesRight,
                        context, serviceMediaType, !moviesRight.contains(id));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
