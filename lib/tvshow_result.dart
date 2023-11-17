// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'common/constants.dart';
import 'common/utils.dart';
import 'friends.dart';
import 'friends_profile.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'objects/TVShow.dart';
import 'person_result.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

String _imageProviderSeen = 'assets/seen_before.png';
String _imageProviderWatchlist = 'assets/watchlist_before.png';
String _imageProviderList = 'assets/playlists_before.png';
String _imageProviderFav = 'assets/fav_before.png';
bool _isTappedSeen = false;
bool _isTappedWatchlist = false;
bool _isTappedFav = false;
bool _isTappedList = false;

class TVShowResult extends StatefulWidget {
  // const TVShowResult({super.key});

  final TVShow tvshow;
  const TVShowResult({Key? key, required this.tvshow}) : super(key: key);

  @override
  _TVShowResultState createState() => _TVShowResultState();
}

bool containsMap(List list, List map) {
  for (int i = 0; i < list.length; i++) {
    if ((list[i][1]) as String == map[1].toString() &&
        (list[i][0]) as String == map[0].toString()) {
      return true;
    }
  }
  return false;
}

class _TVShowResultState extends State<TVShowResult> {
  Future<Map> getMovieData() async {
    List movieData = [widget.tvshow.id, "TVShows"];
    String name = movieData[1]
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$TV_SHOW_LINK${movieData[0]}-$name$API_KEY'));
    print('$TV_SHOW_LINK${movieData[0]}-$name$API_KEY');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final response2 = await http.get(
          Uri.parse('$TV_SHOW_LINK${movieData[0]}-$name$EXTERNAL_IDS_LINK'));
      if (response2.statusCode == 200) {
        String imdbId = jsonDecode(response2.body)['imdb_id'];
        String link2 = 'https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9';
        final r = await http.get(Uri.parse(link2));
        if (r.statusCode == 200) {
          json['imdb_rating'] = jsonDecode(r.body)['imdbRating'];
          json['year'] = jsonDecode(r.body)['Year'];
          final r2 = await http.get(Uri.parse(
              '$TV_SHOW_LINK${movieData[0]}-$name$WATCH_PROVIDERS_LINK'));
          if (r2.statusCode == 200) {
            json['providers'] = [];
            if (jsonDecode(r2.body)["results"]
                .keys
                .contains(currentUser.country)) {
              if (jsonDecode(r2.body)["results"][currentUser.country]
                      ['flatrate'] !=
                  null) {
                jsonDecode(r2.body)["results"][currentUser.country]['flatrate']
                    .forEach(
                  (provider) async {
                    String name = provider['provider_name'];
                    String photo = IMG_LINK + provider['logo_path'];
                    json['providers'].add([name, photo]);
                  },
                );
                final r3 = await http.get(Uri.parse(
                    '$TV_SHOW_LINK${movieData[0]}-$name$CREDITS_LINK'));
                if (r3.statusCode == 200) {
                  json['cast'] = jsonDecode(r3.body)["cast"];
                  json['crew'] = jsonDecode(r3.body)["crew"];
                  final r4 = await http.get(Uri.parse(
                      '$TV_SHOW_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                  if (r4.statusCode == 200) {
                    bool got = false;
                    jsonDecode(r4.body)['results'].forEach((element) {
                      if (element['site'] == "YouTube" &&
                          element['type'] == "Trailer" &&
                          !got) {
                        json['trailer'] = element;
                        got = true;
                      }
                    });
                    return json;
                  }
                  throw Exception('Failed to load movie details');
                }
                throw Exception('Failed to load movie details');
              } else {
                json['providers'] = [];
                final r3 = await http.get(Uri.parse(
                    '$TV_SHOW_LINK${movieData[0]}-$name$CREDITS_LINK'));
                if (r3.statusCode == 200) {
                  json['cast'] = jsonDecode(r3.body)["cast"];
                  json['crew'] = jsonDecode(r3.body)["crew"];
                  final r4 = await http.get(Uri.parse(
                      '$TV_SHOW_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                  if (r4.statusCode == 200) {
                    bool got = false;
                    jsonDecode(r4.body)['results'].forEach((element) {
                      if (element['site'] == "YouTube" &&
                          element['type'] == "Trailer" &&
                          !got) {
                        json['trailer'] = element;
                        got = true;
                      }
                    });
                    return json;
                  }
                  throw Exception('Failed to load movie details');
                }
                throw Exception('Failed to load movie details');
              }
            } else {
              json['providers'] = [];
              final r3 = await http.get(
                  Uri.parse('$TV_SHOW_LINK${movieData[0]}-$name$CREDITS_LINK'));
              if (r3.statusCode == 200) {
                json['cast'] = jsonDecode(r3.body)["cast"];
                json['crew'] = jsonDecode(r3.body)["crew"];
                final r4 = await http.get(Uri.parse(
                    '$TV_SHOW_LINK${movieData[0]}-$name$VIDEOS_LINK'));
                if (r4.statusCode == 200) {
                  bool got = false;
                  jsonDecode(r4.body)['results'].forEach((element) {
                    if (element['site'] == "YouTube" &&
                        element['type'] == "Trailer" &&
                        !got) {
                      json['trailer'] = element;
                      got = true;
                    }
                  });
                  return json;
                }
                throw Exception('Failed to load movie details');
              }
              throw Exception('Failed to load movie details');
            }
          } else {
            throw Exception('Failed to load movie details');
          }
        } else {
          throw Exception('Failed to load movie details');
        }
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  void check() {
    if (widget.tvshow.isSeen()) {
      _isTappedSeen = true;
      _imageProviderSeen = 'assets/seen_after.png';
    } else {
      _isTappedSeen = false;
      _imageProviderSeen = 'assets/seen_before.png';
    }
    if (widget.tvshow.isBookmarked()) {
      _isTappedWatchlist = true;
      _imageProviderWatchlist = 'assets/watchlist_after.png';
    } else {
      _isTappedWatchlist = false;
      _imageProviderWatchlist = 'assets/watchlist_before.png';
    }
    if (widget.tvshow.isFavorite()) {
      _isTappedFav = true;
      _imageProviderFav = 'assets/fav_after.png';
    } else {
      _isTappedFav = false;
      _imageProviderFav = 'assets/fav_before.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    check();

    Future<void> _onTap(String type, String id, String title, int runtime,
        double rating) async {
      bool success = false;
      switch (type) {
        case 'seen':
          _isTappedSeen = !_isTappedSeen;
          if (_isTappedSeen) {
            success = await FirebaseUtils.markWatched(
                id, title, runtime, rating, context, "TVShows");
          } else {
            success = await FirebaseUtils.deleteFromWatchedConfirmation(
                id, context, "TVShows");
          }
          break;
        case 'watchlist':
          _isTappedWatchlist = !_isTappedWatchlist;
          if (_isTappedWatchlist) {
            success = await FirebaseUtils.bookmark(id, context, "TVShows");
          } else {
            success = await FirebaseUtils.unbookmark(id, context, "TVShows");
          }
          break;
        case 'fav':
          _isTappedFav = !_isTappedFav;
          if (_isTappedFav) {
            success = await FirebaseUtils.favorite(id, context, "TVShows");
          } else {
            success = await FirebaseUtils.unfavorite(id, context, "TVShows");
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
                        moviesLeft = currentUser.playlists[keyLeft]['TV Shows'];
                      }
                      if (keyRight != null) {
                        valueRight = currentUser.playlists[keyRight]['Name'];
                        imageRight =
                            currentUser.playlists[keyRight]['CoverPhoto'];
                        moviesRight =
                            currentUser.playlists[keyRight]['TV Shows'];
                      }
                      return Row(
                        children: [
                          if (keyLeft != null)
                            GestureDetector(
                              onTap: () {
                                if (moviesLeft.contains(id)) {
                                  FirebaseUtils.deleteFromList(id, keyLeft,
                                      moviesLeft, context, "TVShows");
                                } else {
                                  FirebaseUtils.addToList(id, keyLeft,
                                      moviesLeft, context, "TVShows");
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
                                        image: NetworkImage(imageLeft),
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
                                    // Use Align to position the text
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          valueLeft,
                                          style: const TextStyle(
                                            color: Colors
                                                .white, // Make sure the text is visible on the gradient
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
                                      moviesRight, context, "TVShows");
                                } else {
                                  FirebaseUtils.addToList(id, keyRight,
                                      moviesRight, context, "TVShows");
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
                                        image: NetworkImage(imageRight),
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

      if (success) {
        setState(() {});
      }
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: getMovieData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          // print(snapshot.data);
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
                                image: NetworkImage(
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
                              "${snapshot.data!['name']} (${snapshot.data!['year']})",
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                wordSpacing: 2,
                                height: 1.5,
                              ),
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
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          height: 85, // fixed height
                          padding: const EdgeInsets.all(8), // optional padding
                          child: ListView(
                            children: [
                              Text(
                                snapshot.data!['overview'],
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontSize: 15,
                                  wordSpacing: 2,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    height: 30, // fixed height
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 30,
                        margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey[
                              900], // Adjust the background color opacity as needed
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min, // Use min to wrap content
                          children: [
                            const Icon(Icons.access_time,
                                color: Colors
                                    .white), // Replace with your desired icon
                            const SizedBox(width: 5),
                            Text(
                              snapshot.data!['seasons'].length > 1
                                  ? '${snapshot.data!['seasons'].length} seasons'
                                  : '${snapshot.data!['seasons'].length} season',
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
                          color: Colors.grey[
                              900], // Adjust the background color opacity as needed
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min, // Use min to wrap content
                          children: [
                            const Icon(Icons.star,
                                color: Colors
                                    .white), // Replace with your desired icon
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _onTap(
                            'seen',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["name"],
                            0,
                            0),
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
                        onTap: () => _onTap(
                            'watchlist',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["name"],
                            0,
                            0),
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
                        onTap: () => _onTap(
                            'fav',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["name"],
                            0,
                            0),
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
                        onTap: () => _onTap(
                            'list',
                            snapshot.data!["id"].toString(),
                            snapshot.data!["name"],
                            0,
                            0),
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
                            height: 30, // fixed height
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
                                      image: NetworkImage(
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
                  // Container(
                  //   margin: const EdgeInsets.all(10.0), // set margin here
                  //   child: const Text(
                  //     "Where to Watch?",
                  //     style: TextStyle(fontSize: 18),
                  //   ),
                  // ),
                  // if (snapshot.data!['providers'].length != 0)
                  //   Container(
                  //     height: 30, // fixed height
                  //     margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
                  //     child: ListView.builder(
                  //       scrollDirection: Axis.horizontal,
                  //       itemCount: snapshot.data!['providers'].length,
                  //       itemBuilder: (BuildContext context, int index) {
                  //         return Container(
                  //           margin: const EdgeInsets.only(right: 10),
                  //           height: 40,
                  //           width: 40,
                  //           decoration: BoxDecoration(
                  //             borderRadius: BorderRadius.circular(10),
                  //             image: DecorationImage(
                  //               image: NetworkImage(
                  //                 imgLink +
                  //                     snapshot.data!['providers'][index][1],
                  //               ),
                  //               fit: BoxFit.cover,
                  //             ),
                  //           ),
                  //         );
                  //       },
                  //     ),
                  //   ),
                  // if (snapshot.data!['providers'].length == 0)
                  //   Container(
                  //     margin: const EdgeInsets.all(10.0), // set margin here
                  //     child: const Text(
                  //       "Nowhere at the moment",
                  //       style: TextStyle(fontSize: 18),
                  //     ),
                  //   ),
                  // SizedBox(
                  //   width: 200,
                  //   child: TextField(
                  //     controller: TextEditingController(),
                  //     decoration: const InputDecoration(
                  //       labelText: 'Times Seen',
                  //       hintStyle: TextStyle(color: Colors.grey),
                  //       enabledBorder: UnderlineInputBorder(
                  //         borderSide: BorderSide(color: Colors.grey),
                  //       ),
                  //       labelStyle: TextStyle(color: Colors.grey),
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     keyboardType: TextInputType.number,
                  //   ),
                  // ),
                  if (containsMap(
                      currentUser.seenTVShows, ['TVShows', widget.tvshow.id]))
                    ExpansionTile(
                      title: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text(
                            "Watching History",
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
                        // if ((snapshot.data!['seen_dates'] as List).isNotEmpty)
                        //   Padding(
                        //     padding: const EdgeInsets.all(12.0),
                        //     child: Row(
                        //       children: [
                        //         const SizedBox(
                        //             width: 16), // Added margin to the left
                        //         const Icon(Icons.access_time,
                        //             color: Colors.green),
                        //         const SizedBox(width: 8),
                        //         Text(
                        //           "Last watched: ${intl.DateFormat('dd MMMM, yyyy').format(DateTime.parse(snapshot.data!['seen_dates'][0][0]))}",
                        //           style: const TextStyle(
                        //               fontSize: 16,
                        //               fontWeight: FontWeight.bold,
                        //               color: Colors.green),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // Rest of the dates in a smaller font

                        FutureBuilder(
                          future: Future.wait(
                            currentUser.seenWith.entries
                                .where((entry) =>
                                    entry.value["TVShows"]?.contains(
                                        widget.tvshow.id.toString()) ??
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
                              // Now you have a list of DocumentSnapshots for each friend who watched the movie
                              return GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(), // to disable GridView's scrolling
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
                                        // Navigate to Profile Page
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
                                                    // ... other text elements if needed ...
                                                  ],
                                                ),
                                              ),
                                              // IconButton(
                                              //   icon: Icon(
                                              //       Icons
                                              //           .remove_circle_outline_outlined,
                                              //       color: Colors.red),
                                              //   onPressed: () async {},
                                              // ),
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
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                Map<String, bool> selectedFriends =
                                    {}; // Maps friend UID to selection status
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title:
                                          const Text('Add Friends Who Watched'),
                                      content: SizedBox(
                                        height:
                                            250, // Set your desired height here
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: List.generate(
                                              currentUser.friends.length,
                                              (friendIndex) {
                                                return FutureBuilder<
                                                    DocumentSnapshot>(
                                                  future: FirebaseFirestore
                                                      .instance
                                                      .collection(currentUser
                                                          .friends[friendIndex])
                                                      .doc('Settings')
                                                      .get(),
                                                  builder: (context, snapshot) {
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
                                                      var data =
                                                          snapshot.data!.data()
                                                              as Map<String,
                                                                  dynamic>;
                                                      String userName =
                                                          data['username'] ??
                                                              '';
                                                      String profilePath = data[
                                                              'profile_photo'] ??
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
                                                                      width: 25,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    )
                                                                  : Image.asset(
                                                                      'assets/main_profile.png',
                                                                      height:
                                                                          25,
                                                                      width: 25,
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                            ),
                                                            const SizedBox(
                                                                width: 16.0),
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
                                                            selectedFriends[currentUser
                                                                        .friends[
                                                                    friendIndex]] =
                                                                value!;
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
                                            String id =
                                                widget.tvshow.id.toString();
                                            FirebaseFirestore firestore =
                                                FirebaseFirestore.instance;
                                            for (String friend
                                                in selectedFriends.keys
                                                    .toList()) {
                                              var userDoc = FirebaseFirestore
                                                  .instance
                                                  .collection(friend)
                                                  .doc("TVShows");
                                              await userDoc.update({
                                                'Seen':
                                                    FieldValue.arrayUnion([id])
                                              });
                                              if (currentUser.seenWith
                                                      .containsKey(friend) &&
                                                  !currentUser.seenWith[friend]
                                                          ["TVShows"]
                                                      .contains(
                                                          id.toString())) {
                                                currentUser.seenWith[friend]
                                                        ["TVShows"]
                                                    .add(id.toString());
                                              } else if (!currentUser.seenWith
                                                  .containsKey(friend)) {
                                                currentUser.seenWith[friend] = {
                                                  "Movies": [],
                                                  "TVShows": []
                                                };
                                                currentUser.seenWith[friend]
                                                        ["TVShows"]
                                                    .add(id.toString());
                                              }
                                              DocumentReference userDoc2 =
                                                  firestore
                                                      .collection(friend)
                                                      .doc("SeenWith");
                                              Map<String, dynamic> item = {};
                                              List<dynamic> watchedWithList = [
                                                currentUser.uid
                                              ];
                                              item[id] = watchedWithList;
                                              await firestore.runTransaction(
                                                  (transaction) async {
                                                // Get the document snapshot
                                                DocumentSnapshot snapshot =
                                                    await transaction
                                                        .get(userDoc2);

                                                if (!snapshot.exists) {
                                                  throw Exception(
                                                      "Document does not exist!");
                                                }

                                                Map<String, dynamic> data =
                                                    snapshot.data()
                                                        as Map<String, dynamic>;

                                                if (data.containsKey(
                                                        'TVShows') &&
                                                    data['TVShows'] is Map<
                                                        String, dynamic>) {
                                                  Map<String, dynamic>
                                                      moviesMap =
                                                      data['TVShows'];

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
                                                    transaction.update(userDoc2,
                                                        {"TVShows": moviesMap});
                                                  } else {
                                                    moviesMap[id] = {
                                                      "friends": watchedWithList
                                                    };
                                                    transaction.update(userDoc2,
                                                        {"TVShows": moviesMap});
                                                  }
                                                } else {
                                                  transaction.set(
                                                      userDoc2,
                                                      {
                                                        'TVShows': {
                                                          id: {
                                                            "friends":
                                                                watchedWithList
                                                          }
                                                        }
                                                      },
                                                      SetOptions(merge: true));
                                                }
                                              }).catchError((error) {
                                                print(
                                                    "Failed to update document: $error");
                                              });
                                            }
                                            DocumentReference userDoc2 =
                                                firestore
                                                    .collection(currentUser.uid)
                                                    .doc("SeenWith");

                                            Map<String, dynamic> item = {};
                                            List<dynamic> watchedWithList =
                                                selectedFriends.keys
                                                    .where((key) =>
                                                        selectedFriends[key] ==
                                                        true)
                                                    .toList();
                                            item[id] = watchedWithList;
                                            firestore.runTransaction(
                                                (transaction) async {
                                              // Get the document snapshot
                                              DocumentSnapshot snapshot =
                                                  await transaction
                                                      .get(userDoc2);

                                              if (!snapshot.exists) {
                                                throw Exception(
                                                    "Document does not exist!");
                                              }

                                              // Get the current data
                                              Map<String, dynamic> data =
                                                  snapshot.data()
                                                      as Map<String, dynamic>;

                                              // Check if 'Movies' map exists and if the 'id' is already a key in the 'Movies' map
                                              if (data.containsKey('TVShows') &&
                                                  data['TVShows']
                                                      is Map<String, dynamic>) {
                                                Map<String, dynamic> moviesMap =
                                                    data['TVShows'];

                                                // Check if the 'id' already exists in the 'Movies' map
                                                if (moviesMap.containsKey(id)) {
                                                  // If it exists, append the new list to the existing one
                                                  List existingList =
                                                      moviesMap[id]["friends"];
                                                  for (String person
                                                      in watchedWithList) {
                                                    if (!existingList
                                                        .contains(person)) {
                                                      existingList.add(person);
                                                    }
                                                  }
                                                  moviesMap[id] = {
                                                    "friends": existingList
                                                  };
                                                } else {
                                                  // If the 'id' doesn't exist, add the new key-value pair
                                                  moviesMap[id] = {
                                                    "friends": watchedWithList
                                                  };
                                                }
                                                // Update the 'Movies' map
                                                transaction.update(userDoc2,
                                                    {'TVShows': moviesMap});
                                              } else {
                                                // If 'Movies' map doesn't exist, create it and add the 'id' and list
                                                transaction.set(
                                                    userDoc2,
                                                    {
                                                      'TVShows': {
                                                        id: {
                                                          "friends":
                                                              watchedWithList
                                                        }
                                                      }
                                                    },
                                                    SetOptions(merge: true));
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
                          height: 10,
                        ),
                      ],
                    ),

                  const Row(
                    children: [],
                  ),
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0.0, 5.0),
                        child: const Text(
                          "Main Cast:",
                          style: TextStyle(fontSize: 18),
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
                                  personResult = person;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PersonResult()),
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
                                    const SizedBox(
                                        height:
                                            10), // optional: to give some space between image and text
                                    Text(
                                      '${person["name"]}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '(${person["character"]})',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Container(
                      //   width: MediaQuery.of(context).size.width,
                      //   margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0, 5.0),
                      //   child: const Text(
                      //     "Main Crew:",
                      //     style: TextStyle(fontSize: 18),
                      //   ),
                      // ),
                      // Container(
                      //   width: MediaQuery.of(context).size.width * 1,
                      //   height: 100,
                      //   margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
                      //   child: ListView.builder(
                      //     scrollDirection: Axis.vertical,
                      //     itemCount: snapshot.data!['crew'].length < 5
                      //         ? snapshot.data!['crew'].length
                      //         : 5,
                      //     itemBuilder: (BuildContext context, int index) {
                      //       Map person = snapshot.data!['crew'][index];
                      //       return Text(
                      //         "${person['job']}: ${person['name']}",
                      //         style: const TextStyle(fontSize: 15),
                      //       );
                      //     },
                      //   ),
                      // ),
                    ],
                  ),
                  Builder(
                    builder: (BuildContext context) {
                      try {
                        // Widget tree that may throw an exception
                        return Container(
                          // fixed height
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
                        // Handle the exception
                        return Center(
                          child: Text('An error occurred: $e'),
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
