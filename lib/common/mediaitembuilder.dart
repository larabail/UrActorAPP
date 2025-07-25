import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/social_service.dart';
import 'package:uractor/friends_thoughts.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/TVShow.dart';
import 'package:uractor/popups/share.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../objects/Media.dart';
import '../objects/Movie.dart';
import 'constants.dart';

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
                Colors.black.withOpacity(1),
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
              color: Colors.black.withOpacity(0.5),
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
                                    : UNKOWN_COVER)
                            : TVShow(
                                id: mediaItem.id,
                                title: data["name"],
                                coverPhoto: data["poster_path"] != null
                                    ? IMG_LINK + data["poster_path"]
                                    : UNKOWN_COVER);
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

Widget getGenres(data) {
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
            color: Colors.white.withOpacity(0.3),
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

Widget getRuntimeRating(data) {
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

Widget getProviders(data) {
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
        const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "Where to Watch?",
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
            child: const Text(
              "Nowhere at the moment",
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

Widget getTrailer(data) {
  return Builder(
    builder: (BuildContext context) {
      try {
        return Container(
          margin: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
          child: YoutubePlayer(
            controller: YoutubePlayerController(
              initialVideoId: data["trailer"]["key"],
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                hideControls: false,
              ),
            ),
            showVideoProgressIndicator: true,
          ),
        );
      } catch (e) {
        return const Center(
          child: Text(''),
        );
      }
    },
  );
}
