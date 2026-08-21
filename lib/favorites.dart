// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/navigation/appbar.dart';
import 'main.dart';
import 'common/tab_view.dart';
import 'common/navigation/app_scaffold.dart';

// ignore: use_key_in_widget_constructors
class Favorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
                      MyTabView(
                        favItems: currentUser.favMovies,
                        showFavoriteBadge: false,
                      ),
                      MyTabView(
                        favItems: currentUser.favTVShows,
                        showFavoriteBadge: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      ]),
      selectedIndex: -1,
    );
  }
}
