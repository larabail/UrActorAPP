// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'main.dart';
import 'common/tab_view.dart';

// ignore: use_key_in_widget_constructors
class Favorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            S.of(context)!.yourSection("Favorites"),
            style: const TextStyle(
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
