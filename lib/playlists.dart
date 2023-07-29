import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/list_result.dart';

Map list_result = {};

class Playlists extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    dynamic movies = [];
    dynamic tvshows = [];
    dynamic accessCode = "";

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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            String key = playlists.keys.elementAt(index);
            dynamic value = playlists[key]['Name'];
            dynamic image = playlists[key]['CoverPhoto'];
            dynamic movies = playlists[key]['Movies'];
            dynamic tvshows = playlists[key]['TV Shows'];
            dynamic accessCode = playlists[key]['AccessCode'];
            return GestureDetector(
              onTap: () {
                // Handle the click event here
                list_result["Movies"] = movies;
                list_result["TVShows"] = tvshows;
                list_result["Backdrop"] = image;
                list_result["Name"] = value;
                list_result["AccessCode"] = accessCode;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListResult()),
                );
              },
              child: Container(
                margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(
                            image,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(1),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
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
        currentIndex: 2,
        onTap: _onItemTapped,
      ),
    );
  }
}
