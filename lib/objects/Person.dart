import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/objects/User.dart';
import 'dart:convert';

import '../common/constants.dart';
import '../common/utils.dart';

class Person {
  final String name;
  final String id;
  final Map data;
  Map personStats = {};

  Person({
    required this.id,
    required this.name,
    required this.data,
  });

  Future<Map> getSimpleData() async {
    final response =
              await http.get(Uri.parse('$PERSON_LINK$id$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['profile_path'] == null) {
        json['profile_path'] =
            'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
      } else {
        json['profile_path'] = IMG_LINK + json['profile_path'];
      }
      return json;
    } else {
      throw Exception('Failed to load director details');
    }
  }

  Future<Map> getPersonData(AppUser currentUser, Map oscars) async {
    int scoreActor = 0;
    int scoreDirector = 0;
    int stats = 0;
    int statsTv = 0;
    int allDirMovies = 0;
    int statsDir = 0;
    List countedMoviesDirector = [];
    List countedMoviesActor = [];
    List countedTVShowsDirector = [];
    List countedTVShowsActor = [];
    Map json = {};
    String formattedName =
        name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "-");
    final response =
        await http.get(Uri.parse('$PERSON_LINK$id-$formattedName$API_KEY'));
    json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final r2 = await http
          .get(Uri.parse('$PERSON_LINK$id-$formattedName$MOVIE_CREDITS_LINK'));
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
          if (Utils.contains_non_type(
              currentUser.seenMovies, ["Movies", element["id"]])) {
            if (!countedMoviesActor.contains(element["id"].toString())) {
              stats += 1;
              if (Utils.contains_non_type(currentUser.favMovies,
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
          } else if (Utils.contains_non_type(currentUser.watchlist,
                  ['Movies', element["id"].toString()]) &&
              !countedMoviesActor.contains(element["id"].toString())) {
            scoreActor += 1;
            countedMoviesActor.add(element["id"].toString());
          }
        }
        final r3 = await http.get(
            Uri.parse('$PERSON_LINK$id-$formattedName$TV_SHOW_CREDITS_LINK'));
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
            if (Utils.contains_non_type(
                currentUser.seenTVShows, ["TVShows", element["id"]])) {
              if (!countedTVShowsActor.contains(element["id"].toString())) {
                statsTv += 1;
                if (Utils.contains_non_type(currentUser.favTVShows,
                    ['TVShows', element["id"].toString()])) {
                  scoreActor += 3;
                } else {
                  scoreActor += 2;
                }
                countedTVShowsActor.add(element["id"].toString());
              }
            } else if (Utils.contains_non_type(currentUser.watchlistTVShows,
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
          if (Utils.contains_non_type(
              currentUser.seenMovies, ["Movies", element["id"].toString()])) {
            if (element["job"] == "Director" &&
                !countedMoviesDirector.contains(element["id"].toString())) {
              statsDir += 1;
              if (Utils.contains_non_type(currentUser.favMovies,
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
          } else if (Utils.contains_non_type(currentUser.watchlist,
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
        final r4 = await http.get(
            Uri.parse('$PERSON_LINK$id-$formattedName$TV_SHOW_CREDITS_LINK'));
        if (r4.statusCode == 200) {
          List tvCrew = [];
          for (Map show in jsonDecode(r4.body)['crew']) {
            if (show["poster_path"] != null) {
              tvCrew.add(show);
            }
          }
          json['tv_credits_crew'] = tvCrew;
          for (var element in tvCrew) {
            if (Utils.contains_non_type(currentUser.seenTVShows,
                ["TVShows", element["id"].toString()])) {
              if (element["job"] == "Director" &&
                  !countedTVShowsDirector.contains(element["id"].toString())) {
                statsDir += 1;
                if (Utils.contains_non_type(currentUser.favTVShows,
                    ['TVShows', element["id"].toString()])) {
                  scoreDirector += 3;
                } else {
                  scoreDirector += 1;
                }
                countedTVShowsDirector.add(element["id"].toString());
              }
            } else if (Utils.contains_non_type(currentUser.watchlistTVShows,
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
          if (oscars.keys.contains(id.toString())) {
            json['num_oscars'] = oscars[id.toString()]['num_oscars'];
          } else {
            json['num_oscars'] = 0;
          }
          var userDoc = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("FavDirectors");
          Map<Object, Object?> directorStats = {};
          directorStats[id.toString()] = scoreDirector;
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
              if (act[1].toString() == id.toString()) {
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
          actorStats[id.toString()] = scoreActor;
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
              if (act[1].toString() == id.toString()) {
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
          personStats["scoreActor"] = scoreActor;
          personStats["scoreDirector"] = scoreDirector;
          personStats["stats"] = stats;
          personStats["stats_tv"] = statsTv;
          personStats["stats_dir"] = statsDir;
          personStats["allDirMovies"] = allDirMovies;
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
}
