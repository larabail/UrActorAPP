import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'profile.dart';
import 'search.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'playlists.dart';
import 'package:flutter/services.dart' show rootBundle;

final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
final String imgLink = 'https://image.tmdb.org/t/p/w500/';
String api_key_movie =
    '/movie_credits?api_key=700cd4fab994df56eb41b34d38c4762a';
String api_key_tv = '/tv_credits?api_key=700cd4fab994df56eb41b34d38c4762a';
String link = "https://api.themoviedb.org/3/person/";
int scoreActor = 0;
int scoreDirector = 0;
List countedMoviesDirector = [];
List countedMoviesActor = [];
List countedTVShowsDirector = [];
List countedTVShowsActor = [];

Future<String> _loadJSONFile() async {
  return await rootBundle.loadString('assets/oscars_api.json');
}

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
  PersonResult();

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
        await http.get(Uri.parse('$link${presult["id"]}-$name$api_key_actor'));
    json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final r2 = await http
          .get(Uri.parse('$link${presult["id"]}-$name$api_key_movie'));
      if (r2.statusCode == 200) {
        List movie_cast = [];
        for (Map movie in jsonDecode(r2.body)['cast']) {
          if (movie["poster_path"] != null) {
            movie_cast.add(movie);
          }
        }
        json['movie_credits_cast'] = movie_cast;
        movie_cast.forEach((element) {
          if (containsMap(seenMovies, ["Movies", element["id"]])) {
            if (personResult["known_for_department"] == "Acting" &&
                !countedMoviesActor.contains(element["id"].toString())) {
              if (containsMap(
                  favMovies, ['Movies', element["id"].toString()])) {
                scoreActor += 3;
              }
              if (rewatchedMovies.keys.toList().contains(element["id"])) {
                scoreActor +=
                    int.parse(rewatchedMovies[element["id"].toString()]);
              } else {
                scoreActor += 1;
              }
              countedMoviesActor.add(element["id"].toString());
            }
          }
        });
        final r3 =
            await http.get(Uri.parse('$link${presult["id"]}-$name$api_key_tv'));
        if (r3.statusCode == 200) {
          List tv_cast = [];
          for (Map show in jsonDecode(r3.body)['cast']) {
            if (show["poster_path"] != null) {
              tv_cast.add(show);
            }
          }
          json['tv_credits_cast'] = tv_cast;
          tv_cast.forEach((element) {
            if (containsMap(seenTVShows, ["TVShows", element["id"]])) {
              if (personResult["known_for_department"] == "Acting" &&
                  !countedTVShowsActor.contains(element["id"].toString())) {
                if (containsMap(
                    favTVShows, ['Movies', element["id"].toString()])) {
                  scoreActor += 3;
                } else {
                  scoreActor += 1;
                }
                countedTVShowsActor.add(element["id"].toString());
              }
            }
          });
        } else {
          throw Exception('Failed to load movie details');
        }
        List movie_crew = [];
        for (Map movie in jsonDecode(r2.body)['crew']) {
          if (movie["poster_path"] != null && movie["job"] != "Thanks") {
            movie_crew.add(movie);
          }
        }
        json['movie_credits_crew'] = movie_crew;
        movie_crew.forEach((element) {
          if (containsMap(seenMovies, ["Movies", element["id"]])) {
            if (element["job"] == "Director" &&
                !countedMoviesDirector.contains(element["id"].toString())) {
              if (containsMap(
                  favMovies, ['Movies', element["id"].toString()])) {
                scoreDirector += 3;
              }
              if (rewatchedMovies.keys.toList().contains(element["id"])) {
                scoreDirector +=
                    int.parse(rewatchedMovies[element["id"].toString()]);
              } else {
                scoreDirector += 1;
              }
              countedMoviesDirector.add(element["id"].toString());
            }
          }
        });
        final r4 =
            await http.get(Uri.parse('$link${presult["id"]}-$name$api_key_tv'));
        if (r4.statusCode == 200) {
          List tv_crew = [];
          for (Map show in jsonDecode(r4.body)['crew']) {
            if (show["poster_path"] != null) {
              tv_crew.add(show);
            }
          }
          json['tv_credits_crew'] = tv_crew;
          tv_crew.forEach((element) {
            if (containsMap(seenTVShows, ["TVShows", element["id"]])) {
              if (element["job"] == "Director" &&
                  !countedTVShowsDirector.contains(element["id"].toString())) {
                if (containsMap(
                    favTVShows, ['Movies', element["id"].toString()])) {
                  scoreDirector += 3;
                } else {
                  scoreDirector += 1;
                }
                countedTVShowsDirector.add(element["id"].toString());
              }
            }
          });
          // Map oscars = await parseJSONFile();
          if (oscars.keys.contains(presult["id"])) {
            json['num_oscars'] = oscars[presult["id"]]['num_oscars'];
          } else {
            json['num_oscars'] = 0;
          }
          print(scoreActor);
          print(scoreDirector);
          var userDoc =
              FirebaseFirestore.instance.collection(uid).doc("FavDirectors");
          Map<Object, Object?> directorStats = {};
          directorStats[personResult['id'].toString()] = scoreDirector;
          await userDoc.update(directorStats);
          var ActorDoc =
              FirebaseFirestore.instance.collection(uid).doc("FavActors");
          Map<Object, Object?> actorStats = {};
          actorStats[personResult['id'].toString()] = scoreActor;
          await ActorDoc.update(actorStats);
          favActors = [];
          favDirectors = [];
          await FirebaseFirestore.instance
              .collection(uid)
              .get()
              .then((QuerySnapshot querySnapshot) {
            for (var doc in querySnapshot.docs) {
              if (doc.id == "FavActors" && favActors.isEmpty) {
                Map tempFavActors = doc.data() as Map;
                favActors = tempFavActors.entries
                    .map((entry) => [entry.value, entry.key])
                    .toList();
                favActors.sort((a, b) => b[0].compareTo(a[0]));
              } else if (doc.id == "FavDirectors" && favDirectors.isEmpty) {
                Map tempFavDirectors = doc.data() as Map;
                favDirectors = tempFavDirectors.entries
                    .map((entry) => [entry.value, entry.key])
                    .toList();
                favDirectors.sort((a, b) => b[0].compareTo(a[0]));
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
    scoreDirector = 0;
    countedMoviesDirector = [];
    countedMoviesActor = [];
    int selectedIndex = 0;

    final List<Widget> pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
            child: Image.asset(
          'assets/logo_character.png',
          height: 54,
        )),
      ),
      body: FutureBuilder<Map>(
        future: getPersonData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.data!['num_oscars'] != 0)
                    Center(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.075,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              snapshot.data!['num_oscars'],
                              (index) => Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.075,
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
                              width: MediaQuery.of(context).size.width * 0.18,
                              height: MediaQuery.of(context).size.height * 0.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                image: DecorationImage(
                                  image: NetworkImage(
                                      imgLink + snapshot.data!['profile_path']),
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
                              DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    const TabBar(
                                      tabs: [
                                        Tab(text: 'Movies'),
                                        Tab(text: 'TV Shows'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'movie_credits_cast']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie = (middleMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [middleMovieIndex]
                                                  : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_cast']
                                                      [rightMovieIndex]
                                                  : null;
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null &&
                                                      leftMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          leftMovie['id'],
                                                          leftMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          leftMovie, "Movies"),
                                                    ),
                                                  if (middleMovie != null &&
                                                      middleMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          middleMovie['id'],
                                                          middleMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          middleMovie,
                                                          "Movies"),
                                                    ),
                                                  if (rightMovie != null &&
                                                      rightMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          rightMovie['id'],
                                                          rightMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          rightMovie, "Movies"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'tv_credits_cast']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_cast']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie =
                                                  (middleMovieIndex <
                                                          snapshot
                                                              .data![
                                                                  'tv_credits_cast']
                                                              .length)
                                                      ? snapshot.data![
                                                              'tv_credits_cast']
                                                          [middleMovieIndex]
                                                      : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_cast']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_cast']
                                                      [rightMovieIndex]
                                                  : null;
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null &&
                                                      leftMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          leftMovie['id'],
                                                          leftMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(context,
                                                          leftMovie, "TVShows"),
                                                    ),
                                                  if (middleMovie != null &&
                                                      middleMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          middleMovie['id'],
                                                          middleMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          middleMovie,
                                                          "TVShows"),
                                                    ),
                                                  if (rightMovie != null &&
                                                      rightMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          rightMovie['id'],
                                                          rightMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seen(
                                                          context,
                                                          rightMovie,
                                                          "TVShows"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    const TabBar(
                                      tabs: [
                                        Tab(text: 'Movies'),
                                        Tab(text: 'TV Shows'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'movie_credits_crew']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie = (middleMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [middleMovieIndex]
                                                  : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'movie_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'movie_credits_crew']
                                                      [rightMovieIndex]
                                                  : null;
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null &&
                                                      leftMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          leftMovie['id'],
                                                          leftMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          leftMovie, "Movies"),
                                                    ),
                                                  if (middleMovie != null &&
                                                      middleMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          middleMovie['id'],
                                                          middleMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          middleMovie,
                                                          "Movies"),
                                                    ),
                                                  if (rightMovie != null &&
                                                      rightMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        movieResult = [
                                                          rightMovie['id'],
                                                          rightMovie['title'],
                                                          "Movies",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  MovieResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          rightMovie, "Movies"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          ListView.builder(
                                            scrollDirection: Axis.vertical,
                                            itemCount: (snapshot
                                                        .data![
                                                            'tv_credits_crew']
                                                        .length /
                                                    3)
                                                .ceil(),
                                            itemBuilder: (context, index) {
                                              final leftMovieIndex = index * 3;
                                              final middleMovieIndex =
                                                  index * 3 + 1;
                                              final rightMovieIndex =
                                                  index * 3 + 2;
                                              final leftMovie = (leftMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_crew']
                                                      [leftMovieIndex]
                                                  : null;
                                              final middleMovie =
                                                  (middleMovieIndex <
                                                          snapshot
                                                              .data![
                                                                  'tv_credits_crew']
                                                              .length)
                                                      ? snapshot.data![
                                                              'tv_credits_crew']
                                                          [middleMovieIndex]
                                                      : null;
                                              final rightMovie = (rightMovieIndex <
                                                      snapshot
                                                          .data![
                                                              'tv_credits_crew']
                                                          .length)
                                                  ? snapshot.data![
                                                          'tv_credits_crew']
                                                      [rightMovieIndex]
                                                  : null;
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  if (leftMovie != null &&
                                                      leftMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          leftMovie['id'],
                                                          leftMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(context,
                                                          leftMovie, "TVShows"),
                                                    ),
                                                  if (middleMovie != null &&
                                                      middleMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          middleMovie['id'],
                                                          middleMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          middleMovie,
                                                          "TVShows"),
                                                    ),
                                                  if (rightMovie != null &&
                                                      rightMovie[
                                                              "poster_path"] !=
                                                          null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        // Handle the click event here
                                                        tvShowResult = [
                                                          rightMovie['id'],
                                                          rightMovie['name'],
                                                          "TVShows",
                                                        ];
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  TVShowResult()),
                                                        );
                                                      },
                                                      child: seenCrew(
                                                          context,
                                                          rightMovie,
                                                          "TVShows"),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              label: 'Profile',
              icon: Icon(Icons.person),
            ),
          ],
          currentIndex: selectedIndex,
          onTap: _onItemTapped),
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
    if (!containsMap(seenMovies, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
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
                  child: Container(
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
                image: NetworkImage(imgLink + movie['poster_path']),
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
                  child: Container(
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
    if (!containsMap(seenMovies, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(imgLink + movie['poster_path']),
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
                  child: Container(
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
                image: NetworkImage(imgLink + movie['poster_path']),
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
                  child: Container(
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
