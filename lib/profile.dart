// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/search.dart';
import 'package:uractor/main.dart';
import 'package:uractor/person_result.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
final String imgLink = 'https://image.tmdb.org/t/p/w500/';
String link = "https://api.themoviedb.org/3/movie/";
int weekOffset = 0; // This will be used to go to previous or next weeks

final months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
];

Future<List<Map>> topMovies() async {
  int i = 0;
  List<Map> movies = [];

  List moviesTemp = [];
  rewatchedMovies.forEach((key, value) {
    moviesTemp.add([value, key]);
  });

  moviesTemp.sort((a, b) => b[0].compareTo(a[0]));

  while (i < 18 && i < moviesTemp.length) {
    Map data;
    String completeLinkMovie =
        link + moviesTemp[i][1].toString() + api_key_actor;

    final response = await http.get(Uri.parse(completeLinkMovie));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      movies.add(json);
    } else {
      throw Exception('Failed to load movie details');
    }
    i++;
  }
  return movies;
}

class Profile extends StatefulWidget {
  Profile();

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;
    DateTime now = DateTime.now();
    DateTime startOfWeek =
        now.subtract(Duration(days: now.weekday - 1 + (7 * weekOffset)));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    Future<List<Map<String, dynamic>>> actorData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favActors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load actor details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

    Future<List<Map<String, dynamic>>> dirData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favDirectors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load director details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

    final List<Widget> pages = [
      const MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    Map filteredData = {};

    Map tempData = Map.fromEntries(calendar.entries.where((entry) {
      DateTime entryDate = DateTime.parse(entry.key);
      return entryDate.isAfter(startOfWeek) && entryDate.isBefore(endOfWeek);
    }));

    // print(tempData);
    for (int i = 0; i <= endOfWeek.difference(startOfWeek).inDays; i++) {
      DateTime currentDay = startOfWeek.add(Duration(days: i));
      if (!tempData.keys.toList().contains(
          DateTime(currentDay.year, currentDay.month, currentDay.day)
              .toIso8601String()
              .split("T")[0])) {
        filteredData[DateTime(currentDay.year, currentDay.month, currentDay.day)
            .toIso8601String()
            .split("T")[0]] = [];
      } else {
        filteredData[DateTime(currentDay.year, currentDay.month, currentDay.day)
                .toIso8601String()
                .split("T")[0]] =
            tempData[DateTime(currentDay.year, currentDay.month, currentDay.day)
                .toIso8601String()
                .split("T")[0]];
      }
    }
    List<BarChartGroupData> chartData = filteredData.entries.map((entry) {
      final day = DateTime.parse(entry.key).day;
      final moviesCount = entry.value.length;
      return BarChartGroupData(x: day, barRods: [
        BarChartRodData(
            y: moviesCount.toDouble(),
            colors: [Colors.blue],
            width: 7 // Adjust this value to change the bar thickness
            )
      ]);
    }).toList();

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    int maxMovies = 0;
    for (var movies in calendar.values) {
      if (movies.length > maxMovies) {
        maxMovies = movies.length;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Center(
          child: Image.asset(
            'assets/logo.png',
            height: 54,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/main_profile.png',
                      height: 200,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              "($country)",
                              style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        )),
                    Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(
                              255, 49, 49, 49), // background color
                          borderRadius:
                              BorderRadius.circular(10), // border radius
                        ),
                        child: ExpansionTile(
                            title: const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                  style: TextStyle(
                                      color: Colors.white,
                                      backgroundColor:
                                          Color.fromARGB(0, 44, 44, 44)),
                                  "Watching Statistics"),
                            ),
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 25),
                                child: Column(
                                  children: [
                                    if (startOfWeek.month == endOfWeek.month)
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          "Movies seen the week of ${startOfWeek.toIso8601String().split("-")[2].split("T")[0]}-${endOfWeek.toIso8601String().split("-")[2].split("T")[0]} in ${months[startOfWeek.month - 1]}",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ),
                                    if (startOfWeek.month != endOfWeek.month)
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          "Movies seen the week of ${startOfWeek.toIso8601String().split("-")[2].split("T")[0]}-${endOfWeek.toIso8601String().split("-")[2].split("T")[0]} in ${months[startOfWeek.month - 1]}-${months[endOfWeek.month - 1]}",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset +=
                                                  1; // Go to the previous week
                                            });
                                          },
                                          child: const Text('<<'),
                                        ),
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset =
                                                  0; // Go to the previous week
                                            });
                                          },
                                          child: const Text('This Week'),
                                        ),
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset -=
                                                  1; // Go to the next week
                                            });
                                          },
                                          child: const Text('>>'),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.2,
                                      width: MediaQuery.of(context).size.width *
                                          0.75,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: chartData,
                                          borderData: FlBorderData(show: false),
                                          titlesData: FlTitlesData(
                                            leftTitles: SideTitles(
                                              showTitles: false,
                                              getTextStyles: (context, value) =>
                                                  const TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 10),
                                            ),
                                            bottomTitles: SideTitles(
                                              showTitles: true,
                                              getTextStyles: (context, value) =>
                                                  const TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        "Your record is $maxMovies movies in a day",
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                            fontSize: 18, color: Colors.yellow),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Text(
                                        "Total Movies Ever Seen: ${seenMovies.length}",
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                            fontSize: 15, color: Colors.white),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Text(
                                        "Total TV Shows Ever Seen: ${seenTVShows.length}",
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                            fontSize: 15, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ])),
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Fav. Actors'),
                              Tab(text: 'Fav. Directors'),
                              Tab(text: 'Most Seen'),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.655,
                            child: TabBarView(
                              children: [
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: actorData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    // Handle the click event here
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
                                                              'profile_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: dirData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
                                                              'profile_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                                FutureBuilder<List<Map>>(
                                  future: topMovies(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    // Handle the click event here
                                                    movieResult = [
                                                      leftMovie['id'],
                                                      leftMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            imgLink +
                                                                leftMovie[
                                                                    'poster_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    movieResult = [
                                                      middleMovie['id'],
                                                      middleMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            imgLink +
                                                                middleMovie[
                                                                    'poster_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    movieResult = [
                                                      rightMovie['id'],
                                                      rightMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          imgLink +
                                                              rightMovie[
                                                                  'poster_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.logout_outlined,
                color: Colors.white,
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                email = "";
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
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
        currentIndex: 3,
        onTap: _onItemTapped,
      ),
    );
  }
}
