// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/tvshow_result.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uractor/main.dart';

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Explore extends StatelessWidget {
  final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
  final String imgLink = 'https://image.tmdb.org/t/p/w500/';
  String link = "https://api.themoviedb.org/3/movie/";
  List<Map<String, dynamic>> movies = [];

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      const MyApp(),
      Search(),
      Playlists(),
      Profile(),
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Text("Explore Page Here"),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121212),
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
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
