// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'common/utils.dart';
import 'friends.dart';
import 'objects/Movie.dart';
import 'objects/TVShow.dart';
import 'playlists.dart';
import 'main.dart';
import 'profile.dart';
import 'search.dart';
import 'movie_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'tvshow_result.dart';

const String imgLink = 'https://image.tmdb.org/t/p/w500/';
DateTime selectedDate = DateTime.now();

class FriendCalendar extends StatefulWidget {
  const FriendCalendar({super.key, required String friendUid});
  @override
  _FriendCalendarState createState() => _FriendCalendarState();
}

class _FriendCalendarState extends State<FriendCalendar> {
  String dateForMap = '';
  Map friendCalendar = {};
  bool gotData = false;
  Future<void> getFirebaseData() async {
    await FirebaseFirestore.instance
        .collection(friendUid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Calendar" && friendCalendar.keys.isEmpty) {
          friendCalendar = doc.data() as Map;
        }
      }
    });
    setState(() {
      gotData = true;
      _updateMonthlyStats(_focusedDay); // Add this line
    });
  }

  DateTime _focusedDay = DateTime.now();
  String _selectedDay = DateTime.now().toIso8601String().split('T')[0];
  List _monthlyStats = [0, 0, 0];

  void _updateMonthlyStats(DateTime focusedDay) {
    _monthlyStats = _getMonthlyStats(focusedDay);
  }

  List _getMonthlyStats(DateTime focusedDay) {
    num totalRuntime = 0; // Total runtime of all movies in the month
    double totalRating = 0; // Total rating of all movies in the month
    int movieCount = 0; // Total number of movies in the month
    List counted = [];

    for (String key in friendCalendar.keys) {
      key = key.split("T")[0];
      DateTime date = DateTime.parse(key);
      if (date.month == focusedDay.month && date.year == focusedDay.year) {
        for (var movie in friendCalendar[key]) {
          if (movie.keys.toList().contains("type")) {
            if (!counted.contains(movie["title"]) &&
                movie["type"] == "series") {
              counted.add(movie["title"]);
              totalRuntime += movie['runtime'] ?? 0;
              totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
              movieCount++;
            } else if (movie["type"] == "movie") {
              totalRuntime += movie['runtime'] ?? 0;
              totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
              movieCount++;
            }
          } else {
            totalRuntime += movie['runtime'] ?? 0;
            totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
            movieCount++;
          }
        }
      }
    }

    double averageRating = movieCount > 0 ? totalRating / movieCount : 0;

    return [movieCount, averageRating, totalRuntime];
  }

  @override
  void initState() {
    super.initState();
    getFirebaseData();
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      const MyApp(),
      const Playlists(),
      const Search(),
      const Friends(),
      const Profile(),
      // Add more pages here
    ];

    void onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    List moviesOnDay = [];
    List movies = [];

    void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
      String month = '${selectedDay.month}';
      String day = '${selectedDay.day}';
      if (selectedDay.month < 10) {
        month = '0${selectedDay.month}';
      }
      if (selectedDay.day < 10) {
        day = '0${selectedDay.day}';
      }
      _selectedDay = '${selectedDay.year}-$month-$day';
      if (friendCalendar.keys.contains(_selectedDay)) {
        moviesOnDay = friendCalendar[_selectedDay];
      } else {
        moviesOnDay = [];
      }
      int i = 0;
      movies = [];
      moviesOnDay.forEach((element) async {
        String id = element['id'];
        String name = element['title'];
        final response = await http.get(Uri.parse(
            '${element.containsKey("type") ? element["type"] == "movie" ? MOVIE_LINK : TV_SHOW_LINK : MOVIE_LINK}$id-$name$API_KEY'));
        if (response.statusCode == 200) {
          dynamic json = jsonDecode(response.body);
          if (!Utils.containsMap(movies, json)) {
            if (element.containsKey("friends")) {
              json["friends"] = element["friends"];
            }
            movies.add(json);
          }
        } else {
          throw Exception('Failed to load movie details');
        }
        if (i == moviesOnDay.length - 1) {
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.31,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          "Seen on $_selectedDay",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...movies
                                  .map(
                                    (event) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              var tempMedia = event.containsKey(
                                                      "title")
                                                  ? Movie(
                                                      id: event["id"]
                                                          .toString(),
                                                      title: event['title'],
                                                      coverPhoto: event[
                                                              "poster_path"] ??
                                                          "")
                                                  : TVShow(
                                                      id: event["id"]
                                                          .toString(),
                                                      title: event['name'],
                                                      coverPhoto: event[
                                                              "poster_path"] ??
                                                          "");
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      event.containsKey("title")
                                                          ? MovieResult(
                                                              movie: tempMedia
                                                                  as Movie)
                                                          : TVShowResult(
                                                              tvshow: tempMedia
                                                                  as TVShow),
                                                ),
                                              );
                                            },
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.32,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.2,
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image:
                                                            CachedNetworkImageProvider(
                                                          event['poster_path'] !=
                                                                  null
                                                              ? IMG_LINK +
                                                                  event[
                                                                      'poster_path']
                                                              : "https://cringemdb.com/img/movie-poster-placeholder.png",
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (event
                                                    .containsKey("friends"))
                                                  Positioned(
                                                    bottom: 8,
                                                    left: 8,
                                                    right: 8,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: FutureBuilder<
                                                              List<String>>(
                                                            future: FirebaseUtils
                                                                .getProfilePhotos(
                                                                    event[
                                                                        "friends"]),
                                                            builder: (context,
                                                                snapshot) {
                                                              if (snapshot
                                                                      .connectionState ==
                                                                  ConnectionState
                                                                      .waiting) {
                                                                return const SizedBox(
                                                                  height: 32.0,
                                                                  child: Center(
                                                                      child:
                                                                          CircularProgressIndicator()),
                                                                );
                                                              } else if (snapshot
                                                                  .hasError) {
                                                                return const SizedBox(
                                                                  height: 32.0,
                                                                  child: Center(
                                                                      child: Text(
                                                                          'Error loading images')),
                                                                );
                                                              } else if (snapshot
                                                                  .hasData) {
                                                                var images =
                                                                    snapshot
                                                                        .data!;
                                                                return SizedBox(
                                                                  height: 32.0,
                                                                  child: Stack(
                                                                    children: List.generate(
                                                                        images
                                                                            .length,
                                                                        (index) {
                                                                      double
                                                                          offset =
                                                                          index *
                                                                              10.0;
                                                                      return Positioned(
                                                                        left:
                                                                            offset,
                                                                        child:
                                                                            ClipOval(
                                                                          child: images[index] != ""
                                                                              ? Image.network(
                                                                                  images[index],
                                                                                  height: 25,
                                                                                  width: 25,
                                                                                  fit: BoxFit.cover,
                                                                                )
                                                                              : Image.asset(
                                                                                  'assets/main_profile.png',
                                                                                  height: 25,
                                                                                  width: 25,
                                                                                  fit: BoxFit.cover,
                                                                                ),
                                                                        ),
                                                                      );
                                                                    }),
                                                                  ),
                                                                );
                                                              } else {
                                                                return const SizedBox
                                                                    .shrink();
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        i++;
      });
    }

    if (gotData) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: const CustomAppBar(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height *
                    0.57, // Adjust as needed

                child: TableCalendar(
                    firstDay: DateTime.utc(1990, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    eventLoader: (date) {
                      final eventsOnDate =
                          friendCalendar[date.toString().substring(0, 10)] ??
                              [];
                      return eventsOnDate
                          .map((event) => event['title'] ?? '')
                          .toList();
                    },
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(DateTime.parse(_selectedDay), day),
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                        _updateMonthlyStats(focusedDay);
                      });
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay =
                            selectedDay.toIso8601String().split('T')[0];
                        _focusedDay = focusedDay; // update focusedDay here
                        _updateMonthlyStats(focusedDay);
                      });
                      onDaySelected(selectedDay, focusedDay);
                    }),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.movie, size: 40, color: Colors.blue),
                        Text('${_monthlyStats[0]}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('# Seen', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.timer, size: 40, color: Colors.green),
                        Text('${(_monthlyStats[2] / 60).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Hours Spent',
                            style: TextStyle(fontSize: 15)),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.star, size: 40, color: Colors.yellow),
                        Text(
                            '${_monthlyStats[1].toStringAsFixed(2)}', // Round to 2 decimal places
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Avg. Rating',
                            style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CommonBottomAppBar(-1),
      );
    } else {
      return const Scaffold();
    }
  }
}
