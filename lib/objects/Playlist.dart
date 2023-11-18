class Playlist {
  final String id;
  String name;
  List movies;
  List tvshows;
  String backdrop;
  String accesscode;
  List users;

  Playlist({
    required this.id,
    required this.name,
    required this.movies,
    required this.tvshows,
    required this.backdrop,
    required this.accesscode,
    required this.users,
  });
}
