import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:uractor/objects/Movie.dart';

import '../main.dart';
import 'constants.dart';

class ApiUtils {
  static Future<dynamic> fetchOmdbData(String imdbId) async {
    final response = await http
        .get(Uri.parse('https://www.omdbapi.com/?i=$imdbId&apikey=768d2cf9'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load OMDB data');
    }
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> fetchProviders(
      String movieId, String name, String country, String type) async {
    final response = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$WATCH_PROVIDERS_LINK'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load provider data');
    }

    var data = jsonDecode(response.body);
    List<dynamic> providers = [];
    if (data["results"].keys.contains(country) &&
        data["results"][country]['flatrate'] != null) {
      providers = data["results"][country]['flatrate'].map((provider) {
        return [provider['provider_name'], IMG_LINK + provider['logo_path']];
      }).toList();
    }
    return providers;
  }

  static Future<Map<String, dynamic>> fetchCreditsAndTrailer(
      String movieId, String name, String type) async {
    final creditsResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$CREDITS_LINK'));
    final trailerResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$VIDEOS_LINK'));

    if (creditsResponse.statusCode != 200 ||
        trailerResponse.statusCode != 200) {
      throw Exception('Failed to load credits or trailer data');
    }
    List countedCrew = [];
    List finalCrew = [];
    for (Map crewMember in jsonDecode(creditsResponse.body)["crew"]) {
      if (countedCrew.contains(crewMember["id"])) {
        for (Map credit in finalCrew) {
          if (credit["id"].toString() == crewMember["id"].toString()) {
            credit["job"] = "${credit["job"]} / ${crewMember["job"]}";
          }
        }
      } else {
        finalCrew.add(crewMember);
        countedCrew.add(crewMember["id"]);
      }
    }

    Map<String, dynamic> data = {
      'cast': jsonDecode(creditsResponse.body)["cast"],
      'crew': finalCrew,
      'trailer': null
    };

    var trailerResults = jsonDecode(trailerResponse.body)['results'];
    var trailer = trailerResults.firstWhere(
        (element) =>
            element['site'] == "YouTube" && element['type'] == "Trailer",
        orElse: () => null);
    if (trailer != null) {
      data['trailer'] = trailer;
    }

    return data;
  }

  static Future<Map<String, dynamic>> fetchMovieDetails(
      String movieId, String name, String type) async {
    final movieResponse = await http.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$API_KEY'));
    if (movieResponse.statusCode != 200) {
      throw Exception('Failed to load movie details');
    }
    return jsonDecode(movieResponse.body);
  }

  static Future<Map<String, dynamic>> fetchAdditionalMovieData(
      Map json, String movieId, String name, String type) async {
    Map<String, dynamic> additionalData = {};

    var imdbId = json['imdb_id'];
    if (type != "movie") {
      final response2 = await http
          .get(Uri.parse('$TV_SHOW_LINK$movieId-$name$EXTERNAL_IDS_LINK'));
      if (response2.statusCode == 200) {
        imdbId = jsonDecode(response2.body)['imdb_id'];
      }
    }
    if (imdbId != null) {
      var omdbData = await fetchOmdbData(imdbId);
      additionalData['imdb_rating'] =
          omdbData["imdbRating"] != "N/A" ? omdbData["imdbRating"] : "0.0";
      additionalData['year'] = omdbData['Year'] ?? "None";
    } else {
      additionalData['imdb_rating'] = "0.0";
      additionalData['year'] = "None";
    }

    additionalData['providers'] =
        await fetchProviders(movieId, name, currentUser.country, type);
    additionalData.addAll(await fetchCreditsAndTrailer(movieId, name, type));

    return additionalData;
  }

  static List<dynamic> processSeenDates(
      Map calendar, String movieId, String type) {
    List<dynamic> seenDates = [];
    calendar.forEach((key, movies) {
      movies
          .where((movie) => ((movie['id'] == movieId) &&
              (movie.containsKey("type")
                  ? movie["type"] == type
                  : type == "movie"
                      ? true
                      : false)))
          .forEach((movie) {
        seenDates.add([key, movie["friends"]]);
      });
    });
    seenDates
        .sort((a, b) => DateTime.parse(b[0]).compareTo(DateTime.parse(a[0])));
    return seenDates;
  }

  static Future<List> getUpcomingMovies() async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    DateTime oneMonthLater = DateTime(now.year, now.month + 1, now.day);
    if (now.month == 12) {
      oneMonthLater = DateTime(now.year + 1, 1, now.day);
    }
    while (oneMonthLater.month != ((now.month % 12) + 1)) {
      oneMonthLater = DateTime(
          oneMonthLater.year, oneMonthLater.month, oneMonthLater.day - 1);
    }

    String formattedDateOneMonth =
        DateFormat('yyyy-MM-dd').format(oneMonthLater);
    final responseUpcomingMovies = await http.get(Uri.parse(
        "https://api.themoviedb.org/3/discover/movie$API_KEY&include_adult=false&include_video=false&language=en-US&page=1&sort_by=popularity.desc&with_release_type=2|3&release_date.gte=$formattedDate&release_date.lte=$formattedDateOneMonth"));
    List upcomingMovies = [];
    if (responseUpcomingMovies.statusCode == 200) {
      final upcomingMoviesJson = jsonDecode(responseUpcomingMovies.body);
      for (Map movie in upcomingMoviesJson["results"]) {
        Movie tempMovie = Movie(
            id: movie["id"].toString(),
            title: movie["title"],
            coverPhoto: movie["poster_path"]);
        upcomingMovies.add(tempMovie);
      }
    }
    return upcomingMovies;
  }

  static Future<List> searchData(searchTermActor) async {
    String searchLink = "";
    if (searchTermActor != "") {
      searchLink =
          '$SEARCH_BY_NAME_MULTI_LINK${searchTermActor.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['results'];
      }
    }
    return [];
  }

  static Future<List> searchMovies(String searchTerm) async {
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$SEARCH_BY_NAME_MOVIE_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['results'];
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      return [];
    }
  }

  static Future<List> searchTvShows(String searchTerm) async {
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$SEARCH_BY_NAME_TV_SHOW_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        return json['results'];
      } else {
        throw Exception('Failed to load tv show details');
      }
    } else {
      return [];
    }
  }
}
