import 'Media.dart';

class TVShow extends MediaItem {
  TVShow({
    required String id,
    required String title,
    required String coverPhoto,
  }) : super(
            id: id,
            title: title,
            coverPhoto: coverPhoto);
}
