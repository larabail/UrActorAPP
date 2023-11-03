// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'friends.dart';
import 'profile.dart';
import 'search.dart';
import 'main.dart';
import 'list_result.dart';

import 'list_add_popup.dart';
import 'list_join_popup.dart';

Map list_result = {};

class Playlists extends StatefulWidget {
  @override
  _PlaylistsState createState() => _PlaylistsState();
}

class _PlaylistsState extends State<Playlists> {
  bool isJoinListPanelOpen = false;
  bool isAddListPanelOpen = false;

  void _toggleJoinListPanel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ListJoinDialogue();
      },
    );
  }

  void _toggleAddListPanel() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ListAddDialogue();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;


    final List<Widget> pages = [
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
            child: Image.asset(
          'assets/logo_character.png',
          height: 54,
        )),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _toggleJoinListPanel();
                  },
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Join Existing List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors
                        .green, // Change the background color of the button
                    // Change the text color of the button
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _toggleAddListPanel();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.red, // Change the background color of the button
                    // Change the text color of the button
                  ),
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Center(
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
                        list_result["id"] = key;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => ListResult()),
                        );
                      },
                      child: Container(
                        margin:
                            const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 5.0),
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
                              padding: const EdgeInsets.all(16.0),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            label: 'Friends',
            icon: Icon(Icons.contacts),
          ),
          BottomNavigationBarItem(
            label: 'Profile',
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: 1,
        onTap: _onItemTapped,
      ),
    );
  }
}
