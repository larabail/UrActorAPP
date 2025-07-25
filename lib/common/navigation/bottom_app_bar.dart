// common_bottom_app_bar.dart
// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';

import '../../friends.dart';
import '../../main.dart';

class CommonBottomAppBar extends StatelessWidget {
  int _selectedIndex = 0;
  CommonBottomAppBar(int selectedIndex, {super.key}) {
    _selectedIndex = selectedIndex;
  }

  final List<Widget> pages = [
    const MyHomePage(),
    const Playlists(),
    const Friends(),
    const Profile(),
  ];

  @override
  Widget build(BuildContext context) {
    void onItemTapped(int index) {
      if (_selectedIndex != index) {
        _selectedIndex = index;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => pages[_selectedIndex]),
        );
      }
    }

    return BottomNavigationBar(
      selectedItemColor: _selectedIndex >= 0
          ? const Color.fromARGB(250, 224, 190, 78)
          : Colors.grey,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: S.of(context)!.home,
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books_rounded),
          label: S.of(context)!.library,
        ),
        BottomNavigationBarItem(
          label: S.of(context)!.friends,
          icon: Icon(Icons.contacts),
        ),
        BottomNavigationBarItem(
          label: S.of(context)!.profile,
          icon: currentUser.settings["profile_photo"] != "" &&
                  currentUser.settings["profile_photo"] != null
              ? ClipOval(
                  child: Image.network(
                  currentUser.settings["profile_photo"],
                  height: 27,
                  width: 27,
                  fit: BoxFit.cover,
                ))
              : const Icon(Icons.person),
        ),
      ],
      currentIndex: _selectedIndex >= 0 ? _selectedIndex : 0,
      onTap: onItemTapped,
    );
  }
}
