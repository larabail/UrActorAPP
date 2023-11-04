// ignore_for_file: unnecessary_brace_in_string_interps, no_leading_underscores_for_local_identifiers, avoid_function_literals_in_foreach_calls
import 'package:flutter/material.dart';
import 'package:uractor/explore.dart';
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

class Calendar extends StatefulWidget {
  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime _focusedDay = DateTime.now();
  String _selectedDay = DateTime.now().toIso8601String().split('T')[0];
  List _monthlyStats = [0, 0, 0];
  final Map events = calendar;
  void deleteMovieSubmit(String id, String title) async {
    var userDoc = db.collection(uid).doc("Calendar");
    for (String key in calendar.keys) {
      if (key == _selectedDay) {
        calendar[key].removeWhere(
            (movie) => movie['id'] == id && movie['title'] == title);
      }
    }
    Map<Object, Object> updatedCalendar = {};
    for (String key in calendar.keys) {
      if (calendar[key].isNotEmpty) {
        updatedCalendar[key] = calendar[key];
      }
    }
    await userDoc.update(updatedCalendar);

    if (rewatchedMovies.keys.toList().contains(id)) {
      rewatchedMovies[id] -= 1;
      if (rewatchedMovies[id] == 0) {
        List w;
        await FirebaseFirestore.instance
            .collection(uid)
            .get()
            .then((QuerySnapshot querySnapshot) {
          querySnapshot.docs.forEach((doc) async {
            if (doc.id == "Movies") {
              Map movies_result = doc.data() as Map;
              w = movies_result["Seen"];
              int index = w.indexOf(id);

              if (index > -1) {
                w.removeAt(index);
              }
              var userDoc =
                  FirebaseFirestore.instance.collection(uid).doc("Movies");
              await userDoc.update({'Seen': w});
              seenMovies = [];
              for (var element in w) {
                seenMovies += [
                  ["Movies", element]
                ];
              }
              setState(() {
                seenMovies = seenMovies;
              });
            }
          });
        });
      }
      userDoc = db.collection(uid).doc("Rewatched");
      Map<Object, Object> updatedRewatched = {};
      for (String key in rewatchedMovies.keys) {
        updatedRewatched[key] = rewatchedMovies[key];
      }
      await userDoc.update(updatedRewatched);
    }

    Navigator.pop(context);
    setState(() {
      calendar = calendar;
    });
  }

  void _updateMonthlyStats(DateTime focusedDay) {
    _monthlyStats = _getMonthlyStats(focusedDay);
  }

