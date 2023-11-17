import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart';
import '../movie_result.dart';
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
    final response = await http.get(Uri.parse('$MOVIE_LINK${this.id}$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json as Map;
    }
    return {};
  }

  Future<Map> getMovieData() async {
    final String movieId = this.id.toString();
    final String name =
        'Movies'.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "-");

    Map json = await ApiUtils.fetchMovieDetails(movieId, name);

    // Handle seen times and review
    json["times_seen"] = rewatchedMovies.containsKey(movieId)
        ? rewatchedMovies[movieId]
        : (containsMap(seenMovies, ['Movies', this.id.toString()]) ? 1 : 0);
    json["review"] = reviewed ? (reviews[movieId] as Map?) : null;

    // Process seen dates
    json["seen_dates"] = ApiUtils.processSeenDates(calendar, movieId);

    // Default values for missing data
    json["backdrop_path"] = json["backdrop_path"] ?? "";
    json["imdb_rating"] = "0.0";
    json["year"] = "None";

    // Fetch and add additional movie data
    Map additionalData =
        await ApiUtils.fetchAdditionalMovieData(json, movieId, name);
    json.addAll(additionalData);

    return json;
  }
}
