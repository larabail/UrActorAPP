import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart';
import 'Media.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TVShow extends MediaItem {
  TVShow({
    required String id,
    required String title,
    required String coverPhoto,
  }) : super(id: id, title: title, coverPhoto: coverPhoto);
  @override
  Future<Map> getData() async {
    final response = await http.get(Uri.parse('$TV_SHOW_LINK$id$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json as Map;
    }
    return {};
  }

  @override
  Future<Map> getExtendedData() async {
    final String showId = id.toString();
    final String name =
        title.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "-");

    Map json = await ApiUtils.fetchMovieDetails(showId, name, "show");

    // Handle seen times and review
    // json["times_seen"] = currentUser.rewatchedMovies.containsKey(movieId)
    //     ? currentUser.rewatchedMovies[movieId]
    //     : (isSeen() ? 1 : 0);
    json["review"] =
        reviewed ? (currentUser.tvShowReviews[showId] as Map?) : null;

    // Process seen dates
    json["seen_dates"] =
        ApiUtils.processSeenDates(currentUser.calendar, showId, "series");

    json["backdrop_path"] = json["backdrop_path"] ?? "";
    json["imdb_rating"] = "0.0";
    json["year"] = "None";

    Map additionalData =
        await ApiUtils.fetchAdditionalMovieData(json, showId, name, "show");
    json.addAll(additionalData);

    return json;
  }

  bool isSeen() {
    return Utils.contains(currentUser.seenTVShows, ['TVShows', id], "TVShows");
  }

  bool isBookmarked() {
    return Utils.contains(
        currentUser.watchlistTVShows, ['TVShows', id], "TVShows");
  }

  bool isFavorite() {
    return Utils.contains(currentUser.favTVShows, ['TVShows', id], "TVShows");
  }
}
