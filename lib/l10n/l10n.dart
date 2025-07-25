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
    Locale('es')
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

  /// No description provided for @errorLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'Error loading images'**
  String get errorLoadingImages;

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

  /// Shown at the end of a title to expand items
  ///
  /// In en, this message translates to:
  /// **'See All ({number} items)'**
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
  /// **'{totalContent} items'**
  String totalContent(String totalContent);

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
      'that was used.');
}
