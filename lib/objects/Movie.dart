import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart';
import 'Media.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Movie extends MediaItem {
  // String movieId, movieTitle, movieCoverPhoto;
  Movie({
    required String id,
    required String title,
    required String coverPhoto,
  }) : super(id: id, title: title, coverPhoto: coverPhoto);

  @override
  Future<Map> getData() async {
    final response = await http.get(Uri.parse('$MOVIE_LINK$id$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json as Map;
    }
    return {};
  }

  @override
  Future<Map> getExtendedData() async {
    final String movieId = id.toString();
    final String name =
        title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "-");

    Map json = await ApiUtils.fetchMovieDetails(movieId, name, "movie");

    // Handle seen times and review
    json["times_seen"] = currentUser.rewatchedMovies.containsKey(movieId)
        ? currentUser.rewatchedMovies[movieId]
        : (isSeen() ? 1 : 0);
    json["review"] = reviewed ? (currentUser.reviews[movieId] as Map?) : null;

    // Process seen dates
    json["seen_dates"] =
        ApiUtils.processSeenDates(currentUser.calendar, movieId, "movie");

    // Default values for missing data
    json["backdrop_path"] = json["backdrop_path"] ?? "";
    json["imdb_rating"] = "0.0";
    json["year"] = "None";

    // Fetch and add additional movie data
    Map additionalData =
        await ApiUtils.fetchAdditionalMovieData(json, movieId, name, "movie");
    json.addAll(additionalData);

    return json;
  }

  bool isSeen() {
    return Utils.contains(currentUser.seenMovies, ['Movies', id], "Movies");
  }

  bool isBookmarked() {
    return Utils.contains(currentUser.watchlist, ['Movies', id], "Movies");
  }

  bool isFavorite() {
    return Utils.contains(currentUser.favMovies, ['Movies', id], "Movies");
  }
}
