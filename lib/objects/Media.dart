abstract class MediaItem {
  final String id;
  final String coverPhoto;
  String title;

  MediaItem({
    required this.id,
    required this.title,
    required this.coverPhoto,
  });

  Future<Map> getData();

  Future<Map> getExtendedData();
}
