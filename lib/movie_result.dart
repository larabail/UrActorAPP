// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'package:cached_network_image/cached_network_image.dart';
import 'package:uractor/objects/Media.dart';
import 'package:uractor/popups/add_to_calendar_pop_up.dart';
import 'package:uractor/popups/share.dart';

import 'cast_and_crew.dart';
import 'common/utils.dart';
import 'common/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'friends.dart';
import 'friends_profile.dart';
import 'main.dart';
import 'objects/Movie.dart';
import 'objects/Person.dart';
import 'person_result.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';

class MovieResult extends StatefulWidget {
  final Movie movie;
  const MovieResult({Key? key, required this.movie}) : super(key: key);

  @override
  _MovieResultState createState() => _MovieResultState();
}

class _MovieResultState extends State<MovieResult> {
  final myController = TextEditingController(text: "");
  bool isExpanded = false;
  String _imageProviderSeen = 'assets/seen_before.png';
  String _imageProviderWatchlist = 'assets/watchlist_before.png';
  String _imageProviderList = 'assets/playlists_before.png';
  String _imageProviderFav = 'assets/fav_before.png';
  bool _isTappedSeen = false;
  bool _isTappedWatchlist = false;
  bool _isTappedFav = false;
  bool _isTappedList = false;
  void check() {
    if (widget.movie.isSeen()) {
      _isTappedSeen = true;
      _imageProviderSeen = 'assets/seen_after.png';
    } else {
      _isTappedSeen = false;
      _imageProviderSeen = 'assets/seen_before.png';
    }
    if (widget.movie.isBookmarked()) {
      _isTappedWatchlist = true;
      _imageProviderWatchlist = 'assets/watchlist_after.png';
    } else {
      _isTappedWatchlist = false;
      _imageProviderWatchlist = 'assets/watchlist_before.png';
    }
    if (widget.movie.isFavorite()) {
      _isTappedFav = true;
      _imageProviderFav = 'assets/fav_after.png';
    } else {
      _isTappedFav = false;
      _imageProviderFav = 'assets/fav_before.png';
    }
    if (currentUser.reviews.keys.toList().contains(widget.movie.id)) {
      reviewed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    reviewed = false;
    check();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser.rewatchedMovies.keys.toList().contains(widget.movie.id)) {
        myController.text =
            (currentUser.rewatchedMovies[widget.movie.id]).toString();
      } else if (widget.movie.isSeen()) {
        myController.text = "1";
      } else {
        myController.text = "0";
      }
    });

    Future<void> _onTap(String type, String id, String title, int runtime,
        double rating) async {
      bool success = false;
      switch (type) {
        case 'seen':
          _isTappedSeen = !_isTappedSeen;
          if (_isTappedSeen) {
            success = await FirebaseUtils.markWatched(
                id, title, runtime, rating, context, "Movies");
          } else {
            success = await FirebaseUtils.deleteFromWatchedConfirmation(
                id, context, "Movies");
          }
          if (success) {
            setState(() {
              _imageProviderSeen = _isTappedSeen
                  ? 'assets/seen_after.png'
                  : 'assets/seen_before.png';
            });
          }
          break;
        case 'watchlist':
          _isTappedWatchlist = !_isTappedWatchlist;
          if (_isTappedWatchlist) {
            success = await FirebaseUtils.bookmark(id, context, "Movies");
            setState(() {
              currentUser.watchlist = currentUser.watchlist;
            });
          } else {
            success = await FirebaseUtils.unbookmark(id, context, "Movies");
            setState(() {
              currentUser.watchlist = currentUser.watchlist;
            });
          }
          break;
        case 'fav':
          _isTappedFav = !_isTappedFav;
          if (_isTappedFav) {
            success = await FirebaseUtils.favorite(id, context, "Movies");
            setState(() {
              currentUser.favMovies = currentUser.favMovies;
            });
          } else {
            success = await FirebaseUtils.unfavorite(id, context, "Movies");
            setState(() {
              currentUser.favMovies = currentUser.favMovies;
            });
          }
          break;
        case 'list':
          _isTappedList = !_isTappedList;
          if (_isTappedList) {
            _imageProviderList = 'assets/playlists_after.png';
            showModalBottomSheet(
              context: context,
              builder: (_) {
                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: (currentUser.playlists.length / 2).ceil(),
                    itemBuilder: (context, index) {
                      final leftMovieIndex = index * 2;
                      final rightMovieIndex = index * 2 + 1;
                      final keyLeft = (leftMovieIndex <
                              currentUser.playlists.length)
                          ? currentUser.playlists.keys.elementAt(leftMovieIndex)
                          : null;
                      final keyRight =
                          (rightMovieIndex < currentUser.playlists.length)
                              ? currentUser.playlists.keys
                                  .elementAt(rightMovieIndex)
                              : null;
                      dynamic valueLeft,
                          imageLeft,
                          moviesLeft,
                          valueRight,
                          imageRight,
                          moviesRight;
                      if (keyLeft != null) {
                        valueLeft = currentUser.playlists[keyLeft]['Name'];
                        imageLeft =
                            currentUser.playlists[keyLeft]['CoverPhoto'];
                        moviesLeft = currentUser.playlists[keyLeft]['Movies'];
                      }
                      if (keyRight != null) {
                        valueRight = currentUser.playlists[keyRight]['Name'];
                        imageRight =
                            currentUser.playlists[keyRight]['CoverPhoto'];
                        moviesRight = currentUser.playlists[keyRight]['Movies'];
                      }
                      return Row(
                        children: [
                          if (keyLeft != null)
                            GestureDetector(
                              onTap: () {
                                if (moviesLeft.contains(id)) {
                                  FirebaseUtils.deleteFromList(id, keyLeft,
                                      moviesLeft, context, "Movies");
                                } else {
                                  FirebaseUtils.addToList(id, keyLeft,
                                      moviesLeft, context, "Movies");
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        10.0, 10.0, 5.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(imageLeft),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
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
                                  ),
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          valueLeft,
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
                                  if (moviesLeft.contains(id))
                                    const Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Icon(Icons.check_circle,
                                          color: Colors.green),
                                    ),
                                ],
                              ),
                            ),
                          if (keyRight != null)
                            GestureDetector(
                              onTap: () {
                                if (moviesRight.contains(id)) {
                                  FirebaseUtils.deleteFromList(id, keyRight,
                                      moviesRight, context, "Movies");
                                } else {
                                  FirebaseUtils.addToList(id, keyRight,
                                      moviesRight, context, "Movies");
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(imageRight),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
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
                                  ),
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.45,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          valueRight,
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
                                  if (moviesRight.contains(id))
                                    const Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Icon(Icons.check_circle,
                                          color: Colors.green),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ).then((value) => {
                  setState(() {
                    _imageProviderList = 'assets/playlists_before.png';
                    _isTappedList = !_isTappedList;
                  })
                });
          } else {
            _imageProviderList = 'assets/playlists_before.png';
          }
          break;
        default:
          break;
      }
    }

    DateTime selectedDate = DateTime.now();
    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: widget.movie.getExtendedData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Stack(
                      children: [
                        if (snapshot.data!['backdrop_path'] != "")
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  IMG_LINK + snapshot.data!['backdrop_path'],
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (snapshot.data!['backdrop_path'] == "")
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
                              "${snapshot.data!['title']} (${snapshot.data!['year']})",
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
                                        MediaItem tempItem = Movie(
                                            id: widget.movie.id,
                                            title: snapshot.data!["title"],
                                            coverPhoto: IMG_LINK +
                                                snapshot.data!["poster_path"]);
                                        return Share(
                                          item: tempItem,
                                          type: "movie",
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
                  ),
                  if (snapshot.data!['overview'] != null &&
                      snapshot.data!['overview'] != "")
                    Padding(
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
                              snapshot.data!['overview'],
                              textAlign: TextAlign.justify,
                              overflow: TextOverflow.fade,
                              style: const TextStyle(
                                fontSize: 15,
                                wordSpacing: 2,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (!isExpanded &&
                              snapshot.data!['overview'].length > 100)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  isExpanded = true;
                                });
                              },
                              child: const SizedBox(
                                width: double.infinity,
                                child: Text(
                                  "Read All",
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Container(
                    height: 30,
                    margin: const EdgeInsets.fromLTRB(20.0, 5.0, 0, 5.0),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!['genres'].length,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.3),
                          ),
                          child: Text(
                            snapshot.data!['genres'][index]['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 45,
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 30,
                          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey[900],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                '${snapshot.data!['runtime']} min',
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
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
                                'IMDB: ${snapshot.data!["imdb_rating"]}',
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
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _onTap(
                              'seen',
                              snapshot.data!["id"].toString(),
                              snapshot.data!["title"],
                              snapshot.data!["runtime"],
                              double.parse(snapshot.data!["imdb_rating"]));
                          setState(() {});
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderSeen,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _onTap(
                              'watchlist',
                              snapshot.data!["id"].toString(),
                              snapshot.data!["title"],
                              snapshot.data!["runtime"],
                              double.parse(snapshot.data!["imdb_rating"]));
                          setState(() {});
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderWatchlist,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _onTap(
                              'fav',
                              snapshot.data!["id"].toString(),
                              snapshot.data!["title"],
                              snapshot.data!["runtime"],
                              double.parse(snapshot.data!["imdb_rating"]));
                          setState(() {});
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderFav,
                            height: 40,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _onTap(
                              'list',
                              snapshot.data!["id"].toString(),
                              snapshot.data!["title"],
                              snapshot.data!["runtime"],
                              double.parse(snapshot.data!["imdb_rating"]));
                          setState(() {});
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
                          child: Image.asset(
                            _imageProviderList,
                            height: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reviewed &&
                      snapshot.data!.keys.contains("review") &&
                      snapshot.data!["review"] != null)
                    ExpansionTile(
                        title: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reviews),
                            SizedBox(width: 8),
                            Text(
                              "Your Review",
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
                                      'Opinion: ${snapshot.data!["review"]["Opinion"]}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        wordSpacing: 2,
                                        height: 1.5,
                                      ),
                                    ),
                                    Text(
                                      'Rating: ${snapshot.data!["review"]["Rating"]}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        wordSpacing: 2,
                                        height: 1.5,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            bool success =
                                                await FirebaseUtils.editReview(
                                                    snapshot.data!["id"],
                                                    "Movies",
                                                    context);
                                            if (success) {
                                              setState(() {});
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit,
                                                    color: Colors.blue),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Edit',
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
                                            bool success = await FirebaseUtils
                                                .deleteReview(
                                                    snapshot.data!["id"],
                                                    "Movies",
                                                    context);
                                            if (success) {
                                              setState(() {});
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    color: Colors.red),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Delete',
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
                        ]),
                  if (!reviewed && widget.movie.isSeen())
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            bool success = await FirebaseUtils.writeReview(
                                snapshot.data!["id"], "Movies", context);
                            if (success) {
                              setState(() {
                                currentUser.reviews = currentUser.reviews;
                              });
                            }
                          },
                          child: const Row(
                            children: [
                              Icon(
                                Icons.reviews,
                                color: Colors.white,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Write A Review',
                                style: TextStyle(color: Colors.white),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  Container(
                    margin: const EdgeInsets.all(20.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 10.0),
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
                        if (snapshot.data!['providers'].length != 0)
                          Container(
                            height: 30,
                            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 0, 5.0),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: snapshot.data!['providers'].length,
                              itemBuilder: (BuildContext context, int index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        IMG_LINK +
                                            snapshot.data!['providers'][index]
                                                [1],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (snapshot.data!['providers'].length == 0)
                          Container(
                            margin: const EdgeInsets.all(10.0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 5.0),
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
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: myController,
                      decoration: const InputDecoration(
                        labelText: "Times seen",
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        FirebaseUtils.incrementWatched(
                            value.toString(), snapshot.data!["id"].toString());
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.movie.isSeen())
                    ExpansionTile(
                      title: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text(
                            "Viewing History",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              wordSpacing: 2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (snapshot.data!['seen_dates'] as List)
                                  .map<Widget>((date) {
                                List friendsWhoWatched = date[1] ?? [];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 16),
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        intl.DateFormat('dd MMMM, yyyy')
                                            .format(DateTime.parse(date[0])),
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700]),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Expanded(
                                        child: FutureBuilder<List<String>>(
                                          future:
                                              FirebaseUtils.getProfilePhotos(
                                                  friendsWhoWatched),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const SizedBox(
                                                height: 32.0,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              );
                                            } else if (snapshot.hasError) {
                                              return const SizedBox(
                                                height: 32.0,
                                                child: Center(
                                                    child: Text(
                                                        'Error loading images')),
                                              );
                                            } else if (snapshot.hasData) {
                                              var images = snapshot.data!;
                                              return SizedBox(
                                                height: 32.0,
                                                child: Stack(
                                                  children: List.generate(
                                                      images.length, (index) {
                                                    double offset =
                                                        index * 10.0;
                                                    return Positioned(
                                                      left: offset,
                                                      child: ClipOval(
                                                        child: images[index] !=
                                                                ""
                                                            ? Image.network(
                                                                images[index],
                                                                height: 25,
                                                                width: 25,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : Image.asset(
                                                                'assets/main_profile.png',
                                                                height: 25,
                                                                width: 25,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                          const SizedBox(height: 15),
                        if ((snapshot.data!['seen_dates'] as List).isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              "No viewing history available.",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.red),
                            ),
                          ),
                        if (currentUser.seenWith.entries
                            .where((entry) =>
                                entry.value["Movies"]
                                    ?.contains(widget.movie.id) ??
                                false)
                            .isNotEmpty)
                          const Text("People watched with",
                              style: TextStyle(
                                fontSize: 16,
                              )),
                        FutureBuilder(
                          future: Future.wait(
                            currentUser.seenWith.entries
                                .where((entry) =>
                                    entry.value["Movies"]
                                        ?.contains(widget.movie.id) ??
                                    false)
                                .map((entry) => FirebaseFirestore.instance
                                    .collection(entry.key)
                                    .doc("Settings")
                                    .get()),
                          ),
                          builder: (BuildContext context,
                              AsyncSnapshot<List> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  "Failed to load friends' profiles.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            } else if (snapshot.hasData) {
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 3 / 1,
                                ),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  var doc = snapshot.data![index];
                                  var userData =
                                      doc.data() as Map<String, dynamic>;
                                  var profilePhoto = userData['profile_photo'];
                                  var username =
                                      userData['username'] ?? 'Unknown';

                                  return GestureDetector(
                                      onTap: () async {
                                        var querySnapshot =
                                            await FirebaseFirestore.instance
                                                .collection('usernames')
                                                .where('username',
                                                    isEqualTo: username)
                                                .limit(1)
                                                .get();

                                        friendUid = querySnapshot.docs.first
                                            .data()['uid'];
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FriendProfile(
                                                friendUID: friendUid),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[900],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ClipOval(
                                                child: profilePhoto != ""
                                                    ? Image.network(
                                                        profilePhoto,
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
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      username,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ));
                                },
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    Map<String, bool> selectedFriends = {};
                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        return AlertDialog(
                                          title: const Text('Add Friends'),
                                          content: SizedBox(
                                            height: 250,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: List.generate(
                                                  currentUser.friends.length,
                                                  (friendIndex) {
                                                    return FutureBuilder<
                                                        DocumentSnapshot>(
                                                      future: FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                              currentUser
                                                                      .friends[
                                                                  friendIndex])
                                                          .doc('Settings')
                                                          .get(),
                                                      builder:
                                                          (context, snapshot) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return const Center(
                                                              child:
                                                                  CircularProgressIndicator());
                                                        } else if (snapshot
                                                            .hasError) {
                                                          return Text(
                                                              'Error: ${snapshot.error}');
                                                        } else if (!snapshot
                                                                .hasData ||
                                                            !snapshot
                                                                .data!.exists) {
                                                          return const Text(
                                                              'No data found');
                                                        } else {
                                                          var data = snapshot
                                                                  .data!
                                                                  .data()
                                                              as Map<String,
                                                                  dynamic>;
                                                          String userName =
                                                              data['username'] ??
                                                                  '';
                                                          String profilePath =
                                                              data['profile_photo'] ??
                                                                  '';
                                                          return CheckboxListTile(
                                                            title: Row(
                                                              children: [
                                                                ClipOval(
                                                                  child: profilePath !=
                                                                          ""
                                                                      ? Image
                                                                          .network(
                                                                          profilePath,
                                                                          height:
                                                                              25,
                                                                          width:
                                                                              25,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        )
                                                                      : Image
                                                                          .asset(
                                                                          'assets/main_profile.png',
                                                                          height:
                                                                              25,
                                                                          width:
                                                                              25,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                ),
                                                                const SizedBox(
                                                                    width:
                                                                        16.0),
                                                                Expanded(
                                                                  child: Text(
                                                                    userName,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            16.0),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            value: selectedFriends
                                                                    .keys
                                                                    .toList()
                                                                    .contains(currentUser
                                                                            .friends[
                                                                        friendIndex])
                                                                ? selectedFriends[
                                                                    currentUser
                                                                            .friends[
                                                                        friendIndex]]
                                                                : false,
                                                            onChanged:
                                                                (bool? value) {
                                                              setState(() {
                                                                selectedFriends[
                                                                    currentUser
                                                                            .friends[
                                                                        friendIndex]] = value!;
                                                              });
                                                            },
                                                          );
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              child: const Text('Cancel'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            TextButton(
                                              child: const Text('Apply'),
                                              onPressed: () async {
                                                String id = widget.movie.id;
                                                FirebaseFirestore firestore =
                                                    FirebaseFirestore.instance;
                                                for (String friend
                                                    in selectedFriends.keys
                                                        .toList()) {
                                                  var userDoc =
                                                      FirebaseFirestore.instance
                                                          .collection(friend)
                                                          .doc("Movies");
                                                  await userDoc.update({
                                                    'Seen':
                                                        FieldValue.arrayUnion(
                                                            [id])
                                                  });
                                                  if (currentUser.seenWith
                                                          .containsKey(
                                                              friend) &&
                                                      !currentUser
                                                          .seenWith[friend]
                                                              ["Movies"]
                                                          .contains(
                                                              id.toString())) {
                                                    currentUser.seenWith[friend]
                                                            ["Movies"]
                                                        .add(id.toString());
                                                  } else if (!currentUser
                                                      .seenWith
                                                      .containsKey(friend)) {
                                                    currentUser
                                                        .seenWith[friend] = {
                                                      "Movies": [],
                                                      "TVShows": []
                                                    };
                                                    currentUser.seenWith[friend]
                                                            ["Movies"]
                                                        .add(id.toString());
                                                  }
                                                  DocumentReference userDoc2 =
                                                      firestore
                                                          .collection(friend)
                                                          .doc("SeenWith");
                                                  Map<String, dynamic> item =
                                                      {};
                                                  List<dynamic>
                                                      watchedWithList = [
                                                    currentUser.uid
                                                  ];
                                                  item[id] = watchedWithList;
                                                  await firestore
                                                      .runTransaction(
                                                          (transaction) async {
                                                    DocumentSnapshot snapshot =
                                                        await transaction
                                                            .get(userDoc2);

                                                    if (!snapshot.exists) {
                                                      throw Exception(
                                                          "Document does not exist!");
                                                    }

                                                    Map<String, dynamic> data =
                                                        snapshot.data() as Map<
                                                            String, dynamic>;

                                                    if (data.containsKey(
                                                            'Movies') &&
                                                        data['Movies'] is Map<
                                                            String, dynamic>) {
                                                      Map<String, dynamic>
                                                          moviesMap =
                                                          data['Movies'];

                                                      if (moviesMap
                                                          .containsKey(id)) {
                                                        List existingList =
                                                            moviesMap[id]
                                                                ["friends"];
                                                        for (String person
                                                            in watchedWithList) {
                                                          if (!existingList
                                                              .contains(
                                                                  person)) {
                                                            existingList
                                                                .add(person);
                                                          }
                                                        }
                                                        moviesMap[id] = {
                                                          "friends":
                                                              existingList
                                                        };
                                                        transaction.update(
                                                            userDoc2, {
                                                          "Movies": moviesMap
                                                        });
                                                      } else {
                                                        moviesMap[id] = {
                                                          "friends":
                                                              watchedWithList
                                                        };
                                                        transaction.update(
                                                            userDoc2, {
                                                          "Movies": moviesMap
                                                        });
                                                      }
                                                    } else {
                                                      transaction.set(
                                                          userDoc2,
                                                          {
                                                            'Movies': {
                                                              id: {
                                                                "friends":
                                                                    watchedWithList
                                                              }
                                                            }
                                                          },
                                                          SetOptions(
                                                              merge: true));
                                                    }
                                                  }).catchError((error) {
                                                    print(
                                                        "Failed to update document: $error");
                                                  });
                                                }
                                                DocumentReference userDoc2 =
                                                    firestore
                                                        .collection(
                                                            currentUser.uid)
                                                        .doc("SeenWith");

                                                Map<String, dynamic> item = {};
                                                List<dynamic> watchedWithList =
                                                    selectedFriends.keys
                                                        .where((key) =>
                                                            selectedFriends[
                                                                key] ==
                                                            true)
                                                        .toList();
                                                item[id] = watchedWithList;
                                                firestore.runTransaction(
                                                    (transaction) async {
                                                  DocumentSnapshot snapshot =
                                                      await transaction
                                                          .get(userDoc2);

                                                  if (!snapshot.exists) {
                                                    throw Exception(
                                                        "Document does not exist!");
                                                  }

                                                  Map<String, dynamic> data =
                                                      snapshot.data() as Map<
                                                          String, dynamic>;

                                                  if (data.containsKey(
                                                          'Movies') &&
                                                      data['Movies'] is Map<
                                                          String, dynamic>) {
                                                    Map<String, dynamic>
                                                        moviesMap =
                                                        data['Movies'];

                                                    if (moviesMap
                                                        .containsKey(id)) {
                                                      List existingList =
                                                          moviesMap[id]
                                                              ["friends"];
                                                      for (String person
                                                          in watchedWithList) {
                                                        if (!existingList
                                                            .contains(person)) {
                                                          existingList
                                                              .add(person);
                                                        }
                                                      }
                                                      moviesMap[id] = {
                                                        "friends": existingList
                                                      };
                                                    } else {
                                                      moviesMap[id] = {
                                                        "friends":
                                                            watchedWithList
                                                      };
                                                    }
                                                    transaction.update(userDoc2,
                                                        {'Movies': moviesMap});
                                                  } else {
                                                    transaction.set(
                                                        userDoc2,
                                                        {
                                                          'Movies': {
                                                            id: {
                                                              "friends":
                                                                  watchedWithList
                                                            }
                                                          }
                                                        },
                                                        SetOptions(
                                                            merge: true));
                                                  }
                                                }).catchError((error) {
                                                  print(
                                                      "Failed to update document: $error");
                                                });
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ).then((_) {
                                  setState(() {});
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                width: 145,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.person_add, color: Colors.green),
                                    SizedBox(width: 10),
                                    Text(
                                      'Add Friends',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            GestureDetector(
                              onTap: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2101),
                                  builder:
                                      (BuildContext context, Widget? child) {
                                    return Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: const ColorScheme.dark(
                                            primary: Colors.lightBlue),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (pickedDate != null) {
                                  selectedDate = pickedDate;
                                  if (currentUser.friends.isNotEmpty) {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AddToCalendar(
                                          movie: widget.movie,
                                          dateForMap: selectedDate
                                              .toIso8601String()
                                              .split("T")[0],
                                        );
                                      },
                                    );
                                    if (result != null) {
                                      setState(() {});
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                width: 145,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded,
                                        color: Colors.green),
                                    SizedBox(width: 10),
                                    Text(
                                      'Add Date',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0.0, 5.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CastCrew(
                                  data: {
                                    "cast": snapshot.data!['cast'],
                                    "crew": snapshot.data!['crew']
                                  },
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "Cast and Crew: (See All)",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.25,
                        margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!['cast'].length < 10
                              ? snapshot.data!['cast'].length
                              : 10,
                          itemBuilder: (BuildContext context, int index) {
                            Map person = snapshot.data!['cast'][index];
                            if (person['profile_path'] == null) {
                              person['profile_path'] =
                                  "https://cdn-icons-png.flaticon.com/512/3088/3088765.png";
                            } else {
                              person['profile_path'] =
                                  IMG_LINK + person['profile_path'];
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(5.0, 0.0, 5.0, 0.0),
                              child: GestureDetector(
                                onTap: () {
                                  Person personResult = Person(
                                      id: person["id"].toString(),
                                      name: person["name"].toString(),
                                      data: person);

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PersonResult(
                                              personResult: personResult,
                                            )),
                                  );
                                },
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          10.0, 10.0, 5.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.25,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(27),
                                        child: Image.network(
                                          person['profile_path'],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${person["name"]}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'as ${person["character"]}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 1,
                        height: 50,
                        margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!['crew'].length < 5
                              ? snapshot.data!['crew'].length
                              : 5,
                          itemBuilder: (BuildContext context, int index) {
                            var director = snapshot.data!['crew'].firstWhere(
                              (person) => person['job'] == 'Director',
                              orElse: () => null,
                            );
                            var writer = snapshot.data!['crew'].firstWhere(
                              (person) =>
                                  person['job'] == 'Writer' ||
                                  person['job'] == 'Screenplay',
                              orElse: () => null,
                            );

                            if (index == 0 && director != null) {
                              return GestureDetector(
                                  onTap: () {
                                    Person personResult = Person(
                                        id: director["id"].toString(),
                                        name: director["name"].toString(),
                                        data: director);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PersonResult(
                                                personResult: personResult,
                                              )),
                                    );
                                  },
                                  child: Text(
                                    "Directed by ${director['name']}",
                                    style: const TextStyle(fontSize: 15),
                                  ));
                            }

                            if (index == 1 && writer != null) {
                              return GestureDetector(
                                  onTap: () {
                                    Person personResult = Person(
                                        id: writer["id"].toString(),
                                        name: writer["name"].toString(),
                                        data: writer);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PersonResult(
                                                personResult: personResult,
                                              )),
                                    );
                                  },
                                  child: Text(
                                    "${writer['job'] == "Writer" ? "Written" : writer["job"]} by ${writer['name']}",
                                    style: const TextStyle(fontSize: 15),
                                  ));
                            }
                            return Container();
                          },
                        ),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (BuildContext context) {
                      try {
                        return Container(
                          margin:
                              const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 20.0),
                          child: YoutubePlayer(
                            controller: YoutubePlayerController(
                              initialVideoId: snapshot.data!["trailer"]["key"],
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
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text("Failed to load movie details"),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
