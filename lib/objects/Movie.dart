import 'Media.dart';

class Movie extends MediaItem {
  Movie({
    required String id,
    required String title,
    required String coverPhoto,
  }) : super(
            id: id,
            title: title,
            coverPhoto: coverPhoto);
}
