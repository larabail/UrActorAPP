import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/profile.dart';
import 'appbar.dart';
import 'bottom_app_bar.dart';
import 'friends.dart';
import 'friends_calendar.dart';
import 'playlists.dart';
import 'search.dart';
import 'main.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'seenTogether.dart';

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
  FriendProfile({required String friendUID});

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

  bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }

  String link = "https://api.themoviedb.org/3/movie/";
  List<Map<String, dynamic>> movies = [];
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
        appBar: CustomAppBar(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 16.0, top: 10),
                    child: ClipOval(
                      child: friendSettings["profile_photo"] != ""
                          ? Image.network(
                              friendSettings["profile_photo"],
                              height: 75, // Smaller size
                              width: 75, // Smaller size
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/main_profile.png',
                              height: 75, // Smaller size
                              width: 75, // Smaller size
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(
                      width: 16.0), // Space between the photo and the username
                  Expanded(
                    child: Text(
                      friendSettings["username"],
                      style: const TextStyle(
                        fontSize: 20, // Adjust the font size as needed
                        fontWeight:
                            FontWeight.bold, // Optional: to make it bold
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      bool confirmed = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirmation'),
                            content: const Text(
                                'Are you sure you want to remove this friend?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('No'),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text('Yes'),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed) {
                        // Reference to the Firestore instance
                        FirebaseFirestore firestore =
                            FirebaseFirestore.instance;

                        // Remove friend from current user's friend list
                        await firestore
                            .collection(friendUid)
                            .doc("Friends")
                            .update({
                          'friends': FieldValue.arrayRemove([uid])
                        });

                        // Remove current user from friend's friend list
                        await firestore.collection(uid).doc("Friends").update({
                          'friends': FieldValue.arrayRemove([friendUid])
                        });
                        friends.remove(friendUid);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => Friends()),
                        );
                      }
                    },
                    child: Icon(
                      Icons.person_remove, // Example icon
                      color: Colors.red[300], // Icon color
                    ),
                  ),
                  const SizedBox(width: 16.0),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GestureDetector(
                  onTap: () {
                    // Navigate to Calendar Page
                    friendUid = friendUid;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FriendCalendar(friendUid: friendUid),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[900],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Calendar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(
                  height:
                      10), // Optional: to add some space between the row and the list
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(5.0),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                            Icons.group), // Replace with your preferred icon
                        const SizedBox(width: 10),
                        const Text(
                          'Seen Together',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (seenWith.containsKey(friendUid))
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SeenTogether(
                                          friendSettings: friendSettings,
                                        )),
                              );
                            },
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  'See All (${seenWith[friendUid]["Movies"].length} items)',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (seenWith.containsKey(friendUid))
                      SizedBox(
                        height: 150, // Adjust the height as needed
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: seenWith[friendUid]["Movies"].length > 10
                              ? 10
                              : seenWith[friendUid]["Movies"]
                                  .length, // Limit to first 10 movies
                          itemBuilder: (context, index) {
                            return FutureBuilder<Map<String, dynamic>>(
                              future: getData(
                                  seenWith[friendUid]["Movies"][index],
                                  'Movies'),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      movieResult = [
                                        snapshot.data!['id'],
                                        snapshot.data!['title'],
                                        snapshot.data!['type'],
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
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              snapshot.data!['poster']),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return const Center(
                                      child:
                                          Text("Failed to load movie details"));
                                } else {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                              },
                            );
                          },
                        ),
                      ),

                    if (!seenWith.containsKey(friendUid))
                      const Text("Haven't watched any movies together yet"),
                    //   FutureBuilder<DocumentSnapshot>(
                    //     future: FirebaseFirestore.instance
                    //         .collection(uid)
                    //         .doc('SeenWith')
                    //         .get(),
                    //     builder: (context, snapshot) {
                    //       if (snapshot.connectionState ==
                    //           ConnectionState.waiting) {
                    //         return const Center(
                    //             child: CircularProgressIndicator());
                    //       } else if (snapshot.hasError) {
                    //         return Text('Error: ${snapshot.error}');
                    //       } else if (!snapshot.hasData ||
                    //           !snapshot.data!.exists) {
                    //         return const Text('No data found');
                    //       } else {
                    //         var seentogether = snapshot.data!.data() as Map;
                    //         List moviesSeenTogether = [];
                    //         for (var movie in seentogether["Movies"].keys) {
                    //           if (seentogether["Movies"][movie]["friends"]
                    //               .contains(friendUid)) {
                    //             moviesSeenTogether.add(movie);
                    //           }
                    //         }
                    //         if (moviesSeenTogether.isNotEmpty) {
                    //           return Column(
                    //             crossAxisAlignment: CrossAxisAlignment.start,
                    //             children: [
                    //               Text(
                    //                 moviesSeenTogether.length > 1
                    //                     ? "You have seen ${moviesSeenTogether.length} movies together"
                    //                     : "You have seen ${moviesSeenTogether.length} movie together",
                    //                 style: const TextStyle(
                    //                   color: Colors.white,
                    //                   fontSize: 16,
                    //                 ),
                    //               ),
                    //               const SizedBox(height: 10),
                    //               SizedBox(
                    //                 height: 125, // Adjust the height as needed
                    //                 child: ListView.builder(
                    //                   scrollDirection: Axis.horizontal,
                    //                   itemCount: moviesSeenTogether.length > 10
                    //                       ? 10
                    //                       : moviesSeenTogether
                    //                           .length, // Limit to first 10 movies
                    //                   itemBuilder: (context, index) {
                    //                     return FutureBuilder<
                    //                         Map<String, dynamic>>(
                    //                       future: getData(
                    //                           moviesSeenTogether[index],
                    //                           'Movies'),
                    //                       builder: (BuildContext context,
                    //                           AsyncSnapshot<Map> snapshot) {
                    //                         if (snapshot.hasData) {
                    //                           return GestureDetector(
                    //                             onTap: () {
                    //                               movieResult = [
                    //                                 snapshot.data!['id'],
                    //                                 snapshot.data!['title'],
                    //                                 snapshot.data!['type'],
                    //                               ];
                    //                               Navigator.push(
                    //                                 context,
                    //                                 MaterialPageRoute(
                    //                                     builder: (context) =>
                    //                                         MovieResult()),
                    //                               );
                    //                             },
                    //                             child: Container(
                    //                               margin:
                    //                                   const EdgeInsets.fromLTRB(
                    //                                       5.0, 10.0, 10.0, 0),
                    //                               width: MediaQuery.of(context)
                    //                                       .size
                    //                                       .width *
                    //                                   0.28,
                    //                               decoration: BoxDecoration(
                    //                                 borderRadius:
                    //                                     BorderRadius.circular(27),
                    //                                 image: DecorationImage(
                    //                                   image: NetworkImage(snapshot
                    //                                       .data!['poster']),
                    //                                   fit: BoxFit.fitWidth,
                    //                                 ),
                    //                               ),
                    //                             ),
                    //                           );
                    //                         } else if (snapshot.hasError) {
                    //                           return const Center(
                    //                               child: Text(
                    //                                   "Failed to load movie details"));
                    //                         } else {
                    //                           return const Center(
                    //                               child:
                    //                                   CircularProgressIndicator());
                    //                         }
                    //                       },
                    //                     );
                    //                   },
                    //                 ),
                    //               ),
                    //             ],
                    //           );
                    //         } else {
                    //           return const Text(
                    //             "You haven't watched any movies together yet",
                    //             style: TextStyle(
                    //               color: Colors.white,
                    //               fontSize: 16,
                    //             ),
                    //           );
                    //         }
                    //       }
                    //     },
                    //   ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(5.0),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.movie),
                        SizedBox(width: 10),
                        Text(
                          'Most Seen Movies',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.22,
                      child: FutureBuilder<List<Map>>(
                        future: topMovies(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final movies = snapshot.data!;
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: movies.length,
                              itemBuilder: (context, index) {
                                final movie = movies[index];
                                return GestureDetector(
                                  onTap: () {
                                    movieResult = [
                                      movie['id'],
                                      movie['title'],
                                      "Movies"
                                    ];
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MovieResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          imgLink + movie['poster_path'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else if (snapshot.hasError) {
                            return const Center(
                              child: Text("Failed to load movie details"),
                            );
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(5.0),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.theater_comedy),
                        SizedBox(width: 10),
                        Text(
                          'Favorite Actors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.22,
                      child: FutureBuilder<List<Map>>(
                        future: actorData(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final persons = snapshot.data!;
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: persons.length,
                              itemBuilder: (context, index) {
                                final person = persons[index];
                                return GestureDetector(
                                  onTap: () {
                                    personResult = person;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PersonResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          imgLink + person['profile_path'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else if (snapshot.hasError) {
                            return const Center(
                              child: Text("Failed to load movie details"),
                            );
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(5.0),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chair),
                        SizedBox(width: 10),
                        Text(
                          'Favorite Directors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.22,
                      child: FutureBuilder<List<Map>>(
                        future: dirData(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final persons = snapshot.data!;
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: persons.length,
                              itemBuilder: (context, index) {
                                final person = persons[index];
                                return GestureDetector(
                                  onTap: () {
                                    personResult = person;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PersonResult()),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          imgLink + person['profile_path'],
                                        ),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else if (snapshot.hasError) {
                            return const Center(
                              child: Text("Failed to load movie details"),
                            );
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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
        bottomNavigationBar: CommonBottomAppBar(-1),
      );
    } else {
      return const Scaffold();
    }
  }
}
