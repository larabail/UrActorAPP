// ignore_for_file: unnecessary_brace_in_string_interps, no_leading_underscores_for_local_identifiers, avoid_function_literals_in_foreach_calls
import 'package:flutter/material.dart';
import 'package:uractor/explore.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
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
        if (calendar[key].length == 1) {
          var movie = calendar[key][0];
          if (movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString()) {
            calendar[key] = []; // Clear the list
          }
        } else {
          calendar[key].removeWhere((movie) =>
              movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString());
        }
      }
    }
    Map<Object, Object> updatedCalendar = {};
    for (String key in calendar.keys) {
      if (calendar[key].isNotEmpty) {
        updatedCalendar[key] = calendar[key];
      } else {
        updatedCalendar[key] = [];
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
          totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
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
        String name = element['title']
            .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
            .replaceAll(" ", "-");
        final response =
            await http.get(Uri.parse('${link}${id}-${name}${api_key_actor}'));
        // print('${link}${id}-${name}${api_key_actor}');
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
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...movies
                                  .map((event) => Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
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
      appBar: CustomAppBar(),
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
        backgroundColor: Colors.grey[900],
        child: const Icon(
          Icons.add,
          color: Colors.green,
          size: 30,
        ),
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
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
                'http://www.omdbapi.com/?i=${json2["imdb_id"]}&apikey=768d2cf9';
            final omdbData = await http.get(Uri.parse(omdbLink));
            if (response2.statusCode == 200) {
              final json3 = jsonDecode(omdbData.body);
              if (json3["imdbRating"] != null && json3["imdbRating"] != "N/A") {
                json2["imdbRating"] = json3["imdbRating"];
              } else {
                json2["imdbRating"] = "0.0";
              }
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

  void addMovieSubmit(String id, String title, int runtime, double rating,
      Map friendsWatchedWith) async {
    Map myObject = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating,
      'friends': friendsWatchedWith.keys
          .where((key) => friendsWatchedWith[key] == true)
          .toList(),
    };
    // print(friendsWatchedWith);
    if (calendar.keys.toList().contains(dateForMap)) {
      calendar[dateForMap].add(myObject);
    } else {
      calendar[dateForMap] = [
        myObject,
      ];
    }
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    for (var friend in friendsWatchedWith.keys) {
      myObject["friends"] = [
        uid,
      ];
      if (friendsWatchedWith[friend] == true) {
        if (seenWith.containsKey(friend) &&
            !seenWith[friend]["Movies"].contains(id.toString())) {
          seenWith[friend]["Movies"].add(id.toString());
        } else if (!seenWith.containsKey(friend)) {
          seenWith[friend] = {"Movies": [], "TVShows": []};
          seenWith[friend]["Movies"].add(id.toString());
        }
        // Update Calendar
        var userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Calendar");
        await userDoc.update({
          '$dateForMap': FieldValue.arrayUnion([myObject])
        });

        // Update Seen movies
        userDoc = FirebaseFirestore.instance.collection(friend).doc("Movies");
        await userDoc.update({
          'Seen': FieldValue.arrayUnion([id])
        });

        DocumentReference userDoc2 =
            firestore.collection(friend).doc("SeenWith");
        Map<String, dynamic> item = {};
        List<dynamic> watchedWithList = friendsWatchedWith.keys
            .where((key) => friendsWatchedWith[key] == true)
            .toList();
        item[id] = watchedWithList;

        // Run a transaction to ensure atomic updates
        await firestore.runTransaction((transaction) async {
          // Get the document snapshot
          DocumentSnapshot snapshot = await transaction.get(userDoc2);

          if (!snapshot.exists) {
            throw Exception("Document does not exist!");
          }

          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

          if (data.containsKey('Movies') &&
              data['Movies'] is Map<String, dynamic>) {
            Map<String, dynamic> moviesMap = data['Movies'];

            if (moviesMap.containsKey(id)) {
              List existingList = moviesMap[id]["friends"];
              for (String person in watchedWithList) {
                if (!existingList.contains(person)) {
                  existingList.add(person);
                }
              }
              moviesMap[id] = {"friends": existingList};
              transaction.update(userDoc2, {"Movies": moviesMap});
            } else {
              moviesMap[id] = {"friends": watchedWithList};
              transaction.update(userDoc2, {"Movies": moviesMap});
            }
          } else {
            transaction.set(
                userDoc2,
                {
                  'Movies': {
                    id: {"friends": watchedWithList}
                  }
                },
                SetOptions(merge: true));
          }
        }).catchError((error) {
          print("Failed to update document: $error");
        });

        // Update Rewatched
        userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Rewatched");
        DocumentSnapshot doc = await userDoc.get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data.containsKey(id)) {
            // Increment the count if movie id exists
            await userDoc.update({id: FieldValue.increment(1)});
          } else {
            // Add the movie id with count 1 if it doesn't exist
            await userDoc.update({id: 1});
          }
        }
      }
    }

    DocumentReference userDoc2 = firestore.collection(uid).doc("SeenWith");
    Map<String, dynamic> item = {};
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    item[id] = watchedWithList;
    myObject["friends"] = watchedWithList;

    // Run a transaction to ensure atomic updates
    firestore.runTransaction((transaction) async {
      // Get the document snapshot
      DocumentSnapshot snapshot = await transaction.get(userDoc2);

      if (!snapshot.exists) {
        throw Exception("Document does not exist!");
      }

      // Get the current data
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      // Check if 'Movies' map exists and if the 'id' is already a key in the 'Movies' map
      if (data.containsKey('Movies') &&
          data['Movies'] is Map<String, dynamic>) {
        Map<String, dynamic> moviesMap = data['Movies'];

        // Check if the 'id' already exists in the 'Movies' map
        if (moviesMap.containsKey(id)) {
          // If it exists, append the new list to the existing one
          List existingList = moviesMap[id]["friends"];
          for (String person in watchedWithList) {
            if (!existingList.contains(person)) {
              existingList.add(person);
            }
          }
          moviesMap[id] = {"friends": existingList};
        } else {
          // If the 'id' doesn't exist, add the new key-value pair
          moviesMap[id] = {"friends": watchedWithList};
        }
        // Update the 'Movies' map
        transaction.update(userDoc2, {'Movies': moviesMap});
      } else {
        // If 'Movies' map doesn't exist, create it and add the 'id' and list
        transaction.set(
            userDoc2,
            {
              'Movies': {
                id: {"friends": watchedWithList}
              }
            },
            SetOptions(merge: true));
      }
    }).catchError((error) {
      print("Failed to update document: $error");
    });
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

  Map<String, bool> selectedFriends = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Container(
        padding:
            const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 5),
                child: Text(
                  'Add a movie',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                    labelStyle: TextStyle(color: Colors.white),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FutureBuilder<List>(
                    future: searchData(_searchTermMovie),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.green,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      } else {
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data?.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> item = snapshot.data?[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              child: GridTile(
                                child: GestureDetector(
                                  onTap: () {
                                    _movie = item["id"].toString();
                                    addMovieSubmit(
                                        item["id"].toString(),
                                        item["title"].toString(),
                                        item["runtime"],
                                        double.parse(item["imdbRating"]),
                                        selectedFriends);
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 5),
                child: Text(
                  'Did you watch it with anyone?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  height: 125, // Set your desired height here
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    itemBuilder: (context, friendIndex) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection(friends[friendIndex])
                            .doc('Settings')
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else if (!snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return const Text('No data found');
                          } else {
                            var data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            String userName = data['username'] ?? '';
                            String profilePath = data['profile_photo'] ?? '';
                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  ClipOval(
                                    child: profilePath != ""
                                        ? Image.network(
                                            profilePath,
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
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(fontSize: 16.0),
                                    ),
                                  ),
                                ],
                              ),
                              value: selectedFriends.keys
                                      .toList()
                                      .contains(friends[friendIndex])
                                  ? selectedFriends[friends[friendIndex]]
                                  : false,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectedFriends[friends[friendIndex]] =
                                      value!;
                                });
                              },
                            );
                          }
                        },
                      );
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
                          primary: Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text("Cancel")
                          ],
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
