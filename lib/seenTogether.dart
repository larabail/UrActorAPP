// ignore_for_file: must_be_immutable
import 'package:flutter/material.dart';
import 'package:uractor/friends.dart';
import 'package:uractor/l10n/l10n.dart';

import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'main.dart';
import 'common/tabView.dart';

class SeenTogether extends StatelessWidget {
  final Map friendSettings;
  List<Map<String, dynamic>> movies = [];

  SeenTogether({super.key, required this.friendSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "${S.of(context)!.seemWith} ${friendSettings['username']}",
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
                  TabBar(
                    tabs: [
                      Tab(text: S.of(context)!.movies),
                      Tab(text: S.of(context)!.tvShows),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        MyTabView(favItems: [
                          for (String movieId
                              in (currentUser.seenWith[friendUid]["Movies"]
                                          as List<dynamic>?)
                                      ?.reversed
                                      .toList() ??
                                  [])
                            ["Movies", movieId]
                        ]),
                        MyTabView(favItems: [
                          for (String movieId
                              in (currentUser.seenWith[friendUid]["TVShows"]
                                          as List<dynamic>?)
                                      ?.reversed
                                      .toList() ??
                                  [])
                            ["TVShows", movieId]
                        ]),
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
