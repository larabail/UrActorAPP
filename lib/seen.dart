// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'main.dart';
import 'tabView.dart';

class Seen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "Seen",
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DefaultTabController(
            length: 2,
            child: Expanded(
              // Wrap the TabBar and TabBarView with Expanded
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Movies'),
                      Tab(text: 'TV Shows'),
                    ],
                  ),
                  Expanded(
                    // This Expanded widget is for the TabBarView
                    child: TabBarView(
                      children: [
                        MyTabView(favItems: currentUser.seenMovies),
                        MyTabView(favItems: currentUser.seenTVShows),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
