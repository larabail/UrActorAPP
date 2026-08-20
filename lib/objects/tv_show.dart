import 'package:cloud_firestore/cloud_firestore.dart';

import '../common/constants.dart';
import '../common/utils.dart';
import '../common/api/apiutils.dart';
import '../main.dart';
import 'media.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TVShow extends MediaItem {
  TVShow({
    required super.id,
    required super.title,
    required super.coverPhoto,
  });
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

    json["times_seen"] = currentUser.rewatchedTVShows.containsKey(showId)
        ? currentUser.rewatchedTVShows[showId]
        : (isSeen() ? 1 : 0);
    json["review"] =
        reviewed ? (currentUser.tvShowReviews[showId] as Map?) : null;

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

  Future<Map> getSeasonsData(int season) async {
    final String showId = id.toString();
    final response =
        await http.get(Uri.parse('$TV_SHOW_LINK$showId/season/$season$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json as Map;
    }
    return {};
  }
  
  Future removeFriend(String friendUid, List friendsWatchedWith) async {
    var userDoc = await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .doc("SeenWith")
        .get();
    Map docData = userDoc.data() as Map;
    Map<String, dynamic> movieMap = docData["TVShows"];
    List<dynamic> friendsList = movieMap[id]["friends"];
    friendsList.remove(friendUid);
    movieMap[id]["friends"] = friendsList;
    await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .doc("SeenWith")
        .update({"TVShows": movieMap});
    currentUser.seenWith[friendUid]["TVShows"].remove(id);

    var friendsDoc = await FirebaseFirestore.instance
        .collection(friendUid)
        .doc("SeenWith")
        .get();
    docData = friendsDoc.data() as Map;
    movieMap = docData["TVShows"];
    friendsList = movieMap[id]["friends"];
    friendsList.remove(currentUser.uid);
    movieMap[id]["friends"] = friendsList;
    await FirebaseFirestore.instance
        .collection(friendUid)
        .doc("SeenWith")
        .update({"TVShows": movieMap});
  }
}
