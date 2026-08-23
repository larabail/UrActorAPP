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
  String get errorFailedToLoadGeneralDetails => 'Error al cargar los detalles';

  @override
  String get errorLoadingImages => 'Error al cargar las imágenes';

  @override
  String get yourCalendarSection => 'Tu Calendario';

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
  String get simpleSeeAll => 'Ver Todas';

  @override
  String playlistCount(int playlistCount) {
    String _temp0 = intl.Intl.pluralLogic(
      playlistCount,
      locale: localeName,
      other: '$playlistCount listas',
      one: '$playlistCount lista',
    );
    return '$_temp0';
  }

  @override
  String seeAll(int number) {
    String _temp0 = intl.Intl.pluralLogic(
      number,
      locale: localeName,
      other: 'Ver todo ($number elementos)',
      one: 'Ver todo ($number elemento)',
    );
    return '$_temp0';
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
  String get continueWatching => 'Seguir viendo';

  @override
  String nextEpisode(int season, int episode) {
    return 'Siguiente: T$season E$episode';
  }

  @override
  String get watchingTogether => 'Viendo juntos';

  @override
  String watchingTogetherTitles(String titles) {
    return 'Viendo juntos: $titles';
  }

  @override
  String get notifications => 'Notificaciones';

  @override
  String totalContent(int totalContent) {
    String _temp0 = intl.Intl.pluralLogic(
      totalContent,
      locale: localeName,
      other: '$totalContent elementos',
      one: '$totalContent elemento',
    );
    return '$_temp0';
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
    return 'Estado: $status';
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
  String get movies => 'Películas';

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
  String viewingHistoryRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String viewingHistoryRangeOpen(String start) {
    return '$start – presente';
  }

  @override
  String get noViewingHistory => 'No hay historial de visualización';

  @override
  String get noReviews => 'No has dejado ninguna reseña todavía';

  @override
  String get peopleWatchedwith => 'Con quien la has visto';

  @override
  String get failedFriends =>
      'Ha habido un error cargando los perfiles de tus amigos';

  @override
  String get addFriends => 'Añadir amigos';

  @override
  String get addDate => 'Añadir fecha';

  @override
  String directedBy(String director) {
    return 'Dirigida por $director';
  }

  @override
  String get written => 'Escrita';

  @override
  String get screenplay => 'Guión';

  @override
  String get by => 'por';

  @override
  String get whereToWatch => '¿Dónde ver?';

  @override
  String get nowhere => 'En ningún sitio por el momento';

  @override
  String get cast => 'Reparto';

  @override
  String get crew => 'Equipo';

  @override
  String get as => 'interpretando a';

  @override
  String get errorNotification =>
      'Ha habido un error marcando la notificación como leida';

  @override
  String get notificationMessage => 'quiere que veas la';

  @override
  String get movie => 'película';

  @override
  String get show => 'serie';

  @override
  String get newNotification => 'NUEVA';

  @override
  String get ranking => 'ranking';

  @override
  String get progress => 'progreso';

  @override
  String get yourStats => 'Tus Estadísticas';

  @override
  String get asCast => 'Parte del Reparto';

  @override
  String get asCrew => 'Parte del Equipo';

  @override
  String get joinList => 'Unirse a Lista';

  @override
  String get newList => 'Añadir Lista';

  @override
  String get generateRecommendation => 'Generar Recomendaciones';

  @override
  String get recommendationsFailed =>
      'No se pudieron generar recomendaciones. Inténtalo de nuevo más tarde.';

  @override
  String get fetchingRecommendations => 'Generando recomendaciones...';

  @override
  String get handpicked => 'Recomendaciones Para Ti';

  @override
  String get noPlaylists => 'Aun no tienes listas de reproducción';

  @override
  String get usernameTaken => 'Este nombre de usuario ya está cogido';

  @override
  String get usernameUpdated => 'Nombre de usuario actualizado';

  @override
  String get viewingStatistics => 'Estadísticas de visualización';

  @override
  String get moviesSeenWeekOf => 'Películas vistas la semana del';

  @override
  String get january => 'Enero';

  @override
  String get february => 'Febrero';

  @override
  String get march => 'Marzo';

  @override
  String get april => 'Abril';

  @override
  String get may => 'Mayo';

  @override
  String get june => 'Junio';

  @override
  String get july => 'Julio';

  @override
  String get august => 'Agosto';

  @override
  String get september => 'Septiembre';

  @override
  String get october => 'Octubre';

  @override
  String get november => 'Noviembre';

  @override
  String get december => 'Diciembre';

  @override
  String get inWord => 'en';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String currentRecordMovies(int maxMovies) {
    return 'Record actual: $maxMovies películas en un día';
  }

  @override
  String get totalMovies => 'Películas Vistas en Total';

  @override
  String get totalTVShows => 'Series Vistas en Total';

  @override
  String get modifyProfile => 'Modificar Secciones';

  @override
  String get noDataAvailable => 'No hay información';

  @override
  String get unknown => 'Desconocido';

  @override
  String get searchBar => 'Escribe el nombre de una persona/película/serie...';

  @override
  String get noSearchResults => 'No se encontraron resultados';

  @override
  String get sortByAdded => 'Fecha de adición';

  @override
  String get sortByTitle => 'Título';

  @override
  String get sortByReleaseDate => 'Fecha de estreno';

  @override
  String get sortByMyRating => 'Mi valoración';

  @override
  String get sortByImdbRating => 'Valoración de IMDb';

  @override
  String get sortAscending => 'Ascendente';

  @override
  String get sortDescending => 'Descendente';

  @override
  String get reorderFriends => 'Reordenar';

  @override
  String get reorderPlaylists => 'Reordenar';

  @override
  String get finishReordering => 'Listo';

  @override
  String get noFriendsYet => '¡Todavía no has añadido ningún amigo!';

  @override
  String get episodes => 'episodios';

  @override
  String get episode => 'Episodio';

  @override
  String get seemWith => 'Vistas con';

  @override
  String get seasons => 'temporadas';

  @override
  String get apply => 'Aplicar';

  @override
  String get createdBy => 'Creada por';

  @override
  String get noUserFoundError =>
      'No se encontró ningún usuario con ese correo electrónico.';

  @override
  String get wrongPasswordError => 'Contraseña incorrecta para ese usuario.';

  @override
  String get weakPasswordError =>
      'La contraseña proporcionada es demasiado débil.';

  @override
  String get emailAlreadyInUseError =>
      'Ya existe una cuenta con ese correo electrónico.';

  @override
  String get invalidEmailError =>
      'Esa dirección de correo electrónico no es válida.';

  @override
  String get genericAuthError =>
      'Algo salió mal. Por favor, inténtalo de nuevo.';

  @override
  String get deleteAccount => 'Eliminar Cuenta';

  @override
  String get deleteAccountConfirmation =>
      '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción eliminará toda tu información.';

  @override
  String get joinListFailed => 'Código de acceso o nombre de lista incorrecto';

  @override
  String get joinListTooManyAttempts =>
      'Demasiados intentos incorrectos. Inténtalo de nuevo más tarde.';

  @override
  String get joinListMissingDetails =>
      'Introduce el nombre de la lista y el código de acceso.';

  @override
  String get joinListUnavailable =>
      'No se ha podido unir a la lista. Inténtalo de nuevo.';

  @override
  String get joinListTitle => 'Unirse a Lista';

  @override
  String get recommendationSendFailed =>
      'No se ha podido enviar tu recomendación. Inténtalo de nuevo.';

  @override
  String get recommendationSendPartial =>
      'No se ha podido enviar esto a algunos de tus amigos.';

  @override
  String get enterListName => 'Por favor, introduce un nombre de lista';

  @override
  String get listName => 'Nombre de la Lista';

  @override
  String get accessCodeLabel => 'Código de Acceso';

  @override
  String get add => 'Añadir';

  @override
  String get accept => 'Aceptar';

  @override
  String get confirmWatchedToday => '¿Has visto esta película hoy?';

  @override
  String get deleteCalendarEntry => 'Eliminar Entrada del Calendario';

  @override
  String get deleteCalendarEntryQuestion =>
      '¿Quieres eliminar esto solo de tu calendario o del de todos?';

  @override
  String get justMe => 'Solo yo';

  @override
  String get everyone => 'Todos';

  @override
  String get profileSetupFailedError =>
      'No pudimos configurar tu perfil, así que deshicimos la cuenta. Por favor, regístrate de nuevo.';

  @override
  String get profileSetupRollbackFailedError =>
      'No pudimos configurar tu perfil ni deshacer la cuenta. Por favor, inténtalo de nuevo más tarde.';

  @override
  String get favoriteBadge => 'En tus favoritas';

  @override
  String get watchlistBadge => 'En tu lista de pendientes';

  @override
  String get friendRequestActionFailedError =>
      'Algo salió mal. Por favor, inténtalo de nuevo.';

  @override
  String get watchProgress => 'Progreso';

  @override
  String get watchProgressNotStarted => 'Sin empezar';

  @override
  String get watchProgressInProgress => 'Viendo';

  @override
  String get watchProgressFinished => 'Terminada';

  @override
  String watchProgressStartedOn(String date) {
    return 'Viéndola desde el $date';
  }

  @override
  String watchProgressFinishedOn(String date) {
    return 'Terminada el $date';
  }

  @override
  String get watchProgressStart => 'Empezar a ver';

  @override
  String get watchProgressFinish => 'Marcar como terminada';

  @override
  String get watchProgressReopen => 'Volver a verla';

  @override
  String get watchProgressMarkSeason => 'Marcar la temporada como vista';

  @override
  String get watchProgressUnmarkSeason => 'Borrar esta temporada';

  @override
  String get watchProgressMarkEpisode => 'Marcar el episodio como visto';

  @override
  String get watchProgressUnmarkEpisode => 'Desmarcar el episodio';

  @override
  String watchProgressEpisodesWatched(int watched, int total) {
    return '$watched de $total vistos';
  }

  @override
  String get calendarEpisodeSectionTitle =>
      '¿Cuál es el último episodio que terminaste hoy?';

  @override
  String get calendarEpisodeBackfillNote =>
      'Todo lo anterior se marca como visto.';

  @override
  String get calendarSeasonFieldLabel => 'Temporada (opcional)';

  @override
  String get calendarEpisodeFieldLabel => 'Episodio (opcional)';

  @override
  String get calendarEpisodeNeedsSeason =>
      'Añade el número de temporada para guardar un episodio.';

  @override
  String calendarSeasonEpisodeBadge(int season, int episode) {
    return 'T$season E$episode';
  }

  @override
  String calendarSeasonBadge(int season) {
    return 'T$season';
  }

  @override
  String get watchTrailerOnYoutube => 'Ver el tráiler en YouTube';

  @override
  String get detailPanePlaceholder => 'Elige algo para verlo aquí';

  @override
  String get userDisabledError => 'Esa cuenta ha sido deshabilitada.';

  @override
  String get tooManyRequestsError =>
      'Demasiados intentos. Espera un momento y vuelve a intentarlo.';

  @override
  String get networkError =>
      'No se pudo conectar con el servidor. Comprueba tu conexión.';

  @override
  String get blockedAppError =>
      'Esta versión de la aplicación no tiene permiso para iniciar sesión. Volver a intentarlo no servirá de nada.';

  @override
  String get invalidCredentialError =>
      'Ese correo electrónico y esa contraseña no coinciden con ninguna cuenta.';

  @override
  String updateAvailable(String version) {
    return 'UrActor $version ya está disponible';
  }

  @override
  String get updateDownload => 'Descargar';

  @override
  String get updateDismiss => 'Descartar';
}
