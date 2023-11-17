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

  bool isSeen() {
    print(currentUser.seenTVShows);
    return Utils.contains(currentUser.seenTVShows, ['TVShows', id], "TVShows");
  }

  bool isBookmarked() {
    return Utils.contains(currentUser.watchlistTVShows, ['TVShows', id], "TVShows");
  }

  bool isFavorite() {
    return Utils.contains(currentUser.favTVShows, ['TVShows', id], "TVShows");
  }
}
