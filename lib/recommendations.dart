import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';

class Recommendations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    final List<Widget> _pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _pages[_selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Center(
        child: Text('This is the new page.'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF121212),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            label: 'Profile',
            backgroundColor: Color(0xFF121212),
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
