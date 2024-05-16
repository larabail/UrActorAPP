// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'main.dart';
import 'common/tabView.dart';

// ignore: use_key_in_widget_constructors
class Favorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          child: Expanded(
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Movies'),
                    Tab(text: 'TV Shows'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      MyTabView(favItems: currentUser.favMovies),
                      MyTabView(favItems: currentUser.favTVShows),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      ]),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
