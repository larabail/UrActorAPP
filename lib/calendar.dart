// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/main.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/search.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/main.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final String imgLink = 'https://image.tmdb.org/t/p/w500/';

bool containsMap(List list, Map map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}

class Calendar extends StatelessWidget {
  final Map events = calendar;
  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    final List<Widget> _pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _pages[_selectedIndex]),
      );
    }

    String _selectedDay = '';
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
      if (events.keys.contains(_selectedDay)) {
        moviesOnDay = events[_selectedDay];
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
          // ignore: use_build_context_synchronously
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return SingleChildScrollView(
                child: Container(
                  color: Color(0xFF121212),
                  height: 400,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          "Movies seen on ${_selectedDay}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.17,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...movies
                                  .map((event) => GestureDetector(
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
                                                    MovieResult()),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                              10.0, 10.0, 5.0, 0),
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.25,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.15,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(27),
                                            image: DecorationImage(
                                              image: NetworkImage(imgLink +
                                                  event['poster_path']),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
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

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(1990, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: DateTime.now(),
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(color: Colors.white),
              holidayTextStyle: TextStyle(color: Colors.white),
              selectedTextStyle: TextStyle(color: Colors.black),
              todayTextStyle: TextStyle(color: Colors.white),
              weekNumberTextStyle: TextStyle(color: Colors.white),
            ),
            headerStyle: const HeaderStyle(
              titleTextStyle: TextStyle(color: Colors.white),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              formatButtonTextStyle: TextStyle(color: Colors.white),
            ),
            eventLoader: (date) {
              final eventsOnDate =
                  events[date.toString().substring(0, 10)] ?? [];
              return eventsOnDate.map((event) => event['title'] ?? '').toList();
            },
            onDaySelected: _onDaySelected,
          ),
          if (moviesOnDay.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: moviesOnDay.length,
                itemBuilder: (BuildContext context, int index) {
                  print(moviesOnDay[index]);
                  return ListTile(
                    title: Text(
                      moviesOnDay[index]['title'],
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
