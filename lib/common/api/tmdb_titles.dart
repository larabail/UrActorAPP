import 'dart:convert';

import '../constants.dart';
import 'http_client.dart';

/// Looks up TV show names from TMDB.
///
/// The friends list needs nothing from a show but its name, and asking for
/// that through the full detail path would drag in poster handling and season
/// parsing that nothing on that screen uses. This is the narrow version.
///
/// Every lookup is guarded, and an id that will not resolve is simply absent
/// from the result. A friends list is not the place to report that TMDB
/// withdrew an entry, and a throw here would take the whole list down with it.
class TmdbTitles {
  /// Names already fetched this session.
  ///
  /// A show's name does not change between two visits to the friends page, and
  /// the alternative is a fresh request per show every time the tab is opened
  /// or the list is pulled to refresh.
  static final Map<String, String?> _cache = <String, String?>{};

  /// Forgets everything cached. Used when the signed-in user changes, and
  /// between tests, which would otherwise inherit each other's answers.
  static void clearCache() => _cache.clear();

  /// The names for [ids], keyed by id.
  ///
  /// Ids that did not resolve are left out rather than mapped to a placeholder,
  /// so a caller can tell "TMDB has no name for this" from "TMDB says it is
  /// called this".
  /// @param ids The TMDB show ids to name.
  /// @return The names that could be read.
  static Future<Map<String, String>> forShows(Iterable<String> ids) async {
    final unique = <String>{...ids};
    final unknown = unique.where((id) => !_cache.containsKey(id)).toList();

    // In parallel: the list is bounded by the caller, and doing them in turn
    // would leave the friends page waiting on a round trip per show.
    await Future.wait(unknown.map((id) async {
      _cache[id] = await _showName(id);
    }));

    return <String, String>{
      for (final id in unique)
        if (_cache[id] != null) id: _cache[id]!,
    };
  }

  static Future<String?> _showName(String id) async {
    try {
      final response =
          await AppHttp.client.get(Uri.parse('$TV_SHOW_LINK$id$API_KEY'));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final name = decoded['name'];
      if (name is! String || name.trim().isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }
}
