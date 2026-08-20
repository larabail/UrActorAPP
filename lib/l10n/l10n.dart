import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @addTVShowToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add a TV Shows to Your Calendar'**
  String get addTVShowToCalendar;

  /// No description provided for @selectASpecificDate.
  ///
  /// In en, this message translates to:
  /// **'Select a Specific Date'**
  String get selectASpecificDate;

  /// No description provided for @selectADateRange.
  ///
  /// In en, this message translates to:
  /// **'Select a Date Range'**
  String get selectADateRange;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Shown before a selected watch date
  ///
  /// In en, this message translates to:
  /// **'Seen on {date}'**
  String seenOn(String date);

  /// No description provided for @labelSeen.
  ///
  /// In en, this message translates to:
  /// **'# Seen'**
  String get labelSeen;

  /// No description provided for @labelHoursSpent.
  ///
  /// In en, this message translates to:
  /// **'Hours Spent'**
  String get labelHoursSpent;

  /// No description provided for @labelAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg. Rating'**
  String get labelAvgRating;

  /// No description provided for @labelCastAndCrew.
  ///
  /// In en, this message translates to:
  /// **'Cast & Crew'**
  String get labelCastAndCrew;

  /// No description provided for @errorFailedToLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load movie details'**
  String get errorFailedToLoadDetails;

  /// No description provided for @errorFailedToLoadGeneralDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load details'**
  String get errorFailedToLoadGeneralDetails;

  /// No description provided for @errorLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'Error loading images'**
  String get errorLoadingImages;

  /// No description provided for @yourCalendarSection.
  ///
  /// In en, this message translates to:
  /// **'Your Calendar'**
  String get yourCalendarSection;

  /// Shown as title of a section
  ///
  /// In en, this message translates to:
  /// **'Your {section}'**
  String yourSection(String section);

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @removeFriendConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this friend?'**
  String get removeFriendConfirmation;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @noMoviesTogether.
  ///
  /// In en, this message translates to:
  /// **'Haven\'t watched any movies together yet'**
  String get noMoviesTogether;

  /// Shown as title of a section in a friends profile
  ///
  /// In en, this message translates to:
  /// **'Their {title}'**
  String friendSections(String title);

  /// No description provided for @emptySection.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptySection;

  /// No description provided for @simpleSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get simpleSeeAll;

  /// Shown under see all to show playlist count
  ///
  /// In en, this message translates to:
  /// **'{playlistCount, plural, one{{playlistCount} playlist} other{{playlistCount} playlists}}'**
  String playlistCount(int playlistCount);

  /// Shown at the end of a title to expand items
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{See All ({number} item)} other{See All ({number} items)}}'**
  String seeAll(int number);

  /// Shown when friends have seen the same movie
  ///
  /// In en, this message translates to:
  /// **'Your friends\' opinions on {item}'**
  String friendsThoughts(String item);

  /// No description provided for @errorFailedToLoadFavorites.
  ///
  /// In en, this message translates to:
  /// **'There was an error'**
  String get errorFailedToLoadFavorites;

  /// Shown when a friend has not reviewed the movie
  ///
  /// In en, this message translates to:
  /// **'{friendUsername} hasn\'t left a review'**
  String friendLeftNoReview(String friendUsername);

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get addFriend;

  /// No description provided for @noSuchUser.
  ///
  /// In en, this message translates to:
  /// **'Username does not exist'**
  String get noSuchUser;

  /// No description provided for @friendRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendRequests;

  /// No description provided for @viewRequests.
  ///
  /// In en, this message translates to:
  /// **'Approve or reject requests'**
  String get viewRequests;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No requests found'**
  String get noData;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @watchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlist;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Shown in the playlist cards
  ///
  /// In en, this message translates to:
  /// **'{totalContent, plural, one{{totalContent} item} other{{totalContent} items}}'**
  String totalContent(int totalContent);

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @favActors.
  ///
  /// In en, this message translates to:
  /// **'Favorite Actors'**
  String get favActors;

  /// No description provided for @favDirectors.
  ///
  /// In en, this message translates to:
  /// **'Favorite Directors'**
  String get favDirectors;

  /// No description provided for @favWriters.
  ///
  /// In en, this message translates to:
  /// **'Favorite Writers'**
  String get favWriters;

  /// No description provided for @favMovies.
  ///
  /// In en, this message translates to:
  /// **'Most Watched Movies'**
  String get favMovies;

  /// No description provided for @favTVShows.
  ///
  /// In en, this message translates to:
  /// **'Most Watched TV Shows'**
  String get favTVShows;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Shown when a friend request is received
  ///
  /// In en, this message translates to:
  /// **'Request from: {senderUsername}'**
  String requestFrom(String senderUsername);

  /// Shown as a subtitle while loading
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String status(String status);

  /// Shown when needing access code to share playlist
  ///
  /// In en, this message translates to:
  /// **'Access Code: \'{accessCode}\''**
  String accessCode(String accessCode);

  /// No description provided for @usersAccess.
  ///
  /// In en, this message translates to:
  /// **'Users with access'**
  String get usersAccess;

  /// No description provided for @noUsersAccess.
  ///
  /// In en, this message translates to:
  /// **'No users have access'**
  String get noUsersAccess;

  /// No description provided for @grantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Access To Users'**
  String get grantAccess;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get deleteList;

  /// No description provided for @deleteListConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this list?'**
  String get deleteListConfirmation;

  /// Shown when detailing items in playlist
  ///
  /// In en, this message translates to:
  /// **'Movies: {movieCount}, TV Shows: {tvCount}'**
  String listElements(String movieCount, String tvCount);

  /// No description provided for @newMovies.
  ///
  /// In en, this message translates to:
  /// **'New Movies'**
  String get newMovies;

  /// No description provided for @newShows.
  ///
  /// In en, this message translates to:
  /// **'New Shows'**
  String get newShows;

  /// No description provided for @addMovie.
  ///
  /// In en, this message translates to:
  /// **'Add Movie'**
  String get addMovie;

  /// No description provided for @addShow.
  ///
  /// In en, this message translates to:
  /// **'Add Show'**
  String get addShow;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @tvShows.
  ///
  /// In en, this message translates to:
  /// **'TV Shows'**
  String get tvShows;

  /// No description provided for @needEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address Needed'**
  String get needEmail;

  /// No description provided for @typeEmail.
  ///
  /// In en, this message translates to:
  /// **'Please type an email address'**
  String get typeEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @resetEmail.
  ///
  /// In en, this message translates to:
  /// **'Reset Password Email has been sent'**
  String get resetEmail;

  /// Show when there's an error to send reset password email
  ///
  /// In en, this message translates to:
  /// **'Failed to send password reset email: {e}'**
  String failedResetEmail(String e);

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get yourEmail;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get enterEmail;

  /// No description provided for @yourPassword.
  ///
  /// In en, this message translates to:
  /// **'Your Password'**
  String get yourPassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get enterPassword;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountSignUp;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @writeAReview.
  ///
  /// In en, this message translates to:
  /// **'Write A Review'**
  String get writeAReview;

  /// No description provided for @readAll.
  ///
  /// In en, this message translates to:
  /// **'Read All'**
  String get readAll;

  /// No description provided for @yourReview.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get yourReview;

  /// Shows when a user has entered a review for a movie or show
  ///
  /// In en, this message translates to:
  /// **'Opinion: {opinion}'**
  String opinion(String opinion);

  /// Shows when a user has entered a review for a movie or show
  ///
  /// In en, this message translates to:
  /// **'Rating: {rating}'**
  String rating(String rating);

  /// No description provided for @viewingHistory.
  ///
  /// In en, this message translates to:
  /// **'Viewing History'**
  String get viewingHistory;

  /// No description provided for @noViewingHistory.
  ///
  /// In en, this message translates to:
  /// **'No viewing history available'**
  String get noViewingHistory;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'Haven\'t reviewed any movies yet'**
  String get noReviews;

  /// No description provided for @peopleWatchedwith.
  ///
  /// In en, this message translates to:
  /// **'People watched with'**
  String get peopleWatchedwith;

  /// No description provided for @failedFriends.
  ///
  /// In en, this message translates to:
  /// **'Failed to load friends\' profiles'**
  String get failedFriends;

  /// No description provided for @addFriends.
  ///
  /// In en, this message translates to:
  /// **'Add Friends'**
  String get addFriends;

  /// No description provided for @addDate.
  ///
  /// In en, this message translates to:
  /// **'Add Date'**
  String get addDate;

  /// Shows to tell the user the director of a movie
  ///
  /// In en, this message translates to:
  /// **'Directed by {director}'**
  String directedBy(String director);

  /// No description provided for @written.
  ///
  /// In en, this message translates to:
  /// **'Written'**
  String get written;

  /// No description provided for @screenplay.
  ///
  /// In en, this message translates to:
  /// **'Screenplay'**
  String get screenplay;

  /// No description provided for @by.
  ///
  /// In en, this message translates to:
  /// **'by'**
  String get by;

  /// No description provided for @whereToWatch.
  ///
  /// In en, this message translates to:
  /// **'Where to Watch?'**
  String get whereToWatch;

  /// No description provided for @nowhere.
  ///
  /// In en, this message translates to:
  /// **'Nowhere at the moment'**
  String get nowhere;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// No description provided for @crew.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get crew;

  /// No description provided for @as.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get as;

  /// No description provided for @errorNotification.
  ///
  /// In en, this message translates to:
  /// **'Error marking notifications as read'**
  String get errorNotification;

  /// No description provided for @notificationMessage.
  ///
  /// In en, this message translates to:
  /// **'wants you to check out the'**
  String get notificationMessage;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'movie'**
  String get movie;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'show'**
  String get show;

  /// No description provided for @newNotification.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newNotification;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'ranking'**
  String get ranking;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'progress'**
  String get progress;

  /// No description provided for @yourStats.
  ///
  /// In en, this message translates to:
  /// **'Your Statistics'**
  String get yourStats;

  /// No description provided for @asCast.
  ///
  /// In en, this message translates to:
  /// **'As Part of the Cast'**
  String get asCast;

  /// No description provided for @asCrew.
  ///
  /// In en, this message translates to:
  /// **'As Part of the Crew'**
  String get asCrew;

  /// No description provided for @joinList.
  ///
  /// In en, this message translates to:
  /// **'Join Existing List'**
  String get joinList;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'Add New List'**
  String get newList;

  /// No description provided for @generateRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Generate Handpicked Recommendations'**
  String get generateRecommendation;

  /// No description provided for @recommendationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate recommendations. Please try again later.'**
  String get recommendationsFailed;

  /// No description provided for @fetchingRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Fetching recommendations...'**
  String get fetchingRecommendations;

  /// No description provided for @handpicked.
  ///
  /// In en, this message translates to:
  /// **'Handpicked for You'**
  String get handpicked;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any playlists yet!'**
  String get noPlaylists;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username is already taken'**
  String get usernameTaken;

  /// No description provided for @usernameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Username updated successfully'**
  String get usernameUpdated;

  /// No description provided for @viewingStatistics.
  ///
  /// In en, this message translates to:
  /// **'Viewing Statistics'**
  String get viewingStatistics;

  /// No description provided for @moviesSeenWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Movies seen the week of'**
  String get moviesSeenWeekOf;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @inWord.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get inWord;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @currentRecordMovies.
  ///
  /// In en, this message translates to:
  /// **'Current Record: {maxMovies} movies in a day'**
  String currentRecordMovies(int maxMovies);

  /// No description provided for @totalMovies.
  ///
  /// In en, this message translates to:
  /// **'Total Movies Ever Seen'**
  String get totalMovies;

  /// No description provided for @totalTVShows.
  ///
  /// In en, this message translates to:
  /// **'Total TV Shows Ever Seen'**
  String get totalTVShows;

  /// No description provided for @modifyProfile.
  ///
  /// In en, this message translates to:
  /// **'Modify Profile Sections'**
  String get modifyProfile;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @searchBar.
  ///
  /// In en, this message translates to:
  /// **'Enter name of person/movie/show...'**
  String get searchBar;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noSearchResults;

  /// No description provided for @sortByAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortByAdded;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortByTitle;

  /// No description provided for @sortByReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release date'**
  String get sortByReleaseDate;

  /// No description provided for @sortByMyRating.
  ///
  /// In en, this message translates to:
  /// **'My rating'**
  String get sortByMyRating;

  /// No description provided for @sortByImdbRating.
  ///
  /// In en, this message translates to:
  /// **'IMDb rating'**
  String get sortByImdbRating;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @reorderFriends.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorderFriends;

  /// No description provided for @reorderPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorderPlaylists;

  /// No description provided for @finishReordering.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get finishReordering;

  /// No description provided for @noFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any friends yet!'**
  String get noFriendsYet;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'episodes'**
  String get episodes;

  /// No description provided for @episode.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get episode;

  /// No description provided for @seemWith.
  ///
  /// In en, this message translates to:
  /// **'Seen with'**
  String get seemWith;

  /// No description provided for @seasons.
  ///
  /// In en, this message translates to:
  /// **'seasons'**
  String get seasons;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdBy;

  /// No description provided for @noUserFoundError.
  ///
  /// In en, this message translates to:
  /// **'No user found for that email.'**
  String get noUserFoundError;

  /// No description provided for @wrongPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Wrong password provided for that user.'**
  String get wrongPasswordError;

  /// No description provided for @weakPasswordError.
  ///
  /// In en, this message translates to:
  /// **'The password provided is too weak.'**
  String get weakPasswordError;

  /// No description provided for @emailAlreadyInUseError.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for that email.'**
  String get emailAlreadyInUseError;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'That email address is not valid.'**
  String get invalidEmailError;

  /// No description provided for @genericAuthError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericAuthError;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action will delete all your information.'**
  String get deleteAccountConfirmation;

  /// No description provided for @joinListFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong access code or list name'**
  String get joinListFailed;

  /// No description provided for @joinListTitle.
  ///
  /// In en, this message translates to:
  /// **'Join List'**
  String get joinListTitle;

  /// No description provided for @enterListName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a list name'**
  String get enterListName;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get listName;

  /// No description provided for @accessCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Access Code'**
  String get accessCodeLabel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @confirmWatchedToday.
  ///
  /// In en, this message translates to:
  /// **'Did you watch this movie today?'**
  String get confirmWatchedToday;

  /// No description provided for @deleteCalendarEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete Calendar Entry'**
  String get deleteCalendarEntry;

  /// No description provided for @deleteCalendarEntryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this from just your calendar or everyone\'s?'**
  String get deleteCalendarEntryQuestion;

  /// No description provided for @justMe.
  ///
  /// In en, this message translates to:
  /// **'Just me'**
  String get justMe;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @profileSetupFailedError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t set up your profile, so we undid the account. Please try signing up again.'**
  String get profileSetupFailedError;

  /// No description provided for @profileSetupRollbackFailedError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t set up your profile or undo the account. Please try again later.'**
  String get profileSetupRollbackFailedError;

  /// No description provided for @friendRequestActionFailedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get friendRequestActionFailedError;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'es':
      return SEs();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
