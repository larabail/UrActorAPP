/// The signed-in user's own membership lists, narrowed to the one list that
/// could possibly contain a given `[type, id]` pair.
///
/// Badges are drawn on every media tile, so the lookup behind them runs once
/// per tile on every rebuild. These helpers therefore hand back the existing
/// list rather than a merged copy: concatenating favourites and TV favourites
/// would allocate a list per tile, and half of it could never match anyway
/// because a `[type, id]` pair only ever matches its own type.
///
/// The data is whatever `AppUser.getFirebaseData` already loaded at sign in,
/// so a badge costs a linear scan of a list held in memory and never a
/// Firestore read or a TMDB call.
library;

import '../main.dart';

/// The favourites list a `[type, id]` [mediaPair] could appear in, or empty
/// when the pair is not a media pair at all.
Iterable<dynamic> userFavoriteItemsFor(dynamic mediaPair) {
  final String? type = _typeOf(mediaPair);
  if (type == null) return const [];
  return type == 'Movies' ? currentUser.favMovies : currentUser.favTVShows;
}

/// The watchlist a `[type, id]` [mediaPair] could appear in, or empty when the
/// pair is not a media pair at all.
Iterable<dynamic> userWatchlistItemsFor(dynamic mediaPair) {
  final String? type = _typeOf(mediaPair);
  if (type == null) return const [];
  return type == 'Movies' ? currentUser.watchlist : currentUser.watchlistTVShows;
}

String? _typeOf(dynamic mediaPair) {
  if (mediaPair is! List || mediaPair.length < 2) return null;
  final dynamic type = mediaPair[0];
  if (type != 'Movies' && type != 'TVShows') return null;
  return type as String;
}