  List _getMonthlyStats(DateTime focusedDay) {
    num totalRuntime = 0; // Total runtime of all movies in the month
    double totalRating = 0; // Total rating of all movies in the month
    int movieCount = 0; // Total number of movies in the month

    for (String key in calendar.keys) {
      DateTime date = DateTime.parse(key);
      if (date.month == focusedDay.month && date.year == focusedDay.year) {
        for (var movie in calendar[key]) {
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
    _updateMonthlyStats(_focusedDay); // Add this line
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

    Future<void> _openDatePickerDialog() async {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Colors.lightBlue),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null) {
        selectedDate = pickedDate;
        dateForMap = selectedDate.toIso8601String().split("T")[0];
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return CalendarAddDialogue();
          },
        );
      }
    }

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
                                          IconButton(
                                            style: IconButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent),
                                            onPressed: () {
                                              deleteMovieSubmit(
                                                  event['id'].toString(),
                                                  event['title'].toString());
                                            },
                                            icon: const Icon(Icons.delete),
                                            color: Colors.red,
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
              height:
                  MediaQuery.of(context).size.height * 0.5, // Adjust as needed

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
                        events[date.toString().substring(0, 10)] ?? [];
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
                      const Text('Hours Spent', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.star, size: 40, color: Colors.yellow),
                      Text(
                          '${_monthlyStats[1].toStringAsFixed(2)}', // Round to 2 decimal places
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Avg. Rating', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDatePickerDialog,
        backgroundColor: Colors.lightGreen, // Function to open the dialog
        child: const Icon(
          Icons.add,
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
  }
}

// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

String search_by_nameMovie =
    'https://api.themoviedb.org/3/search/movie?api_key=700cd4fab994df56eb41b34d38c4762a&query=';
String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
String linkMovie = "https://api.themoviedb.org/3/movie/";
String img = 'https://image.tmdb.org/t/p/original/';

final myController = TextEditingController(text: "");

String _searchTermMovie = '';
String _movie = "";
FirebaseFirestore db = FirebaseFirestore.instance;

class CalendarAddDialogue extends StatefulWidget {
  @override
  _CalendarAddDialogueState createState() => _CalendarAddDialogueState();
}

class _CalendarAddDialogueState extends State<CalendarAddDialogue> {
  Future<List> searchData(String searchTerm) async {
    // print(searchTerm);
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$search_by_nameMovie$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<Map<String, dynamic>> results = [];
        for (final result in json['results']) {
          String resultSearchLink = '';
          resultSearchLink =
              '$linkMovie${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$api_key_actor';
          final response2 = await http.get(Uri.parse(resultSearchLink));
          if (response2.statusCode == 200) {
            final json2 = jsonDecode(response2.body);
            final omdbLink =
                'http://www.omdbapi.com/?i=${json2["imdb_id"]}&apikey=***REMOVED***';
            final omdbData = await http.get(Uri.parse(omdbLink));
            if (response2.statusCode == 200) {
              final json3 = jsonDecode(omdbData.body);
              json2["imdbRating"] = json3["imdbRating"];
              if (json2["poster_path"] != "" && json2["poster_path"] != null) {
                results.add(json2);
              }
            } else {
              throw Exception('Failed to load movie details');
            }
          } else {
            throw Exception('Failed to load movie details');
          }
        }
        return results;
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      return [];
    }
  }

  void addMovieSubmit(
      String id, String title, int runtime, double rating) async {
    Map myObject = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating
    };
    if (calendar.keys.toList().contains(dateForMap)) {
      calendar[dateForMap].add(myObject);
    } else {
      calendar[dateForMap] = [
        myObject,
      ];
    }
    var userDoc = db.collection(uid).doc("Calendar");
    Map<Object, Object> updatedCalendar = {};
    for (String key in calendar.keys) {
      updatedCalendar[key] = calendar[key];
    }
    await userDoc.update(updatedCalendar);

    if (rewatchedMovies.keys.toList().contains(id)) {
      rewatchedMovies[id] += 1;
    } else {
      rewatchedMovies[id] = 1;
    }

    userDoc = db.collection(uid).doc("Rewatched");
    Map<Object, Object> updatedRewatched = {};
    for (String key in rewatchedMovies.keys) {
      updatedRewatched[key] = rewatchedMovies[key];
    }
    await userDoc.update(updatedRewatched);

    if (!containsList(seenMovies, ["Movies", id])) {
      final userDoc = FirebaseFirestore.instance.collection(uid).doc('Movies');
      id = id.toString();
      await userDoc.update({
        'Seen': FieldValue.arrayUnion([id])
      });
      seenMovies += [
        ["Movies", id]
      ];
    }

    Navigator.pop(context);
    setState(() {
      calendar = calendar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contents of the Add List panel
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 40, 20, 5),
              child: Text(
                'Add a movie',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextFormField(
                validator: (String? value) {
                  if (value == null || value.isEmpty || _movie == "") {
                    return 'Please select a movie';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Name of The Movie You\'d Like to Add',
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTermMovie = value;
                    searchData(_searchTermMovie);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.5,
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: FutureBuilder<List>(
                  future: searchData(
                      _searchTermMovie), // Replace 'Your Search Term' with your actual search term
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    } else {
                      // Data is ready, build the GridView
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data?.length,
                        itemBuilder: (context, index) {
                          // You can customize the item here
                          Map<String, dynamic> item = snapshot.data?[index];
                          return Container(
                            width: 100, // Adjust the width as needed
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: GridTile(
                              child: GestureDetector(
                                onTap: () {
                                  _movie = item["id"].toString();
                                  addMovieSubmit(
                                      item["id"].toString(),
                                      item["title"].toString(),
                                      item["runtime"],
                                      double.parse(item["imdbRating"]));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          img + item['poster_path']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .red, // Change the background color of the button
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
