import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

int scoreActor = 0;
int scoreDirector = 0;
int stats = 0;
int stats_tv = 0;
int allDirMovies = 0;
int stats_dir = 0;
List countedMoviesDirector = [];
List countedMoviesActor = [];
List countedTVShowsDirector = [];
List countedTVShowsActor = [];

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class PersonResult extends StatefulWidget {
  const PersonResult({super.key});

  @override
  _PersonResultState createState() => _PersonResultState();
}

class _PersonResultState extends State<PersonResult> {
  Map presult = personResult;
  Future<Map> getPersonData() async {
    Map json = {};
    String name = presult['name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
        .replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$PERSON_LINK${presult["id"]}-$name$API_KEY'));
    json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final r2 = await http.get(
          Uri.parse('$PERSON_LINK${presult["id"]}-$name$MOVIE_CREDITS_LINK'));
      if (r2.statusCode == 200) {
        List movieCast = [];
        for (Map movie in jsonDecode(r2.body)['cast']) {
          if (movie["poster_path"] != null) {
            if (!movie["character"].toString().toLowerCase().contains("self") &&
                !movie["character"]
                    .toString()
                    .toLowerCase()
                    .contains("archived") &&
                !movie["character"]
                    .toString()
                    .toLowerCase()
                    .contains("uncredited") &&
                movie["character"].toString() != "") {
              movieCast.add(movie);
            }
          }
        }
        json['movie_credits_cast'] = movieCast;
        for (var element in movieCast) {
          if (containsMap(currentUser.seenMovies, ["Movies", element["id"]])) {
            if (!countedMoviesActor.contains(element["id"].toString())) {
              stats += 1;
              if (containsMap(currentUser.favMovies,
                  ['Movies', element["id"].toString()])) {
                scoreActor += 3;
              }
              if (currentUser.rewatchedMovies.keys
                  .toList()
                  .contains(element["id"].toString())) {
                scoreActor += currentUser
                    .rewatchedMovies[element["id"].toString()] as int;
              } else {
                scoreActor += 2;
              }
              countedMoviesActor.add(element["id"].toString());
            }
          } else if (containsMap(currentUser.watchlist,
                  ['Movies', element["id"].toString()]) &&
              !countedMoviesActor.contains(element["id"].toString())) {
            scoreActor += 1;
            countedMoviesActor.add(element["id"].toString());
          }
        }
        final r3 = await http.get(Uri.parse(
            '$PERSON_LINK${presult["id"]}-$name$TV_SHOW_CREDITS_LINK'));
        if (r3.statusCode == 200) {
          List tvCast = [];
          for (Map show in jsonDecode(r3.body)['cast']) {
            if (show["poster_path"] != null) {
              if (!show["character"]
                      .toString()
                      .toLowerCase()
                      .contains("self") &&
                  show["character"].toString() != "") {
                tvCast.add(show);
              }
            }
          }
          json['tv_credits_cast'] = tvCast;
          for (var element in tvCast) {
            if (containsMap(
                currentUser.seenTVShows, ["TVShows", element["id"]])) {
              if (!countedTVShowsActor.contains(element["id"].toString())) {
                stats_tv += 1;
                if (containsMap(currentUser.favTVShows,
                    ['TVShows', element["id"].toString()])) {
                  scoreActor += 3;
                } else {
                  scoreActor += 2;
                }
                countedTVShowsActor.add(element["id"].toString());
              }
            } else if (containsMap(currentUser.watchlistTVShows,
                    ['TVShows', element["id"].toString()]) &&
                !countedTVShowsActor.contains(element["id"].toString())) {
              scoreActor += 1;
              countedTVShowsActor.add(element["id"].toString());
            }
          }
        } else {
          throw Exception('Failed to load movie details');
        }
        List movieCrew = [];
        for (Map movie in jsonDecode(r2.body)['crew']) {
          if (movie["poster_path"] != null && movie["job"] != "Thanks") {
            movieCrew.add(movie);
          }
        }
        json['movie_credits_crew'] = movieCrew;
        for (var element in movieCrew) {
          if (containsMap(
              currentUser.seenMovies, ["Movies", element["id"].toString()])) {
            if (element["job"] == "Director" &&
                !countedMoviesDirector.contains(element["id"].toString())) {
              stats_dir += 1;
              if (containsMap(currentUser.favMovies,
                  ['Movies', element["id"].toString()])) {
                scoreDirector += 3;
              }
              if (currentUser.rewatchedMovies.keys
                  .toList()
                  .contains(element["id"])) {
                scoreDirector += int.parse(
                    currentUser.rewatchedMovies[element["id"].toString()]);
              } else {
                scoreDirector += 2;
              }
              countedMoviesDirector.add(element["id"].toString());
            }
          } else if (containsMap(currentUser.watchlist,
                  ['Movies', element["id"].toString()]) &&
              element["job"] == "Director" &&
              !countedMoviesDirector.contains(element["id"].toString())) {
            scoreDirector += 1;
            countedMoviesDirector.add(element["id"].toString());
          }
          if (element["job"] == "Director") {
            allDirMovies += 1;
          }
        }
        final r4 = await http.get(Uri.parse(
            '$PERSON_LINK${presult["id"]}-$name$TV_SHOW_CREDITS_LINK'));
        if (r4.statusCode == 200) {
          List tvCrew = [];
          for (Map show in jsonDecode(r4.body)['crew']) {
            if (show["poster_path"] != null) {
              tvCrew.add(show);
            }
          }
          json['tv_credits_crew'] = tvCrew;
          for (var element in tvCrew) {
            if (containsMap(currentUser.seenTVShows,
                ["TVShows", element["id"].toString()])) {
              if (element["job"] == "Director" &&
                  !countedTVShowsDirector.contains(element["id"].toString())) {
                stats_dir += 1;
                if (containsMap(currentUser.favTVShows,
                    ['TVShows', element["id"].toString()])) {
                  scoreDirector += 3;
                } else {
                  scoreDirector += 1;
                }
                countedTVShowsDirector.add(element["id"].toString());
              }
            } else if (containsMap(currentUser.watchlistTVShows,
                    ['TVShows', element["id"].toString()]) &&
                element["job"] == "Director" &&
                !countedTVShowsDirector.contains(element["id"].toString())) {
              scoreDirector += 1;
              countedTVShowsDirector.add(element["id"].toString());
            }

            if (element["job"] == "Director") {
              allDirMovies += 1;
            }
          }
          if (oscars.keys.contains(presult["id"])) {
            json['num_oscars'] = oscars[presult["id"]]['num_oscars'];
          } else {
            json['num_oscars'] = 0;
          }
          var userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("FavDirectors");
          Map<Object, Object?> directorStats = {};
          directorStats[personResult['id'].toString()] = scoreDirector;
          await userDoc.update(directorStats);
          await userDoc.get().then((DocumentSnapshot doc) async {
            Map info = doc.data() as Map;
            List actrs = [];
            info.forEach((key, value) {
              List item = [value, key];
              actrs.add(item);
            });
            actrs.sort((a, b) => a[0].compareTo(b[0]));
            actrs = actrs.reversed.toList();
            int num = 0;
            for (var act in actrs) {
              num++;
              if (act[1].toString() == presult["id"].toString()) {
                break;
              }
            }
            json["director_ranking"] = num;
            json["allDirMovies"] = allDirMovies;
          });
          var ActorDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("FavActors");
          Map<Object, Object?> actorStats = {};
          actorStats[personResult['id'].toString()] = scoreActor;
          await ActorDoc.update(actorStats);
          await ActorDoc.get().then((DocumentSnapshot doc) async {
            Map info = doc.data() as Map;
            List actrs = [];
            info.forEach((key, value) {
              List item = [value, key];
              actrs.add(item);
            });
            actrs.sort((a, b) => a[0].compareTo(b[0]));
            actrs = actrs.reversed.toList();
            int num = 0;
            for (var act in actrs) {
              num++;
              if (act[1].toString() == presult["id"].toString()) {
                break;
              }
            }
            json["actor_ranking"] = num;
          });
          currentUser.favActors = [];
          currentUser.favDirectors = [];
          await FirebaseFirestore.instance
              .collection(currentUser.uid)
              .get()
              .then((QuerySnapshot querySnapshot) {
            for (var doc in querySnapshot.docs) {
              if (doc.id == "FavActors" && currentUser.favActors.isEmpty) {
                Map tempFavActors = doc.data() as Map;
                currentUser.favActors = tempFavActors.entries
                    .map((entry) => [entry.value, entry.key])
                    .toList();
                currentUser.favActors.sort((a, b) => b[0].compareTo(a[0]));
              } else if (doc.id == "FavDirectors" &&
                  currentUser.favDirectors.isEmpty) {
                Map tempFavDirectors = doc.data() as Map;
                currentUser.favDirectors = tempFavDirectors.entries
                    .map((entry) => [entry.value, entry.key])
                    .toList();
                currentUser.favDirectors.sort((a, b) => b[0].compareTo(a[0]));
              }
            }
          });
          return json;
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

  @override
  Widget build(BuildContext context) {
    scoreActor = 0;
    stats = 0;
    stats_tv = 0;
    stats_dir = 0;
    allDirMovies = 0;
    scoreDirector = 0;
    countedMoviesDirector = [];
    countedMoviesActor = [];

    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: getPersonData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.data!['num_oscars'] != 0)
                    Center(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.06,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              snapshot.data!['num_oscars'],
                              (index) => SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.06,
                                child: Image.asset("assets/oscar2.png"),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: MediaQuery.of(context).size.width * 0.55,
                      margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: 1,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              //
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.1,
                              height: MediaQuery.of(context).size.height * 0.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                image: DecorationImage(
                                  image: NetworkImage(IMG_LINK +
                                      snapshot.data!['profile_path']),
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      snapshot.data!['name'],
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  ExpansionTile(
                      title: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Your Statistics"),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 25),
                          child: Column(
                            children: [
                              Text(
                                "Actor ranking: #${snapshot.data!['actor_ranking']} ($scoreActor)",
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (allDirMovies != 0)
                                Text(
                                  "Director ranking: #${snapshot.data!['director_ranking']} ($scoreDirector)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Text(
                                  "Actor Movie Progress: $stats / ${(snapshot.data!['movie_credits_cast'].length)} (${double.parse((stats / (snapshot.data!['movie_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats /
                                        (snapshot.data!['movie_credits_cast']
                                            .length),
                                  ),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Text(
                                  "Actor TV Show Progress: $stats_tv / ${(snapshot.data!['tv_credits_cast'].length)} (${double.parse((stats_tv / (snapshot.data!['tv_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats_tv /
                                        (snapshot
                                            .data!['tv_credits_cast'].length),
                                  ),
                                ),
                              if (allDirMovies != 0)
                                Text(
                                  "Director Progress: $stats_dir / ${(snapshot.data!['allDirMovies'])} (${double.parse((stats_dir / (snapshot.data!['allDirMovies']) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (allDirMovies != 0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: stats_dir /
                                        (snapshot.data!['allDirMovies']),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                  if (snapshot.data!['movie_credits_crew'].length != 0 &&
                      snapshot.data!["movie_credits_cast"].length != 0)
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: 'As Part of the Cast'),
                              Tab(text: 'As Part of the Crew'),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.46,
                            child: TabBarView(
                              children: [
                                cast(context, snapshot.data),
                                crew(context, snapshot.data)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (snapshot.data!['movie_credits_crew'].length == 0 &&
                      snapshot.data!["movie_credits_cast"].length != 0)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: cast(context, snapshot.data),
                    ),
                  if (snapshot.data!['movie_credits_crew'].length != 0 &&
                      snapshot.data!["movie_credits_cast"].length == 0)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: crew(context, snapshot.data),
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

  Widget buildMediaRow(BuildContext context, List<dynamic> mediaList, int index,
      String mediaType, bool isCrew) {
    int leftIndex = index * 3;
    int middleIndex = index * 3 + 1;
    int rightIndex = index * 3 + 2;

    Widget buildMediaItem(dynamic media) {
      if (media == null || media["poster_path"] == null) return Container();

      return GestureDetector(
        onTap: () {
          var route;
          if (mediaType == 'Movies') {
            var tempMovie = Movie(
                id: media['id'],
                title: media['title'],
                coverPhoto: media['poster_path']);
            route = MaterialPageRoute(
                builder: (context) => MovieResult(movie: tempMovie));
          } else {
            var tempTvShow = TVShow(
                id: media['id'],
                title: media['name'],
                coverPhoto: media['poster_photo']);
            route = MaterialPageRoute(
                builder: (context) => TVShowResult(tvshow: tempTvShow));
          }
          Navigator.push(context, route);
        },
        child: isCrew
            ? seenCrew(context, media, mediaType)
            : seen(context, media, mediaType),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (leftIndex < mediaList.length) buildMediaItem(mediaList[leftIndex]),
        if (middleIndex < mediaList.length)
          buildMediaItem(mediaList[middleIndex]),
        if (rightIndex < mediaList.length)
          buildMediaItem(mediaList[rightIndex]),
      ],
    );
  }

  cast(BuildContext context, data) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // TabBar code
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: (data['movie_credits_cast'].length / 3).ceil(),
                  itemBuilder: (context, index) => buildMediaRow(context,
                      data['movie_credits_cast'], index, "Movies", false),
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: (data['tv_credits_cast'].length / 3).ceil(),
                  itemBuilder: (context, index) => buildMediaRow(context,
                      data['tv_credits_cast'], index, "TVShows", false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  crew(BuildContext context, data) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // TabBar code
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: (data['movie_credits_cast'].length / 3).ceil(),
                  itemBuilder: (context, index) => buildMediaRow(context,
                      data['movie_credits_cast'], index, "Movies", true),
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: (data['tv_credits_cast'].length / 3).ceil(),
                  itemBuilder: (context, index) => buildMediaRow(
                      context, data['tv_credits_cast'], index, "TVShows", true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool containsMap(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]).toString() == map[0].toString()) {
        return true;
      }
    }
    return false;
  }

  seen(BuildContext context, movie, type) {
    if (!containsMap(currentUser.seenMovies, [type, movie['id']]) &&
        !containsMap(currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
                  const Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  seenCrew(BuildContext context, movie, type) {
    if (!containsMap(currentUser.seenMovies, [type, movie['id']]) &&
        !containsMap(currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.75),
                  const Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}
