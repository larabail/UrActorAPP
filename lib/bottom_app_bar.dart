// common_bottom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';

import 'friends.dart';
import 'main.dart';

// ignore: must_be_immutable
class CommonBottomAppBar extends StatelessWidget {
  int _selectedIndex = 0;
  CommonBottomAppBar(int selectedIndex, {super.key}) {
    _selectedIndex = selectedIndex;
  }

  final List<Widget> pages = [
    const MyApp(),
    const Playlists(),
    // Search(),
    const Friends(),
    const Profile(),
    // Add more pages here
  ];

  @override
  Widget build(BuildContext context) {
    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[_selectedIndex]),
      );
    }

    return BottomNavigationBar(
      selectedItemColor:
          _selectedIndex >= 0 ? const Color.fromARGB(250, 224, 190, 78) : Colors.grey,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.library_books_rounded),
          label: 'Library',
        ),
        // const BottomNavigationBarItem(
        //   icon: Icon(Icons.search),
        //   label: 'Search',
        // ),
        const BottomNavigationBarItem(
          label: 'Friends',
          icon: Icon(Icons.contacts),
        ),
        BottomNavigationBarItem(
          label: 'Profile',
          icon: settings["profile_photo"] != "" &&
                  settings["profile_photo"] != null
              ? ClipOval(
                  child: Image.network(
                  settings["profile_photo"],
                  height: 27,
                  width: 27,
                  fit: BoxFit.cover,
                ))
              : const Icon(Icons.person),
        ),
      ],
      currentIndex: _selectedIndex >= 0 ? _selectedIndex : 0,
      onTap: _onItemTapped,
    );
  }
}
