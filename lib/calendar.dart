// ignore_for_file: unnecessary_brace_in_string_interps, no_leading_underscores_for_local_identifiers, avoid_function_literals_in_foreach_calls, use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/calendar_service.dart';
import 'package:uractor/common/firebase/firebaseutils.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/tvshow_result.dart';
import 'common/constants.dart';
import 'common/utils.dart';
import 'popups/add_to_calendar_pop_up.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'objects/movie.dart';
import 'main.dart';
import 'movie_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'common/firebase/firestore_core.dart';

DateTime selectedDate = DateTime.now();

String dateForMap = '';
FirebaseFirestore db = FirestoreCore.db;

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime _focusedDay = DateTime.now();
  String _selectedDay = DateTime.now().toIso8601String().split('T')[0];
  List _monthlyStats = [0, 0, 0];
  bool areFABsVisible = false;
  void deleteMovieSubmit(String id, String title) async {
    var userDoc = db.collection(currentUser.uid).doc("Calendar");
    await CalendarService.deleteFromCalendar(
      currentUser.uid,
      id,
      title,
      _selectedDay,
      context,
    );

    if (currentUser.rewatchedMovies.keys.toList().contains(id)) {
      currentUser.rewatchedMovies[id] - 1 > 0
          ? currentUser.rewatchedMovies[id] -= 1
          : 0;
      if (currentUser.rewatchedMovies[id] == 0) {
        List w;
        await FirestoreCore.db
            .collection(currentUser.uid)
            .get()
            .then((QuerySnapshot querySnapshot) {
          querySnapshot.docs.forEach((doc) async {
            if (doc.id == "Movies") {
              Map moviesResult = doc.data() as Map;
              w = moviesResult["Seen"];
              int index = w.indexOf(id);

              if (index > -1) {
                w.removeAt(index);
              }
              var userDoc = FirestoreCore.db
                  .collection(currentUser.uid)
                  .doc("Movies");
              await userDoc.update({'Seen': w});
              currentUser.seenMovies = [];
              for (var element in w) {
                currentUser.seenMovies += [
                  ["Movies", element]
                ];
              }
            }
          });
        });
      }
      userDoc = db.collection(currentUser.uid).doc("Rewatched");
      Map<Object, Object> updatedRewatched = {};
      for (String key in currentUser.rewatchedMovies.keys) {
        updatedRewatched[key] = currentUser.rewatchedMovies[key];
      }
      await userDoc.update(updatedRewatched);
    }
    Navigator.of(context).pop(true);
    setState(() {
      currentUser.calendar = Map<String, List>.from(currentUser.calendar);
    });
  }

  void _updateMonthlyStats(DateTime focusedDay) {
    _monthlyStats = _getMonthlyStats(focusedDay);
  }

  List _getMonthlyStats(DateTime focusedDay) {
    num totalRuntime = 0; // Total runtime of all movies in the month
    double totalRating = 0; // Total rating of all movies in the month
    int movieCount = 0; // Total number of movies in the month
    List counted = [];

    for (String key in currentUser.calendar.keys) {
      DateTime date = DateTime.parse(key);
      if (date.month == focusedDay.month && date.year == focusedDay.year) {
        for (var movie in currentUser.calendar[key]) {
          if (movie.keys.toList().contains("type")) {
            if (!counted.contains(movie["title"]) &&
                movie["type"] == "series") {
              counted.add(movie["title"]);
              totalRuntime += movie['runtime'] ?? 0;
              totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
              movieCount +=
                  (movie["rating"] != "N/A" && movie['rating'] != 0) ? 1 : 0;
            } else if (movie["type"] == "movie") {
              totalRuntime += movie['runtime'] ?? 0;
              totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
              movieCount +=
                  (movie["rating"] != "N/A" && movie['rating'] != 0) ? 1 : 0;
            }
          } else {
            totalRuntime += movie['runtime'] ?? 0;
            totalRating += (movie["rating"] != "N/A") ? movie['rating'] : 0;
            movieCount +=
                (movie["rating"] != "N/A" && movie['rating'] != 0) ? 1 : 0;
          }
        }
      }
    }

    double averageRating = movieCount > 0 ? totalRating / movieCount : 0;

    return [movieCount, averageRating, totalRuntime];
  }

  void toggleFABs() {
    setState(() {
      areFABsVisible = !areFABsVisible;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateMonthlyStats(_focusedDay); // Add this line
  }

  @override
  Widget build(BuildContext context) {
    List moviesOnDay = [];
    List movies = [];

    Future<void> showDateSelectionDialog() async {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Container(
              padding: const EdgeInsets.only(
                  left: 20, top: 10, right: 20, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      S.of(context)!.addTVShowToCalendar,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.today),
                          SizedBox(
                            width: 10,
                          ),
                          Text(S.of(context)!.selectASpecificDate)
                        ],
                      ),
                      onTap: () async {
                        DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(3000),
                        );
                        if (selectedDate != null) {
                          bool done = await showDialog(
                            context: context,
                            builder: (BuildContext ontext) {
                              return CalendarAddDialogue(
                                dateForMap: selectedDate
                                    .toIso8601String()
                                    .split("T")[0],
                                dateRange: "",
                                type: "series",
                              );
                            },
                          );
                          if (done) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.date_range),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(S.of(context)!.selectADateRange)
                        ],
                      ),
                      onTap: () async {
                        DateTimeRange? selectedRange =
                            await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2035),
                          initialDateRange: DateTimeRange(
                            start: DateTime.now(),
                            end: DateTime.now().add(const Duration(days: 7)),
                          ),
                        );
                        if (selectedRange != null) {
                          bool done = await showDialog(
                            context: context,
                            builder: (BuildContext ontext) {
                              return CalendarAddDialogue(
                                dateForMap: "",
                                dateRange:
                                    "${selectedRange.start.toIso8601String().split(' ')[0]}T${selectedRange.end.toIso8601String().split(' ')[0]}",
                                type: "series",
                              );
                            },
                          );
                          if (done) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                            const SizedBox(width: 10),
                            Text(
                              S.of(context)!.cancel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
          builder: (BuildContext ontext) {
            return CalendarAddDialogue(
              dateForMap: dateForMap,
              dateRange: "",
              type: "movie",
            );
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
      if (currentUser.calendar.keys.contains(_selectedDay)) {
        moviesOnDay = currentUser.calendar[_selectedDay];
      } else {
        moviesOnDay = [];
      }
      int i = 0;
      movies = [];
      moviesOnDay.forEach((element) async {
        await Utils.fetchCalendarElement(element, movies, sanitizeName: true);
        if (i == moviesOnDay.length - 1) {
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.375,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          S.of(context)!.seenOn(_selectedDay),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          height: 10,
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
                                                          UNKNOWN_COVER)
                                                  : TVShow(
                                                      id: event["id"]
                                                          .toString(),
                                                      title: event['name'],
                                                      coverPhoto: event[
                                                              "poster_path"] ??
                                                          UNKNOWN_COVER);
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
                                                  child: getItemContainer(
                                                      context, event, "media",
                                                      widthPercentage: 0.32,
                                                      heightPercentage: 0.2),
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
                                                                return SizedBox(
                                                                  height: 32.0,
                                                                  child: Center(
                                                                      child: Text(S
                                                                          .of(context)!
                                                                          .errorLoadingImages)),
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
                                          IconButton(
                                            style: IconButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent),
                                            onPressed: () {
                                              String type =
                                                  event.containsKey("title")
                                                      ? "movie"
                                                      : "series";
                                              deleteMovieSubmit(
                                                  event['id'].toString(),
                                                  type == "movie"
                                                      ? event['title']
                                                          .toString()
                                                      : event['name']
                                                          .toString());
                                            },
                                            icon: const Icon(Icons.delete),
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.57,
              child: TableCalendar(
                  firstDay: DateTime.utc(1990, 10, 16),
                  lastDay: DateTime.utc(2030, 3, 14),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  eventLoader: (date) {
                    final dayKey = date.toIso8601String().split('T')[0];
                    final items = currentUser.calendar[dayKey] ?? [];
                    return items.map((item) => item['title'] ?? '').toList();
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
                      _focusedDay = focusedDay;
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
                      Text(S.of(context)!.labelSeen,
                          style: TextStyle(fontSize: 15)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.timer, size: 40, color: Colors.green),
                      Text('${(_monthlyStats[2] / 60).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(S.of(context)!.labelHoursSpent,
                          style: TextStyle(fontSize: 15)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.star, size: 40, color: Colors.yellow),
                      Text('${_monthlyStats[1].toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(S.of(context)!.labelAvgRating,
                          style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Visibility(
            visible: areFABsVisible,
            child: FloatingActionButton(
              onPressed: _openDatePickerDialog,
              backgroundColor: Colors.grey[900],
              child: const Icon(
                Icons.movie,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Visibility(
            visible: areFABsVisible,
            child: FloatingActionButton(
              onPressed: showDateSelectionDialog,
              backgroundColor: Colors.grey[900],
              child: const Icon(
                Icons.tv,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: toggleFABs,
            backgroundColor: Colors.grey[900],
            child: Icon(
              areFABsVisible ? Icons.close : Icons.add,
              size: 30,
              color: Colors.white,
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
