// The four top level destinations, described once.
//
// The bottom bar and the navigation rail are two presentations of the same
// list, and when each built its own copy they drifted: an icon changed in one
// and not the other. Everything that varies between a phone and a desktop is
// in `AppScaffold`; what the destinations *are* is here.
import 'package:flutter/material.dart';

import '../../friends.dart';
import '../../l10n/l10n.dart';
import '../../main.dart';
import '../../playlists.dart';
import '../../profile.dart';

/// One top level destination.
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.label,
    required this.pageBuilder,
  });

  final IconData icon;

  /// Read from the current locale rather than stored, since the app can change
  /// language without restarting.
  final String Function(BuildContext context) label;

  final Widget Function() pageBuilder;
}

/// The destinations, in the order they appear. The index into this list is
/// what screens pass as their `selectedIndex`.
const List<AppDestination> kAppDestinations = <AppDestination>[
  AppDestination(
    icon: Icons.home,
    label: _homeLabel,
    pageBuilder: _homePage,
  ),
  AppDestination(
    icon: Icons.library_books_rounded,
    label: _libraryLabel,
    pageBuilder: _libraryPage,
  ),
  AppDestination(
    icon: Icons.contacts,
    label: _friendsLabel,
    pageBuilder: _friendsPage,
  ),
  AppDestination(
    icon: Icons.person,
    label: _profileLabel,
    pageBuilder: _profilePage,
  ),
];

String _homeLabel(BuildContext context) => S.of(context)!.home;
String _libraryLabel(BuildContext context) => S.of(context)!.library;
String _friendsLabel(BuildContext context) => S.of(context)!.friends;
String _profileLabel(BuildContext context) => S.of(context)!.profile;

Widget _homePage() => const MyHomePage();
Widget _libraryPage() => const Playlists();
Widget _friendsPage() => const Friends();
Widget _profilePage() => const Profile();

/// The index of the profile destination, which draws the user's photo instead
/// of a generic icon when they have one.
const int kProfileDestinationIndex = 3;

/// The icon for [index], which for the profile is the user's own photo.
Widget destinationIcon(int index, {double size = 27}) {
  if (index == kProfileDestinationIndex) {
    final dynamic photo = currentUser.settings["profile_photo"];
    if (photo != null && photo != "") {
      return ClipOval(
        child: Image.network(
          photo,
          height: size,
          width: size,
          fit: BoxFit.cover,
          // A broken avatar URL must not take the whole navigation bar down
          // with it, which an unhandled image error otherwise does.
          errorBuilder: (context, error, stackTrace) =>
              Icon(kAppDestinations[index].icon),
        ),
      );
    }
  }
  return Icon(kAppDestinations[index].icon);
}

/// Moves to the destination at [index].
///
/// Switching tabs used to push the destination onto the stack unconditionally,
/// so a user moving between the four sections grew the route stack without
/// limit — every tab they had ever visited was still alive underneath, and the
/// system back gesture walked all the way back through them. That is merely
/// untidy on a phone and obviously wrong on a desktop, where the window has a
/// back button and a keyboard shortcut for it.
///
/// The home page is the stack's root, so returning to it pops rather than
/// pushes, and any other destination replaces whatever sat above the root.
/// The stack is then never deeper than the root plus the current section.
void goToDestination(BuildContext context, int index, {int? currentIndex}) {
  if (currentIndex != null && currentIndex == index) return;

  final NavigatorState navigator = Navigator.of(context);
  if (index == 0) {
    navigator.popUntil((route) => route.isFirst);
    return;
  }
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => kAppDestinations[index].pageBuilder()),
    (route) => route.isFirst,
  );
}
