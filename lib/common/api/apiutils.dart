import 'dart:async';
import 'dart:convert';

import '../../main.dart';
import '../constants.dart';
import 'http_client.dart';

class ApiUtils {
  static const String _omdbApiKey = String.fromEnvironment('OMDB_API_KEY',
      defaultValue: '***REMOVED***');

  /// Fetches movie data from the OMDB API using the IMDb ID.
  /// @param imdbId The IMDb ID of the movie or show.
  /// @return The decoded JSON response containing OMDB metadata.
  static Future<dynamic> fetchOmdbData(String imdbId) async {
    final response = await AppHttp.client.get(
        Uri.parse('https://www.omdbapi.com/?i=$imdbId&apikey=$_omdbApiKey'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load OMDB data');
    }
    return jsonDecode(response.body);
  }

  /// Fetches watch provider data for a specific movie or TV show.
  /// @param movieId The TMDb movie/TV ID.
  /// @param name The slugified title of the movie/TV show.
  /// @param country The country code for filtering providers.
  /// @param type Either "movie" or "tv" to determine API path.
  /// @return A list of provider name and logo URL pairs.
  static Future<List<dynamic>> fetchProviders(
      String movieId, String name, String country, String type) async {
    final response = await AppHttp.client.get(Uri.parse(
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

  /// Merges duplicate crew entries (same person appearing more than once,
  /// e.g. as both Director and Writer) into a single entry per person, with
  /// their distinct job titles joined by " / " in order of first appearance.
  /// Duplicate job names for the same person are collapsed to one occurrence.
  /// Entries with a null/missing "job" are treated as having no job to add.
  /// @param crew The raw crew list (each entry expected to contain an "id").
  /// @return A new list with one merged entry per distinct crew member id.
  static List<Map> mergeCrewJobs(List<Map> crew) {
    List countedCrew = [];
    List<Map> finalCrew = [];
    for (Map crewMember in crew) {
      if (countedCrew.contains(crewMember["id"])) {
        for (Map credit in finalCrew) {
          if (credit["id"].toString() == crewMember["id"].toString()) {
            List<String> jobs = (credit["job"] as String?)
                    ?.split('/')
                    .map((role) => role.trim())
                    .where((role) => role.isNotEmpty)
                    .toList() ??
                [];
            final newJob = (crewMember["job"] as String?)?.trim();
            if (newJob != null && newJob.isNotEmpty && !jobs.contains(newJob)) {
              jobs.add(newJob);
            }
            credit["job"] = jobs.join(' / ');
          }
        }
      } else {
        finalCrew.add(crewMember);
        countedCrew.add(crewMember["id"]);
      }
    }
    return finalCrew;
  }

  /// Returns the first crew member whose "job" satisfies [matches], or null.
  ///
  /// [mergeCrewJobs] returns a typed `List<Map>`, so callers cannot use
  /// `firstWhere` with an `orElse` that returns null: the closure fails the
  /// runtime cast to the element type and throws on every lookup, before the
  /// predicate is ever evaluated.
  static Map? findCrewMember(dynamic crew, bool Function(String job) matches) {
    if (crew is! List) return null;
    for (final person in crew) {
      final String? job = person["job"] as String?;
      if (job != null && matches(job)) {
        return person as Map;
      }
    }
    return null;
  }

  /// Fetches cast, crew, and trailer data for a specific media item in the current language.
  /// @param movieId The TMDb media ID.
  /// @param name The slugified title.
  /// @param type The media type ("movie" or "tv").
  /// @return A map with cast, formatted crew, and trailer (if any).
  static Future<Map<String, dynamic>> fetchCreditsAndTrailer(
      String movieId, String name, String type) async {
    final lang = currentUser.settings['language'] ?? 'en';
    final creditsResponse = await AppHttp.client.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$CREDITS_LINK&language=$lang'));
    final trailerResponse = await AppHttp.client.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$VIDEOS_LINK&language=$lang'));

    if (creditsResponse.statusCode != 200 ||
        trailerResponse.statusCode != 200) {
      throw Exception('Failed to load credits or trailer data');
    }
    List<Map> finalCrew =
        mergeCrewJobs(List<Map>.from(jsonDecode(creditsResponse.body)["crew"]));

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

  /// Fetches the basic metadata for a movie or TV show in the current language.
  /// @param movieId The TMDb ID.
  /// @param name The slugified name.
  /// @param type The media type ("movie" or "tv").
  /// @return A map of the media details.
  static Future<Map<String, dynamic>> fetchMovieDetails(
      String movieId, String name, String type) async {
    final lang = currentUser.settings['language'] ?? 'en';
    final movieResponse = await AppHttp.client.get(Uri.parse(
        '${type == "movie" ? MOVIE_LINK : TV_SHOW_LINK}$movieId-$name$API_KEY&language=$lang'));
    if (movieResponse.statusCode != 200) {
      throw Exception('Failed to load movie details');
    }
    return jsonDecode(movieResponse.body);
  }

  /// Fetches additional metadata including IMDb rating, release year, streaming providers, cast/crew, and trailer.
  /// Uses the current language for TMDb calls.
  /// @param json The base movie data JSON.
  /// @param movieId The TMDb ID.
  /// @param name The slugified name.
  /// @param type The media type.
  /// @return A map with additional movie metadata.
  static Future<Map<String, dynamic>> fetchAdditionalMovieData(
      Map json, String movieId, String name, String type) async {
    Map<String, dynamic> additionalData = {};
    var lang = currentUser.settings['language'] ?? 'en';

    var imdbId = json['imdb_id'];
    if (type != "movie") {
      final response2 = await AppHttp.client.get(Uri.parse(
          '$TV_SHOW_LINK$movieId-$name$EXTERNAL_IDS_LINK&language=$lang'));
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

  /// Processes and returns all calendar dates where a movie or show was marked as watched.
  /// @param calendar The user calendar map.
  /// @param movieId The media ID to filter for.
  /// @param type The type of media ("movie" or "tv").
  /// @return A sorted list of watch dates and friend data.
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

  /// Performs a multi-type search (actors, movies, shows) based on a term.
  /// @param searchTermActor The search term.
  /// @param page The 1-based result page to fetch.
  /// @return A list of result objects matching the query.
  static Future<List> searchData(String searchTermActor, {int page = 1}) async {
    return (await searchMulti(searchTermActor, page: page)).results;
  }

  /// Performs a multi-type search and returns the page metadata alongside the
  /// results, so callers can keep loading further pages.
  /// @param searchTerm The search term.
  /// @param page The 1-based result page to fetch.
  /// @return The decoded page of results.
  static Future<SearchResultPage> searchMulti(String searchTerm,
      {int page = 1}) async {
    final String query = searchTerm.trim();
    if (query.isEmpty) {
      return const SearchResultPage(results: [], page: 1, totalPages: 0);
    }
    final searchLink =
        '$SEARCH_BY_NAME_MULTI_LINK${Uri.encodeQueryComponent(query)}&page=$page';
    final response = await AppHttp.client.get(Uri.parse(searchLink));
    if (response.statusCode != 200) {
      throw Exception('Failed to load search results');
    }
    final json = jsonDecode(response.body);
    return SearchResultPage(
      results: (json['results'] as List?) ?? const [],
      page: (json['page'] as int?) ?? page,
      totalPages: (json['total_pages'] as int?) ?? 1,
    );
  }

  /// Scores how well a search result matches [query], highest first.
  ///
  /// TMDB orders multi-search results by popularity alone, which buries an
  /// exactly matching title under better known but less relevant entries.
  /// Matching the title is worth more than any popularity difference, so the
  /// match tiers are spaced far enough apart that popularity only breaks ties
  /// within a tier.
  /// @param item A single search result.
  /// @param query The raw search term.
  /// @return The relevance score, where a larger value sorts earlier.
  static double relevanceScore(Map item, String query) {
    final String needle = _normalizeForMatch(query);
    final String title =
        _normalizeForMatch((item['title'] ?? item['name'] ?? '').toString());

    double score;
    if (needle.isEmpty || title.isEmpty) {
      score = 0;
    } else if (title == needle) {
      score = 4000;
    } else if (title.startsWith(needle)) {
      score = 3000;
    } else if (_containsWholeWord(title, needle)) {
      score = 2000;
    } else if (title.contains(needle)) {
      score = 1000;
    } else {
      score = 0;
    }

    // Popularity is unbounded, so it is compressed into the gap between tiers
    // rather than being added raw, which would let a very popular loose match
    // outrank an exact one.
    final double popularity =
        double.tryParse((item['popularity'] ?? 0).toString()) ?? 0;
    return score + (popularity / (popularity + 100)) * 500;
  }

  /// Sorts [results] by [relevanceScore], leaving the original order intact
  /// for entries that score identically.
  /// @param results The raw result list.
  /// @param query The raw search term.
  /// @return A new list ordered by descending relevance.
  static List<dynamic> sortByRelevance(List<dynamic> results, String query) {
    final List<dynamic> sorted = List<dynamic>.from(results);
    final Map<int, double> scores = {
      for (final item in sorted)
        identityHashCode(item):
            item is Map ? relevanceScore(item, query) : 0.0,
    };
    mergeSortByScore(sorted, scores);
    return sorted;
  }

  /// Stable descending sort used by [sortByRelevance]. Dart's [List.sort] is
  /// not stable, which would shuffle equally scored results between rebuilds.
  /// @param items The list to sort in place.
  /// @param scores Score per item, keyed by identity.
  static void mergeSortByScore(List<dynamic> items, Map<int, double> scores) {
    if (items.length < 2) return;
    final int middle = items.length ~/ 2;
    final List<dynamic> left = items.sublist(0, middle);
    final List<dynamic> right = items.sublist(middle);
    mergeSortByScore(left, scores);
    mergeSortByScore(right, scores);

    int l = 0, r = 0, i = 0;
    while (l < left.length && r < right.length) {
      final double leftScore = scores[identityHashCode(left[l])] ?? 0;
      final double rightScore = scores[identityHashCode(right[r])] ?? 0;
      items[i++] = leftScore >= rightScore ? left[l++] : right[r++];
    }
    while (l < left.length) {
      items[i++] = left[l++];
    }
    while (r < right.length) {
      items[i++] = right[r++];
    }
  }

  /// Lowercases and strips accents and punctuation so that "Amelie" matches
  /// "Amélie" and "wall e" matches "WALL·E".
  static String _normalizeForMatch(String value) {
    final String lower = value.toLowerCase();
    final StringBuffer buffer = StringBuffer();
    for (final int rune in lower.runes) {
      final String char = String.fromCharCode(rune);
      final String folded = _accents[char] ?? char;
      if (RegExp(r'[a-z0-9]').hasMatch(folded)) {
        buffer.write(folded);
      } else if (folded.length > 1) {
        buffer.write(folded);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsWholeWord(String haystack, String needle) {
    return haystack.split(' ').contains(needle) ||
        haystack.contains(' $needle ') ||
        haystack.startsWith('$needle ') ||
        haystack.endsWith(' $needle');
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  };

  /// Searches for movies based on a term in the current language.
  /// @param searchTerm The user query.
  /// @return A list of movies matching the query.
  static Future<List> searchMovies(String searchTerm) async {
    final String query = searchTerm.trim();
    if (query.isEmpty) return [];
    final lang = currentUser.settings['language'] ?? 'en';
    final searchLink =
        '$SEARCH_BY_NAME_MOVIE_LINK${Uri.encodeQueryComponent(query)}&language=$lang';
    final response = await AppHttp.client.get(Uri.parse(searchLink));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['results'];
    }
    throw Exception('Failed to load movie details');
  }

  /// Searches for TV shows based on a term in the current language.
  /// @param searchTerm The user query.
  /// @return A list of TV shows matching the query.
  static Future<List> searchTvShows(String searchTerm) async {
    final String query = searchTerm.trim();
    if (query.isEmpty) return [];
    final lang = currentUser.settings['language'] ?? 'en';
    final searchLink =
        '$SEARCH_BY_NAME_TV_SHOW_LINK${Uri.encodeQueryComponent(query)}&language=$lang';
    final response = await AppHttp.client.get(Uri.parse(searchLink));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['results'];
    }
    throw Exception('Failed to load tv show details');
  }
}

/// One page of search results, with enough metadata to fetch the next.
class SearchResultPage {
  final List<dynamic> results;
  final int page;
  final int totalPages;

  const SearchResultPage({
    required this.results,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
