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
}
