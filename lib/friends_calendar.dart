import 'package:flutter/material.dart';
import 'friends.dart';
import 'playlists.dart';
import 'main.dart';
import 'profile.dart';
import 'search.dart';
import 'movie_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final String imgLink = 'https://image.tmdb.org/t/p/w500/';
DateTime selectedDate = DateTime.now();

String _selectedDay = '';
String dateForMap = '';

bool containsMap(List list, Map map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class FriendCalendar extends StatefulWidget {
  FriendCalendar({required String friendUid});
  @override
  _FriendCalendarState createState() => _FriendCalendarState();
}

class _FriendCalendarState extends State<FriendCalendar> {
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

    for (String key in friendCalendar.keys) {
      DateTime date = DateTime.parse(key);
      if (date.month == focusedDay.month && date.year == focusedDay.year) {
        for (var movie in friendCalendar[key]) {
          totalRuntime += movie['runtime'] ?? 0;
          totalRating += movie['rating'] ?? 0;
          movieCount++;
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
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    List moviesOnDay = [];
    List movies = [];

    void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
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
      String link = 'https://api.themoviedb.org/3/movie/';
      String api_key_actor = '?api_key=700cd4fab994df56eb41b34d38c4762a';
      int i = 0;
      movies = [];
      moviesOnDay.forEach((element) async {
        String id = element['id'];
        String name = element['title'];
        final response =
            await http.get(Uri.parse('${link}${id}-${name}${api_key_actor}'));
        if (response.statusCode == 200) {
          dynamic json = jsonDecode(response.body);
          if (!containsMap(movies, json)) {
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
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.375,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          "Movies seen on ${_selectedDay}",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          // height: MediaQuery.of(context).size.height * 0.3,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...movies
                                  .map((event) => Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              // Handle the click event here
                                              movieResult = [
                                                event['id'],
                                                event['title'],
                                                "Movie",
                                              ];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MovieResult(),
                                                ),
                                              );
                                            },
                                            child: ClipRRect(
                                              // Wrap the container with ClipRRect
                                              borderRadius: BorderRadius.circular(
                                                  50), // Set the border radius here
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.fromLTRB(
                                                        5.0, 7.0, 5.0, 0),
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.3,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.2,
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                        imgLink +
                                                            event[
                                                                'poster_path']),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ))
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

    if (gotData)
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          title: Center(
              child: Image.asset(
            'assets/logo_character.png',
            height: 54,
          )),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height *
                    0.5, // Adjust as needed

                child: TableCalendar(
                    firstDay: DateTime.utc(1990, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    // focusedDay: DateTime.now(),
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
                      _onDaySelected(selectedDay, focusedDay);
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
                        const Text('# Movies', style: TextStyle(fontSize: 15)),
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
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Colors.grey,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              label: 'Friends',
              icon: Icon(Icons.contacts),
            ),
            BottomNavigationBarItem(
              label: 'Profile',
              icon: Icon(Icons.person),
            ),
          ],
          currentIndex: selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    else
      return Scaffold();
  }
}
