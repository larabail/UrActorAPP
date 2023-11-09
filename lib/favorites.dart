// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'friends.dart';
import 'playlists.dart';
import 'profile.dart';
import 'search.dart';
import 'main.dart';
import 'tabView.dart';

// ignore: use_key_in_widget_constructors
class Favorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      const MyApp(),
      const Playlists(),
      const Search(),
      const Friends(),
      const Profile(),
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
      appBar: const CustomAppBar(),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            "Your Favorites",
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Movies'),
                  Tab(text: 'TV Shows'),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: TabBarView(
                  children: [
                    MyTabView(favItems: favMovies),
                    MyTabView(favItems: favTVShows),
                  ],
                ),
              ),
            ],
          ),
        )
      ]),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
