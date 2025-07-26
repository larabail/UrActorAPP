// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class SEs extends S {
  SEs([String locale = 'es']) : super(locale);

  @override
  String get addTVShowToCalendar => 'Agrega un programa de TV a tu calendario';

  @override
  String get selectASpecificDate => 'Selecciona una fecha específica';

  @override
  String get selectADateRange => 'Selecciona un rango de fechas';

  @override
  String get cancel => 'Cancelar';

  @override
  String seenOn(String date) {
    return 'Visto el $date';
  }

  @override
  String get labelSeen => '# Visto';

  @override
  String get labelHoursSpent => 'Horas invertidas';

  @override
  String get labelAvgRating => 'Nota media';

  @override
  String get labelCastAndCrew => 'Reparto y equipo';

  @override
  String get errorFailedToLoadDetails =>
      'Error al cargar los detalles de la película';

  @override
  String get errorLoadingImages => 'Error al cargar las imágenes';

  @override
  String yourSection(String section) {
    return 'Tus $section';
  }

  @override
  String get confirmation => 'Confirmación';

  @override
  String get removeFriendConfirmation =>
      'Estás seguro de que quieres quitarte a este amigo?';

  @override
  String get yes => 'Si';

  @override
  String get no => 'No';

  @override
  String get calendar => 'Calendario';

  @override
  String get noMoviesTogether => 'Aún no habeís visto nada juntos';

  @override
  String friendSections(String title) {
    return 'Sus $title';
  }

  @override
  String get emptySection => 'Nada todavía';

  @override
  String seeAll(int number) {
    return 'Ver todo ($number elementos)';
  }

  @override
  String friendsThoughts(String item) {
    return 'Las opiniones de tus amigos sobre $item';
  }

  @override
  String get errorFailedToLoadFavorites => 'Ha habido un error';

  @override
  String friendLeftNoReview(String friendUsername) {
    return '$friendUsername no ha dejado una reseña';
  }

  @override
  String get addFriend => 'Añadir un amigo';

  @override
  String get noSuchUser => 'No existe ningun usuario con este nombre';

  @override
  String get friendRequests => 'Solicitudes de amistad';

  @override
  String get viewRequests => 'Aprobar o rechazar solicitudes';

  @override
  String get noData => 'No hay solicitudes';

  @override
  String get favorites => 'Favoritas';

  @override
  String get watchlist => 'Siguientes';

  @override
  String get seen => 'Vistas';

  @override
  String get notifications => 'Notificaciones';

  @override
  String totalContent(String totalContent) {
    return '$totalContent elementos';
  }

  @override
  String get reviews => 'Reseñas';

  @override
  String get friends => 'Amigos';

  @override
  String get home => 'Casa';

  @override
  String get library => 'Biblioteca';

  @override
  String get profile => 'Perfil';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get favActors => 'Actores Favoritos';

  @override
  String get favDirectors => 'Directores Favoritos';

  @override
  String get favWriters => 'Escritores Favoritos';

  @override
  String get favMovies => 'Peliculas Más Vistas';

  @override
  String get favTVShows => 'Series Más Vistas';

  @override
  String get loading => 'Cargando...';

  @override
  String requestFrom(String senderUsername) {
    return 'Solicitud de: $senderUsername';
  }

  @override
  String status(String status) {
    return 'Status: $status';
  }
}
