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
  String get errorLoadingImages => 'Error loading images';

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
  String seeAll(int number) {
    return 'See All ($number items)';
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
  String totalContent(String totalContent) {
    return '$totalContent items';
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
}
