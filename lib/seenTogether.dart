// ignore_for_file: must_be_immutable

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/friends.dart';

import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'main.dart';
import 'tabView.dart';

class SeenTogether extends StatelessWidget {
  final Map friendSettings;
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";
  List<Map<String, dynamic>> movies = [];

  SeenTogether({super.key, required this.friendSettings});

  Future<Map<String, dynamic>> getData(id, type) async {
    Map<String, dynamic> data = {};
    if (type == "TVShows") {
      link = 'https://api.themoviedb.org/3/tv/';
    } else {
      link = 'https://api.themoviedb.org/3/movie/';
    }
    final response = await http.get(Uri.parse('$link$id$api_key_actor'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (type == "TVShows") {
        data['title'] = json['name'];
      } else {
        data['title'] = json['title'];
      }
      if (json['poster_path'] == null) {
        data['poster'] = 'assets/question_mark.png';
      } else {
        data['poster'] = imgLink + json['poster_path'];
      }
      data['id'] = json['id'];
      data['type'] = type;
      if (!containsMap(movies, data)) {
        movies.add(data);
      }
    } else {
      throw Exception('Failed to load movie details');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "Seen with ${friendSettings['username']}",
              style: const TextStyle(
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
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: TabBarView(
                    children: [
                      MyTabView(favItems: [
                        for (String movieId
                            in (seenWith[friendUid]["Movies"] as List<dynamic>?)
                                    ?.reversed
                                    .toList() ??
                                [])
                          ["Movies", movieId]
                      ]),
                      MyTabView(favItems: [
                        for (String movieId in (seenWith[friendUid]["TVShows"]
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
          )
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
