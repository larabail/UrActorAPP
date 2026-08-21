// ignore_for_file: constant_identifier_names

/// The TMDB API key is supplied at build time instead of being committed:
///
/// ```
///   flutter run   --dart-define=TMDB_API_KEY=<key>
///   flutter build --dart-define=TMDB_API_KEY=<key>
/// ```
///
/// Defaults to an empty string when the define is missing. Call
/// [assertTmdbApiKey] once at startup so a missing key fails loudly, rather
/// than every TMDB request quietly coming back 401.
const String TMDB_API_KEY = String.fromEnvironment('TMDB_API_KEY');

/// Throws a [StateError] when no TMDB key was supplied at build time.
///
/// The parameter exists so the check can be tested directly; callers in the
/// app should use the default.
void assertTmdbApiKey([String key = TMDB_API_KEY]) {
  if (key.isNotEmpty) return;
  throw StateError(
    'TMDB_API_KEY is empty. Pass the key at build time, for example:\n'
    '  flutter run --dart-define=TMDB_API_KEY=<your key>\n'
    'See the Configuration section of README.md.',
  );
}

const String API_KEY = "?api_key=$TMDB_API_KEY";

const String IMG_LINK = 'https://image.tmdb.org/t/p/w500/';
const String MOVIE_LINK = "https://api.themoviedb.org/3/movie/";
const String TV_SHOW_LINK = "https://api.themoviedb.org/3/tv/";
const String CREDITS_LINK = "/credits$API_KEY";

/// Credits for a show across every season it has ever had.
///
/// `/tv/{id}/credits` answers with the newest season's regular cast only, so a
/// long running show comes back with a handful of people and everyone who left
/// missing. This endpoint aggregates all seasons, at the cost of a different
/// response shape -- see `ApiUtils.normalizeCredits`.
const String AGGREGATE_CREDITS_LINK = "/aggregate_credits$API_KEY";
const String WATCH_PROVIDERS_LINK = "/watch/providers$API_KEY";
const String VIDEOS_LINK = "/videos$API_KEY";
const String EXTERNAL_IDS_LINK = "/external_ids$API_KEY";
const String SEARCH_BY_NAME_MOVIE_LINK =
    "https://api.themoviedb.org/3/search/movie$API_KEY&query=";
const String SEARCH_BY_NAME_TV_SHOW_LINK =
    'https://api.themoviedb.org/3/search/tv$API_KEY&query=';
const String SEARCH_BY_NAME_MULTI_LINK =
    'https://api.themoviedb.org/3/search/multi$API_KEY&query=';
const String PERSON_LINK = "https://api.themoviedb.org/3/person/";
const String MOVIE_CREDITS_LINK = '/movie_credits$API_KEY';
const String TV_SHOW_CREDITS_LINK = '/tv_credits$API_KEY';
const String GENRES_LINK =
    "https://api.themoviedb.org/3/genre/movie/list$API_KEY";
const String COUNTRIES_LINK =
    "https://api.themoviedb.org/3/configuration/countries$API_KEY";
const String WATCH_PROVIDERS_BY_REGION_LINK =
    "https://api.themoviedb.org/3/watch/providers/movie$API_KEY&watch_region=";

/// Stand-ins for media TMDB has no artwork for.
///
/// These are bundled assets rather than URLs. They used to be hosted in
/// Firebase Storage, which stopped serving them -- every posterless tile then
/// threw a 403 out of the image resource service. Nothing about them ever
/// varied per user, so shipping them in the bundle removes the request
/// entirely and they render offline and instantly.
///
/// Never hand these to a network image widget. `mediaImageProvider` in
/// `media_image.dart` picks the right provider and is what every caller uses.
const String UNKNOWN_COVER = "assets/unknown_cover.png";
const String UNKNOWN_PERSON = "assets/unknown_person.png";
