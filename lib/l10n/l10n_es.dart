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

  @override
  String accessCode(String accessCode) {
    return 'Codigo de Acceso: \'$accessCode\'';
  }

  @override
  String get usersAccess => 'Usuarios con acceso';

  @override
  String get noUsersAccess => 'Ningún usuario tiene acceso';

  @override
  String get grantAccess => 'Dar Acceso a Usuarios';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Borrar';

  @override
  String get leave => 'Quitar';

  @override
  String get deleteList => 'Borrar Lista';

  @override
  String get deleteListConfirmation =>
      'Estás seguro de que quieres borrar esta lista?';

  @override
  String listElements(String movieCount, String tvCount) {
    return 'Peliculas: $movieCount, Series: $tvCount';
  }

  @override
  String get newMovies => 'Peliculas Nuevas';

  @override
  String get newShows => 'Series Nuevas';

  @override
  String get addMovie => 'Añadir Pelicula';

  @override
  String get addShow => 'Añadir Serie';

  @override
  String get movies => 'Peliculas';

  @override
  String get tvShows => 'Series';

  @override
  String get needEmail => 'Email es Necesario';

  @override
  String get typeEmail => 'Por favor indique un email';

  @override
  String get password => 'Contraseña';

  @override
  String get resetEmail =>
      'Se ha enviado un correo electrónico para restablecer la contraseña';

  @override
  String failedResetEmail(String e) {
    return 'Ha habido un error al restablecer la contraseña: $e';
  }

  @override
  String get yourEmail => 'Tu correo electrónico';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get enterEmail => 'Por favor ingresa tu correo electrónico';

  @override
  String get yourPassword => 'Tu contraseña';

  @override
  String get enterPassword => 'Por favor ingresa tu contraseña';

  @override
  String get noAccountSignUp => '¿No tienes una cuenta? Regístrate';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get okay => 'Aceptar';

  @override
  String get writeAReview => 'Escribe Una Reseña';

  @override
  String get readAll => 'Leer Todo';

  @override
  String get yourReview => 'Tu Reseña';

  @override
  String opinion(String opinion) {
    return 'Opinión: $opinion';
  }

  @override
  String rating(String rating) {
    return 'Nota: $rating';
  }

  @override
  String get viewingHistory => 'Historial de Visualización';

  @override
  String get noViewingHistory => 'No hay historial de visualización';
}
