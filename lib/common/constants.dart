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
const String UNKNOWN_COVER =
    "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/UNKNOWN_cover.png?alt=media&token=4a9b8c89-67b4-4859-91c1-166383ab1586";
const String UNKNOWN_PERSON =
    "https://firebasestorage.googleapis.com/v0/b/actordb-cf981.appspot.com/o/UNKNOWN_actor.png?alt=media&token=054473a7-ed7a-4bc7-9ff9-7b7f37b5ae84";