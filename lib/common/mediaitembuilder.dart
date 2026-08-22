import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/social_service.dart';
import 'package:uractor/friends_thoughts.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/popups/share.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../objects/media.dart';
import '../objects/movie.dart';
import 'constants.dart';
import 'layout/breakpoints.dart';
import 'layout/two_pane.dart';
import 'platform/capabilities.dart';
import 'package:url_launcher/url_launcher.dart';

Widget getCover(Map data, context, MediaItem mediaItem, String type) {
  return Container(
    margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
    height: 200,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(27),
    ),
    child: Stack(
      children: [
        if (data['backdrop_path'] != "")
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: CachedNetworkImageProvider(
                  IMG_LINK + data['backdrop_path'],
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (data['backdrop_path'] == "")
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: const DecorationImage(
                image: AssetImage(
                  "assets/logo.png",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Text(
              "${type == "movie" ? data['title'] : data['name']} (${data['year']})",
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                wordSpacing: 2,
                height: 1.5,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.topLeft,
            child: FutureBuilder<Map>(
              future: SocialService.friendsWhoHaveSeen(
                  currentUser.uid, mediaItem, type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 32.0,
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return const SizedBox(
                    height: 32.0,
                    child: Center(child: Text('Error loading friends')),
                  );
                } else if (snapshot.hasData) {
                  var images = snapshot.data!.values.toList();
                  int extraCount = images.length - 3;
                  return GestureDetector(
                    onTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FriendsThoughts(
                                friends: snapshot.data!,
                                mediaItem: mediaItem,
                                type: type,
                                data: data)),
                      )
                    },
                    child: SizedBox(
                      height: 32.0,
                      child: Stack(
                        children: List.generate(
                          images.length > 3 ? 3 : images.length,
                          (index) {
                            double offset = index * 10.0;
                            if (index == 2 && images.length > 3) {
                              return Positioned(
                                left: offset,
                                child: ClipOval(
                                  child: Container(
                                    height: 25,
                                    width: 25,
                                    color: Colors.grey,
                                    child: Center(
                                      child: Text(
                                        '+$extraCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return Positioned(
                                left: offset,
                                child: ClipOval(
                                  child: images[index] != ""
                                      ? Image.network(
                                          images[index],
                                          height: 25,
                                          width: 25,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          'assets/main_profile.png',
                                          height: 25,
                                          width: 25,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) {
                        MediaItem tempItem = type == "movie"
                            ? Movie(
                                id: mediaItem.id,
                                title: data["title"],
                                coverPhoto: data["poster_path"] != null
                                    ? IMG_LINK + data["poster_path"]
                                    : UNKNOWN_COVER)
                            : TVShow(
                                id: mediaItem.id,
                                title: data["name"],
                                coverPhoto: data["poster_path"] != null
                                    ? IMG_LINK + data["poster_path"]
                                    : UNKNOWN_COVER);
                        return Share(
                          item: tempItem,
                          type: type,
                        );
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.share,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget getGenres(Map data) {
  return Container(
    height: 30,
    margin: const EdgeInsets.fromLTRB(20.0, 5.0, 0, 5.0),
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: data['genres'].length,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.3),
          ),
          child: Text(
            data['genres'][index]['name'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    ),
  );
}

Widget getRuntimeRating(Map data) {
  return Container(
    height: 45,
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 30,
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[900],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                '${data['runtime']} min',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 30,
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[900],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                'IMDB: ${data["imdb_rating"]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget getProviders(Map data, BuildContext context) {
  return Container(
    margin: const EdgeInsets.all(20.0),
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white),
            SizedBox(width: 10),
            Text(
              S.of(context)!.whereToWatch,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (data['providers'].length != 0)
          Container(
            height: 30,
            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 0, 5.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data['providers'].length,
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        IMG_LINK + data['providers'][index][1],
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        if (data['providers'].length == 0)
          Container(
            margin: const EdgeInsets.all(10.0),
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              S.of(context)!.nowhere,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget getTrailer(Map data) {
  final trailer = data["trailer"];
  final key = trailer is Map ? trailer["key"]?.toString() : null;
  if (key == null || key.isEmpty) return const SizedBox.shrink();
  return _Trailer(videoId: key);
}

// A StatefulWidget rather than an inline controller, because youtube_player_flutter
// 10 is backed by a real webview: a controller built in a build method would spin
// up a new one on every rebuild and never close any of them.
class _Trailer extends StatefulWidget {
  const _Trailer({required this.videoId});

  final String videoId;

  @override
  State<_Trailer> createState() => _TrailerState();
}

class _TrailerState extends State<_Trailer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // The player is a webview underneath, and there is no webview on Windows
    // or Linux. Building the controller there throws, so it is not built and
    // the trailer becomes a link out to YouTube instead.
    if (Capabilities.playsEmbeddedVideo) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          mute: false,
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
        child: OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text(S.of(context)!.watchTrailerOnYoutube),
        ),
      );
    }

    // The window, not the pane the player happens to sit in: a detail pane on
    // a tablet is phone sized, and reading the rule from it would put the
    // tablet straight back where it started.
    final bool fullScreenOnGesture = landscapeMeansFullScreen(
      windowSizeClassFor(MediaQuery.sizeOf(context).width),
    );

    Widget player = YoutubePlayer(
      controller: controller,
      autoFullScreen: fullScreenOnGesture,
      enableFullScreenOnVerticalDrag: fullScreenOnGesture,
    );

    // Going fullscreen puts the video in the nearest overlay, which inside a
    // detail pane is the pane's own, while the size it goes to is read from
    // the window. The two disagree by exactly the list beside it, so the video
    // arrives half a window wide in a half window box: cropped down its right
    // edge and pushed off the top. Telling it the pane is its screen is what
    // makes the two agree, and it fills the pane rather than fighting it.
    final DetailPane? pane = DetailPane.maybeOf(context);
    if (pane != null && pane.isInsidePane) {
      player = MediaQuery(
        data: MediaQuery.of(context).copyWith(size: pane.size),
        child: player,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
      // Both of the player's own gestures into fullscreen are read from the
      // window: turning the device sideways, and flicking upwards over the
      // video. Neither means anything on a window that is landscape all the
      // time and holds more than the video, so there the button is left as the
      // only way in — the one route that is a decision rather than a guess.
      child: player,
    );
  }
}
