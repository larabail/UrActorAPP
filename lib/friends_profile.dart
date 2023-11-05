import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'bottom_app_bar.dart';
import 'friends.dart';
import 'playlists.dart';
import 'search.dart';
import 'main.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

const String imgLink = 'https://image.tmdb.org/t/p/w500/';

const String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
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

class FriendProfile extends StatefulWidget {
  FriendProfile({required String friendUid});

  @override
  _FriendProfileState createState() => _FriendProfileState();
}

class _FriendProfileState extends State<FriendProfile> {
  List friendFavActors = [];
  Map friendSettings = {};
  Map friendRewatchedMovies = {};
  List friendFavDirectors = [];
  Map friendCalendar = {};
  bool gotData = false;
  Future<List<Map>> topMovies() async {
    int i = 0;
    List<Map> movies = [];

    List moviesTemp = [];
    friendRewatchedMovies.forEach((key, value) {
      moviesTemp.add([value, key]);
    });

    moviesTemp.sort((a, b) => b[0].compareTo(a[0]));

    while (i < 18 && i < moviesTemp.length) {
      String completeLinkMovie =
          link + moviesTemp[i][1].toString() + api_key_actor;

      final response = await http.get(Uri.parse(completeLinkMovie));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        movies.add(json);
      } else {
        throw Exception('Failed to load actor details');
      }
      i++;
    }
    return movies;
  }

  Future<void> getFirebaseData() async {
    await FirebaseFirestore.instance
        .collection(friendUid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "FavActors" && friendFavActors.isEmpty) {
          Map tempFavActors = doc.data() as Map;
          friendFavActors = tempFavActors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          friendFavActors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "FavDirectors" && friendFavDirectors.isEmpty) {
          Map tempFavDirectors = doc.data() as Map;
          friendFavDirectors = tempFavDirectors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          friendFavDirectors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "Settings" &&
            friendSettings.keys.toList().isEmpty) {
          friendSettings = doc.data() as Map;
        } else if (doc.id == "Rewatched" &&
            friendRewatchedMovies.keys.isEmpty) {
          friendRewatchedMovies = doc.data() as Map;
        } else if (doc.id == "Calendar" && friendCalendar.keys.isEmpty) {
          friendCalendar = doc.data() as Map;
        }
      }
    });
    setState(() {
      gotData = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getFirebaseData();
  }

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
      for (List item in friendFavActors) {
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
      for (List item in friendFavDirectors) {
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
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
      // Add more pages here
    ];

    Map filteredData = {};

    Map tempData = Map.fromEntries(friendCalendar.entries.where((entry) {
      DateTime entryDate = DateTime.parse(entry.key);
      return entryDate.isAfter(startOfWeek.add(const Duration(days: -1))) &&
          entryDate.isBefore(endOfWeek);
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
    for (var movies in friendCalendar.values) {
      if (movies.length > maxMovies) {
        maxMovies = movies.length;
      }
    }
    if (gotData) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Center(
            child: Image.asset(
              'assets/logo_character.png',
              height: 54,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: friendSettings["profile_photo"] != ""
                            ? Image.network(
                                friendSettings["profile_photo"],
                                height: 200,
                                width: 200,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/main_profile.png',
                                height: 200,
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          left: 16.0), // Add margin here
                                      child: Text(
                                        friendSettings["username"],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Text(
                              //   email,
                              //   style: const TextStyle(
                              //     fontSize: 25,
                              //     fontWeight: FontWeight.bold,
                              //   ),
                              // ),
                            ],
                          )),
                      Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(10), // border radius
                          ),
                          child: ExpansionTile(
                              title: const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text("Viewing Statistics"),
                              ),
                              children: <Widget>[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 25),
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
                                            ),
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
                                            ),
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
                                                          Color>(
                                                      Colors.transparent),
                                              elevation:
                                                  MaterialStateProperty.all(
                                                      0.0),
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
                                                          Color>(
                                                      Colors.transparent),
                                              elevation:
                                                  MaterialStateProperty.all(
                                                      0.0),
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
                                                          Color>(
                                                      Colors.transparent),
                                              elevation:
                                                  MaterialStateProperty.all(
                                                      0.0),
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
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.75,
                                        child: BarChart(
                                          BarChartData(
                                            barGroups: chartData,
                                            borderData:
                                                FlBorderData(show: false),
                                            titlesData: FlTitlesData(
                                              leftTitles: SideTitles(
                                                showTitles: false,
                                                getTextStyles:
                                                    (context, value) =>
                                                        const TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 10),
                                              ),
                                              bottomTitles: SideTitles(
                                                showTitles: true,
                                                getTextStyles:
                                                    (context, value) =>
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
                                        child: Column(
                                          children: [
                                            Consumer<ThemeProvider>(builder:
                                                (context, themeProvider,
                                                    child) {
                                              return Row(
                                                children: [
                                                  const Icon(
                                                      Icons.record_voice_over,
                                                      size: 30,
                                                      color: Colors.blue),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      "Record: $maxMovies movies in a day",
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: themeProvider
                                                                .isDarkMode
                                                            ? Colors.yellow
                                                            : Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                const Icon(Icons.movie,
                                                    size: 30,
                                                    color: Colors.green),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    "Total Movies Ever Seen: ${seenMovies.length}",
                                                    style: const TextStyle(
                                                        fontSize: 15),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                const Icon(Icons.tv,
                                                    size: 30,
                                                    color: Colors.red),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    "Total TV Shows Ever Seen: ${seenTVShows.length}",
                                                    style: const TextStyle(
                                                        fontSize: 15),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
                              labelColor: null,
                              unselectedLabelColor: null,
                              tabs: [
                                Tab(text: 'Fav. Actors'),
                                Tab(text: 'Fav. Directors'),
                                Tab(text: 'Most Seen'),
                              ],
                            ),
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.655,
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
                                            final rightMovieIndex =
                                                index * 3 + 2;
                                            final leftMovie =
                                                (leftMovieIndex < movies.length)
                                                    ? movies[leftMovieIndex]
                                                    : null;
                                            final middleMovie =
                                                (middleMovieIndex <
                                                        movies.length)
                                                    ? movies[middleMovieIndex]
                                                    : null;
                                            final rightMovie =
                                                (rightMovieIndex <
                                                        movies.length)
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                      personResult =
                                                          middleMovie;
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                            BorderRadius
                                                                .circular(27),
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
                                            final rightMovieIndex =
                                                index * 3 + 2;
                                            final leftMovie =
                                                (leftMovieIndex < movies.length)
                                                    ? movies[leftMovieIndex]
                                                    : null;
                                            final middleMovie =
                                                (middleMovieIndex <
                                                        movies.length)
                                                    ? movies[middleMovieIndex]
                                                    : null;
                                            final rightMovie =
                                                (rightMovieIndex <
                                                        movies.length)
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                      personResult =
                                                          middleMovie;
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                            BorderRadius
                                                                .circular(27),
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
                                            final rightMovieIndex =
                                                index * 3 + 2;
                                            final leftMovie =
                                                (leftMovieIndex < movies.length)
                                                    ? movies[leftMovieIndex]
                                                    : null;
                                            final middleMovie =
                                                (middleMovieIndex <
                                                        movies.length)
                                                    ? movies[middleMovieIndex]
                                                    : null;
                                            final rightMovie =
                                                (rightMovieIndex <
                                                        movies.length)
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                            BorderRadius
                                                                .circular(27),
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
                                                            BorderRadius
                                                                .circular(27),
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
          ],
        ),
        bottomNavigationBar: CommonBottomAppBar(-1),
      );
    } else {
      return const Scaffold();
    }
  }
}
