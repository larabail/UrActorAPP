import 'dart:convert';
import 'calendar_episode.dart';
import 'constants.dart';
import 'api/http_client.dart';

class Utils {
  static bool containsMap(List list, Map map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }

  static bool containsList(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == "Movies") {
        return true;
      }
    }
    return false;
  }

  static bool containsNonType(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]).toString() == map[0].toString()) {
        return true;
      }
    }
    return false;
  }

  static bool contains(List list, List map, String type) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == type) {
        return true;
      }
    }
    return false;
  }

  /// Fetches TMDB movie/TV show details for [id] and [type] ("TVShows" or
  /// "Movies"), decodes the response into a simplified data map, and adds it
  /// to [cache] if it isn't already present (via [containsMap]). Throws an
  /// [Exception] if the request fails. Shared by the several screens that
  /// previously duplicated this fetch/decode/populate logic.
  static Future<Map<String, dynamic>> fetchMediaData(
    dynamic id,
    String type,
    List<Map<String, dynamic>> cache,
  ) async {
    Map<String, dynamic> data = {};
    String link = type == "TVShows" ? TV_SHOW_LINK : MOVIE_LINK;
    final response = await AppHttp.client.get(Uri.parse('$link$id$API_KEY'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (type == "TVShows") {
        data['title'] = json['name'];
      } else {
        data['title'] = json['title'];
      }
      data['poster_path'] = json['poster_path'];
      data['id'] = json['id'];
      data['type'] = type;
      if (!containsMap(cache, data)) {
        cache.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  /// Fetches TMDB details for a calendar [element] (as stored under a user's
  /// or friend's calendar day) and appends the decoded result to
  /// [targetList], carrying over the "friends" field and any recorded
  /// season/episode if present. Set [sanitizeName] to strip non-alphanumeric
  /// characters from the title before building the request URL
  /// (calendar.dart's historical behavior). Set [dedupe] to skip appending
  /// when [targetList] already contains an identical map
  /// (friends_calendar.dart's historical behavior).
  static Future<void> fetchCalendarElement(
    Map element,
    List targetList, {
    bool sanitizeName = false,
    bool dedupe = false,
  }) async {
    String id = element['id'];
    String name = element['title'];
    if (sanitizeName) {
      name = name
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "-");
    }
    final String link = element.containsKey("type")
        ? (element["type"] == "movie" ? MOVIE_LINK : TV_SHOW_LINK)
        : MOVIE_LINK;
    final response = await AppHttp.client.get(Uri.parse('$link$id-$name$API_KEY'));
    if (response.statusCode == 200) {
      dynamic json = jsonDecode(response.body);
      if (element.containsKey("friends")) {
        json["friends"] = element["friends"];
      }
      // The calendar screens render this TMDB payload rather than the stored
      // entry, so whatever the entry recorded has to be carried across the
      // fetch or it is invisible on the screen it was recorded for.
      CalendarEpisode.copyOnto(element, json);
      // Dedupe on the enriched map, not the bare TMDB payload: two episodes of
      // one show on one day are two entries and both belong on the day, and
      // comparing before the carry-over would collapse them into one.
      if (!dedupe || !containsMap(targetList, json)) {
        targetList.add(json);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
  }
}


