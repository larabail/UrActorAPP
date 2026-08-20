// ignore: file_names
// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/user.dart';
import 'dart:convert';

import '../common/constants.dart';
import '../common/firebase/firestore_core.dart';
import '../common/utils.dart';
import '../common/api/http_client.dart';

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
  final lang = currentUser.settings['language'] ?? 'en';

  Future<Map> getSimpleData() async {
    final response =
        await AppHttp.client.get(Uri.parse('$PERSON_LINK$id$API_KEY&language=$lang'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json;
    } else {
      throw Exception('Failed to load director details');
    }
  }

  Future<Map> getCastCredits() async {
    Map json = {};
    String formattedName =
        name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "-");
    final personResponse = await AppHttp.client.get(
        Uri.parse('$PERSON_LINK$id-$formattedName$API_KEY&language=$lang'));
    json = jsonDecode(personResponse.body);
    if (personResponse.statusCode == 200) {
      final movieCreditsResponse = await AppHttp.client.get(Uri.parse(
          '$PERSON_LINK$id-$formattedName$MOVIE_CREDITS_LINK&language=$lang'));
      if (movieCreditsResponse.statusCode == 200) {
        List movieCast = [];
        for (Map movie in jsonDecode(movieCreditsResponse.body)['cast']) {
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
        List movieCrew = [];
        for (Map movie in jsonDecode(movieCreditsResponse.body)['crew']) {
          if (movie["poster_path"] != null && movie["job"] != "Thanks") {
            movieCrew.add(movie);
          }
        }
        json['movie_credits_crew'] = movieCrew;
        json['movie_credits_cast'] = movieCast;
      }

      final tvCreditsResponse = await AppHttp.client.get(Uri.parse(
          '$PERSON_LINK$id-$formattedName$TV_SHOW_CREDITS_LINK&language=$lang'));
      if (tvCreditsResponse.statusCode == 200) {
        List tvCast = [];
        for (Map show in jsonDecode(tvCreditsResponse.body)['cast']) {
          if (show["poster_path"] != null) {
            if (!show["character"].toString().toLowerCase().contains("self") &&
                show["character"].toString() != "") {
              tvCast.add(show);
            }
          }
        }
        json['tv_credits_cast'] = tvCast;
        List tvCrew = [];
        for (Map show in jsonDecode(tvCreditsResponse.body)['crew']) {
          if (show["poster_path"] != null) {
            tvCrew.add(show);
          }
        }
        json['tv_credits_crew'] = tvCrew;
      }
    }
    return json;
  }

  Future<int> updateStatsDoc(int score, AppUser currentUser, docName) async {
    var ActorDoc =
        FirestoreCore.db.collection(currentUser.uid).doc(docName);
    Map<Object, Object?> actorStats = {};
    actorStats[id.toString()] = score;
    await FirestoreCore.updateDocument(currentUser.uid, docName, actorStats);
    var doc = await ActorDoc.get();
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
    return num;
  }

  Future<void> fetchNewStats(AppUser currentUser) async {
    currentUser.favActors = [];
    currentUser.favDirectors = [];
    currentUser.favWriters = [];
    await FirestoreCore.db
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
        } else if (doc.id == "FavWriters" && currentUser.favWriters.isEmpty) {
          Map tempFavWriters = doc.data() as Map;
          currentUser.favWriters = tempFavWriters.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          currentUser.favWriters.sort((a, b) => b[0].compareTo(a[0]));
        }
      }
    });
  }

  List getCastStats(AppUser currentUser, List cast, String type) {
    List counted = [];
    int stats = 0;
    int score = 0;
    List seen =
        type == "Movies" ? currentUser.seenMovies : currentUser.seenTVShows;
    List favs =
        type == "Movies" ? currentUser.favMovies : currentUser.favTVShows;
    List watchlist =
        type == "Movies" ? currentUser.watchlist : currentUser.watchlistTVShows;
    Map rewatched = type == "Movies"
        ? currentUser.rewatchedMovies
        : currentUser.rewatchedTVShows;
    for (var element in cast) {
      if (Utils.containsNonType(seen, [type, element["id"]])) {
        if (!counted.contains(element["id"].toString())) {
          stats += 1;
          if (Utils.containsNonType(favs, [type, element["id"].toString()])) {
            score += 3;
          }
          if (rewatched.keys.toList().contains(element["id"].toString())) {
            score += rewatched[element["id"].toString()] as int > 1
                ? rewatched[element["id"].toString()] as int
                : 2;
          } else {
            score += 2;
          }
          counted.add(element["id"].toString());
        }
      } else if (Utils.containsNonType(
              watchlist, [type, element["id"].toString()]) &&
          !counted.contains(element["id"].toString())) {
        score += 1;
        counted.add(element["id"].toString());
      }
    }

    return [score, stats];
  }

  List getCrewStats(AppUser currentUser, List crew, String type) {
    List countedTVShowsDirector = [];
    List countedTVShowsWriter = [];
    int scoreDirector = 0;
    int scoreWriter = 0;
    int statsWriterTV = 0;
    int statsDir = 0;
    List favs =
        type == "Movies" ? currentUser.favMovies : currentUser.favTVShows;
    List seen =
        type == "Movies" ? currentUser.seenMovies : currentUser.seenTVShows;
    List watchlist =
        type == "Movies" ? currentUser.watchlist : currentUser.watchlistTVShows;
    Map rewatched = type == "Movies"
        ? currentUser.rewatchedMovies
        : currentUser.rewatchedTVShows;
    List tempCreditsCrew = [];
    List countedItems = [];
    for (var element in crew) {
      if (countedItems.contains(element["id"].toString())) {
        for (Map credit in tempCreditsCrew) {
          if (credit["id"].toString() == element["id"].toString()) {
            credit["job"] = "${credit["job"]} / ${element["job"]}";
          }
        }
      } else {
        tempCreditsCrew.add(element);
        countedItems.add(element["id"].toString());
      }

      if (Utils.containsNonType(seen, [type, element["id"].toString()])) {
        if (element["job"] == "Director" &&
            !countedTVShowsDirector.contains(element["id"].toString())) {
          statsDir += 1;
          if (Utils.containsNonType(favs, [type, element["id"].toString()])) {
            scoreDirector += 3;
          }
          if (rewatched.keys.toList().contains(element["id"].toString())) {
            scoreDirector += rewatched[element["id"].toString()] as int > 1
                ? rewatched[element["id"].toString()] as int
                : 2;
          } else {
            scoreDirector += 2;
          }
          countedTVShowsDirector.add(element["id"].toString());
        } else if ((element["job"] == "Writer" ||
                element["job"] == "Screenplay") &&
            !countedTVShowsWriter.contains(element["id"].toString())) {
          statsWriterTV += 1;
          if (Utils.containsNonType(favs, [type, element["id"].toString()])) {
            scoreWriter += 3;
          }
          if (rewatched.keys.toList().contains(element["id"].toString())) {
            scoreWriter += rewatched[element["id"].toString()] as int > 1
                ? rewatched[element["id"].toString()] as int
                : 2;
          } else {
            scoreWriter += 2;
          }
          countedTVShowsWriter.add(element["id"].toString());
        }
      } else if (Utils.containsNonType(
              watchlist, [type, element["id"].toString()]) &&
          element["job"] == "Director" &&
          !countedTVShowsDirector.contains(element["id"].toString())) {
        scoreDirector += 1;
        countedTVShowsDirector.add(element["id"].toString());
      } else if (Utils.containsNonType(
              watchlist, [type, element["id"].toString()]) &&
          (element["job"] == "Writer" || element["job"] == "Screenplay") &&
          !countedTVShowsWriter.contains(element["id"].toString())) {
        scoreWriter += 1;
        countedTVShowsWriter.add(element["id"].toString());
      }
      if (element["job"] == "Director" &&
          !countedTVShowsDirector.contains(element["id"].toString())) {
        countedTVShowsDirector.add(element["id"].toString());
      }
    }
    return [
      scoreDirector,
      statsDir,
      countedTVShowsDirector.length,
      scoreWriter,
      statsWriterTV,
      tempCreditsCrew
    ];
  }

  Future<Map> getPersonData(AppUser currentUser, Map oscars) async {
    int scoreActor = 0;
    int scoreDirector = 0;
    int scoreWriter = 0;
    int stats = 0;
    int statsTv = 0;
    int allDirMovies = 0;
    int statsDir = 0;
    int statsWriterMovies = 0;
    int statsWriterTV = 0;
    Map json = await getCastCredits();

    List actorStats =
        getCastStats(currentUser, json['movie_credits_cast'], "Movies");
    scoreActor = actorStats[0];
    stats = actorStats[1];

    List actorStatsTV =
        getCastStats(currentUser, json['tv_credits_cast'], "TVShows");
    int tempScoreActor = actorStatsTV[0];
    statsTv = actorStatsTV[1];

    List crewStats =
        getCrewStats(currentUser, json['movie_credits_crew'], "Movies");
    scoreDirector = crewStats[0];
    statsDir = crewStats[1];
    allDirMovies = crewStats[2];
    scoreWriter = crewStats[3];
    statsWriterMovies = crewStats[4];
    List tempMovieCreditsCrew = crewStats[5];
    json['movie_credits_crew'] = tempMovieCreditsCrew;

    List crewStatsTV =
        getCrewStats(currentUser, json['tv_credits_crew'], "TVShows");
    int tempScoreCrew = crewStatsTV[0];
    int tempStats = crewStatsTV[1];
    int tempDirMovies = crewStatsTV[2];
    int tempScoreWriter = crewStatsTV[3];
    statsWriterTV = crewStatsTV[4];
    List tempTVCreditsCrew = crewStatsTV[5];
    json['tv_credits_crew'] = tempTVCreditsCrew;

    if (oscars.keys.contains(id.toString())) {
      json['num_oscars'] = oscars[id.toString()]['num_oscars'];
      json["oscars"] = {};
      for (String year in oscars[id.toString()]["oscars"].keys.toList()) {
        for (Map award in oscars[id.toString()]["oscars"][year]) {
          if (json["oscars"].containsKey(award["movie"].toLowerCase())) {
            json["oscars"][award["movie"].toLowerCase()].add(award["oscar"]);
          } else {
            json["oscars"][award["movie"].toLowerCase()] = [award["oscar"]];
          }
        }
      }
    } else {
      json['num_oscars'] = 0;
      json["oscars"] = {};
    }

    int tempNum = await updateStatsDoc(
        scoreDirector + tempScoreCrew, currentUser, "FavDirectors");
    json["director_ranking"] = tempNum;
    json["allDirMovies"] = allDirMovies;

    tempNum = await updateStatsDoc(
        scoreActor + tempScoreActor, currentUser, "FavActors");
    json["actor_ranking"] = tempNum;

    tempNum = await updateStatsDoc(
        scoreWriter + tempScoreWriter, currentUser, "FavWriters");
    json["writer_ranking"] = tempNum;

    await fetchNewStats(currentUser);

    personStats["scoreActor"] = scoreActor + tempScoreActor;
    personStats["scoreDirector"] = scoreDirector + tempScoreCrew;
    personStats["scoreWriter"] = scoreWriter + tempScoreWriter;
    personStats["stats"] = stats;
    personStats["stats_tv"] = statsTv;
    personStats["stats_dir"] = statsDir + tempStats;
    personStats["stats_writer_movies"] = statsWriterMovies;
    personStats["stats_writer_tv"] = statsWriterTV;
    personStats["allDirMovies"] = allDirMovies + tempDirMovies;
    return json;
  }
}
