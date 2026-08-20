// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get addTVShowToCalendar => 'Add a TV Shows to Your Calendar';

  @override
  String get selectASpecificDate => 'Select a Specific Date';

  @override
  String get selectADateRange => 'Select a Date Range';

  @override
  String get cancel => 'Cancel';

  @override
  String seenOn(String date) {
    return 'Seen on $date';
  }

  @override
  String get labelSeen => '# Seen';

  @override
  String get labelHoursSpent => 'Hours Spent';

  @override
  String get labelAvgRating => 'Avg. Rating';

  @override
  String get labelCastAndCrew => 'Cast & Crew';

  @override
  String get errorFailedToLoadDetails => 'Failed to load movie details';

  @override
  String get errorFailedToLoadGeneralDetails => 'Failed to load details';

  @override
  String get errorLoadingImages => 'Error loading images';

  @override
  String get yourCalendarSection => 'Your Calendar';

  @override
  String yourSection(String section) {
    return 'Your $section';
  }

  @override
  String get confirmation => 'Confirmation';

  @override
  String get removeFriendConfirmation =>
      'Are you sure you want to remove this friend?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get calendar => 'Calendar';

  @override
  String get noMoviesTogether => 'Haven\'t watched any movies together yet';

  @override
  String friendSections(String title) {
    return 'Their $title';
  }

  @override
  String get emptySection => 'Nothing here yet';

  @override
  String get simpleSeeAll => 'See All';

  @override
  String playlistCount(int playlistCount) {
    String _temp0 = intl.Intl.pluralLogic(
      playlistCount,
      locale: localeName,
      other: '$playlistCount playlists',
      one: '$playlistCount playlist',
    );
    return '$_temp0';
  }

  @override
  String seeAll(int number) {
    String _temp0 = intl.Intl.pluralLogic(
      number,
      locale: localeName,
      other: 'See All ($number items)',
      one: 'See All ($number item)',
    );
    return '$_temp0';
  }

  @override
  String friendsThoughts(String item) {
    return 'Your friends\' opinions on $item';
  }

  @override
  String get errorFailedToLoadFavorites => 'There was an error';

  @override
  String friendLeftNoReview(String friendUsername) {
    return '$friendUsername hasn\'t left a review';
  }

  @override
  String get addFriend => 'Add Friend';

  @override
  String get noSuchUser => 'Username does not exist';

  @override
  String get friendRequests => 'Friend requests';

  @override
  String get viewRequests => 'Approve or reject requests';

  @override
  String get noData => 'No requests found';

  @override
  String get favorites => 'Favorites';

  @override
  String get watchlist => 'Watchlist';

  @override
  String get seen => 'Seen';

  @override
  String get notifications => 'Notifications';

  @override
  String totalContent(int totalContent) {
    String _temp0 = intl.Intl.pluralLogic(
      totalContent,
      locale: localeName,
      other: '$totalContent items',
      one: '$totalContent item',
    );
    return '$_temp0';
  }

  @override
  String get reviews => 'Reviews';

  @override
  String get friends => 'Friends';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get profile => 'Profile';

  @override
  String get username => 'Username';

  @override
  String get favActors => 'Favorite Actors';

  @override
  String get favDirectors => 'Favorite Directors';

  @override
  String get favWriters => 'Favorite Writers';

  @override
  String get favMovies => 'Most Watched Movies';

  @override
  String get favTVShows => 'Most Watched TV Shows';

  @override
  String get loading => 'Loading...';

  @override
  String requestFrom(String senderUsername) {
    return 'Request from: $senderUsername';
  }

  @override
  String status(String status) {
    return 'Status: $status';
  }

  @override
  String accessCode(String accessCode) {
    return 'Access Code: \'$accessCode\'';
  }

  @override
  String get usersAccess => 'Users with access';

  @override
  String get noUsersAccess => 'No users have access';

  @override
  String get grantAccess => 'Grant Access To Users';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get leave => 'Leave';

  @override
  String get deleteList => 'Delete List';

  @override
  String get deleteListConfirmation =>
      'Are you sure you want to delete this list?';

  @override
  String listElements(String movieCount, String tvCount) {
    return 'Movies: $movieCount, TV Shows: $tvCount';
  }

  @override
  String get newMovies => 'New Movies';

  @override
  String get newShows => 'New Shows';

  @override
  String get addMovie => 'Add Movie';

  @override
  String get addShow => 'Add Show';

  @override
  String get movies => 'Movies';

  @override
  String get tvShows => 'TV Shows';

  @override
  String get needEmail => 'Email Address Needed';

  @override
  String get typeEmail => 'Please type an email address';

  @override
  String get password => 'Password';

  @override
  String get resetEmail => 'Reset Password Email has been sent';

  @override
  String failedResetEmail(String e) {
    return 'Failed to send password reset email: $e';
  }

  @override
  String get yourEmail => 'Your email';

  @override
  String get email => 'Email';

  @override
  String get login => 'Login';

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get yourPassword => 'Your Password';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get noAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get okay => 'Okay';

  @override
  String get writeAReview => 'Write A Review';

  @override
  String get readAll => 'Read All';

  @override
  String get yourReview => 'Your Review';

  @override
  String opinion(String opinion) {
    return 'Opinion: $opinion';
  }

  @override
  String rating(String rating) {
    return 'Rating: $rating';
  }

  @override
  String get viewingHistory => 'Viewing History';

  @override
  String get noViewingHistory => 'No viewing history available';

  @override
  String get noReviews => 'Haven\'t reviewed any movies yet';

  @override
  String get peopleWatchedwith => 'People watched with';

  @override
  String get failedFriends => 'Failed to load friends\' profiles';

  @override
  String get addFriends => 'Add Friends';

  @override
  String get addDate => 'Add Date';

  @override
  String directedBy(String director) {
    return 'Directed by $director';
  }

  @override
  String get written => 'Written';

  @override
  String get screenplay => 'Screenplay';

  @override
  String get by => 'by';

  @override
  String get whereToWatch => 'Where to Watch?';

  @override
  String get nowhere => 'Nowhere at the moment';

  @override
  String get cast => 'Cast';

  @override
  String get crew => 'Crew';

  @override
  String get as => 'playing';

  @override
  String get errorNotification => 'Error marking notifications as read';

  @override
  String get notificationMessage => 'wants you to check out the';

  @override
  String get movie => 'movie';

  @override
  String get show => 'show';

  @override
  String get newNotification => 'NEW';

  @override
  String get ranking => 'ranking';

  @override
  String get progress => 'progress';

  @override
  String get yourStats => 'Your Statistics';

  @override
  String get asCast => 'As Part of the Cast';

  @override
  String get asCrew => 'As Part of the Crew';

  @override
  String get joinList => 'Join Existing List';

  @override
  String get newList => 'Add New List';

  @override
  String get generateRecommendation => 'Generate Handpicked Recommendations';

  @override
  String get recommendationsFailed =>
      'Couldn\'t generate recommendations. Please try again later.';

  @override
  String get fetchingRecommendations => 'Fetching recommendations...';

  @override
  String get handpicked => 'Handpicked for You';

  @override
  String get noPlaylists => 'You don\'t have any playlists yet!';

  @override
  String get usernameTaken => 'Username is already taken';

  @override
  String get usernameUpdated => 'Username updated successfully';

  @override
  String get viewingStatistics => 'Viewing Statistics';

  @override
  String get moviesSeenWeekOf => 'Movies seen the week of';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get inWord => 'in';

  @override
  String get thisWeek => 'This Week';

  @override
  String currentRecordMovies(int maxMovies) {
    return 'Current Record: $maxMovies movies in a day';
  }

  @override
  String get totalMovies => 'Total Movies Ever Seen';

  @override
  String get totalTVShows => 'Total TV Shows Ever Seen';

  @override
  String get modifyProfile => 'Modify Profile Sections';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get unknown => 'Unknown';

  @override
  String get searchBar => 'Enter name of person/movie/show...';

  @override
  String get noSearchResults => 'No results found';

  @override
  String get sortByAdded => 'Date added';

  @override
  String get sortByTitle => 'Title';

  @override
  String get sortByReleaseDate => 'Release date';

  @override
  String get sortByMyRating => 'My rating';

  @override
  String get sortByImdbRating => 'IMDb rating';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get reorderFriends => 'Reorder';

  @override
  String get reorderPlaylists => 'Reorder';

  @override
  String get finishReordering => 'Done';

  @override
  String get noFriendsYet => 'You haven\'t added any friends yet!';

  @override
  String get episodes => 'episodes';

  @override
  String get episode => 'Episode';

  @override
  String get seemWith => 'Seen with';

  @override
  String get seasons => 'seasons';

  @override
  String get apply => 'Apply';

  @override
  String get createdBy => 'Created by';

  @override
  String get noUserFoundError => 'No user found for that email.';

  @override
  String get wrongPasswordError => 'Wrong password provided for that user.';

  @override
  String get weakPasswordError => 'The password provided is too weak.';

  @override
  String get emailAlreadyInUseError =>
      'An account already exists for that email.';

  @override
  String get invalidEmailError => 'That email address is not valid.';

  @override
  String get genericAuthError => 'Something went wrong. Please try again.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to delete your account? This action will delete all your information.';

  @override
  String get joinListFailed => 'Wrong access code or list name';

  @override
  String get joinListTitle => 'Join List';

  @override
  String get enterListName => 'Please enter a list name';

  @override
  String get listName => 'List Name';

  @override
  String get accessCodeLabel => 'Access Code';

  @override
  String get add => 'Add';

  @override
  String get confirmWatchedToday => 'Did you watch this movie today?';

  @override
  String get deleteCalendarEntry => 'Delete Calendar Entry';

  @override
  String get deleteCalendarEntryQuestion =>
      'Do you want to delete this from just your calendar or everyone\'s?';

  @override
  String get justMe => 'Just me';

  @override
  String get everyone => 'Everyone';
}
