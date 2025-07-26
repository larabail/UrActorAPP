// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'main.dart';
import 'common/tabView.dart';

class Seen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              S.of(context)!.yourSection(S.of(context)!.seen),
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
                  TabBar(
                    tabs: [
                      Tab(text: S.of(context)!.movies),
                      Tab(text: S.of(context)!.tvShows),
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
