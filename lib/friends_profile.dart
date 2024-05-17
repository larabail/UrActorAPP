// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/utils.dart';
import 'friends.dart';
import 'friends_calendar.dart';
import 'objects/Movie.dart';
import 'main.dart';
import 'objects/Person.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'seenTogether.dart';

int weekOffset = 0; // This will be used to go to previous or next weeks

class FriendProfile extends StatefulWidget {
  const FriendProfile({super.key, required String friendUID});

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

  List<Map<String, dynamic>> movies = [];
  Future<Map<String, dynamic>> getData(id, type) async {
    Map<String, dynamic> data = {};
    String link;
    if (type == "TVShows") {
      link = TV_SHOW_LINK;
    } else {
      link = MOVIE_LINK;
    }
    final response = await http.get(Uri.parse('$link$id$API_KEY'));
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
        data['poster'] = IMG_LINK + json['poster_path'];
      }
      data['id'] = json['id'];
      data['type'] = type;
      if (!Utils.containsMap(movies, data)) {
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
    DateTime now = DateTime.now();
    DateTime startOfWeek =
        now.subtract(Duration(days: now.weekday - 1 + (7 * weekOffset)));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    Map filteredData = {};

    Map tempData = Map.fromEntries(friendCalendar.entries.where((entry) {
      DateTime entryDate = DateTime.parse(entry.key);
      return entryDate.isAfter(startOfWeek.add(const Duration(days: -1))) &&
          entryDate.isBefore(endOfWeek);
    }));

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

    int maxMovies = 0;
    for (var movies in friendCalendar.values) {
      if (movies.length > maxMovies) {
        maxMovies = movies.length;
      }
    }
    if (gotData) {
      List moviesTemp = [];
      friendRewatchedMovies.forEach((key, value) {
        moviesTemp.add([value, key]);
      });

      moviesTemp.sort((a, b) => b[0].compareTo(a[0]));
      return Scaffold(
        appBar: const CustomAppBar(),
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
                              height: 75,
                              width: 75,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/main_profile.png',
                              height: 75,
                              width: 75,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      friendSettings["username"],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                          'friends': FieldValue.arrayRemove([currentUser.uid])
                        });

                        // Remove current user from friend's friend list
                        await firestore
                            .collection(currentUser.uid)
                            .doc("Friends")
                            .update({
                          'friends': FieldValue.arrayRemove([friendUid])
                        });
                        currentUser.friends.remove(friendUid);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Friends()),
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
              const SizedBox(height: 10),
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
                        if (currentUser.seenWith.containsKey(friendUid))
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
                                  'See All (${currentUser.seenWith[friendUid]["Movies"].length + currentUser.seenWith[friendUid]["TVShows"].length} items)',
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
                    if (currentUser.seenWith.containsKey(friendUid))
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              currentUser.seenWith[friendUid]["Movies"].length >
                                      10
                                  ? 10
                                  : currentUser
                                      .seenWith[friendUid]["Movies"].length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<Map<String, dynamic>>(
                              future: getData(
                                  currentUser.seenWith[friendUid]["Movies"]
                                      [index],
                                  'Movies'),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      Movie tempMovie = Movie(
                                          id: snapshot.data!['id'].toString(),
                                          title: snapshot.data!['title'],
                                          coverPhoto:
                                              snapshot.data!['poster'] ?? "");
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                MovieResult(movie: tempMovie)),
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
                                  return Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          5.0, 10.0, 10.0, 0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      child: const Center(
                                          child: CircularProgressIndicator()));
                                }
                              },
                            );
                          },
                        ),
                      ),
                    if (!currentUser.seenWith.containsKey(friendUid))
                      const Text("Haven't watched any movies together yet"),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              buildProfileContainer(
                  "Most Seen Movies", moviesTemp, Icons.movie, "Movie"),
              buildProfileContainer("Favorite Actors", friendFavActors,
                  Icons.theater_comedy, "Person"),
              buildProfileContainer("Favorite Directors", friendFavDirectors,
                  Icons.chair, "Person"),
            ],
          ),
        ),
        bottomNavigationBar: CommonBottomAppBar(-1),
      );
    } else {
      return const Scaffold();
    }
  }

  Widget buildProfileContainer(String title, List content, icon, type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(5.0),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(
                'Their $title',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content.isEmpty) const Text("Nothing here yet"),
          if (content.isEmpty) const SizedBox(height: 10),
          if (content.isNotEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.22,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: content.length > 10 ? 10 : content.length,
                itemBuilder: (context, index) {
                  var item;
                  if (type == "Person") {
                    item = Person(id: content[index][1], name: "", data: {});
                  } else {
                    item =
                        Movie(id: content[index][1], title: "", coverPhoto: "");
                  }
                  return FutureBuilder<Map>(
                    future: type == "Person"
                        ? item.getSimpleData()
                        : item.getData(),
                    builder:
                        (BuildContext context, AsyncSnapshot<Map> snapshot) {
                      if (snapshot.hasData) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => type == "Person"
                                      ? PersonResult(
                                          personResult: item as Person)
                                      : MovieResult(movie: item as Movie)),
                            );
                          },
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: MediaQuery.of(context).size.width * 0.28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(27),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  type == "Person"
                                      ? snapshot.data!["profile_path"]
                                      : IMG_LINK +
                                          snapshot.data!["poster_path"],
                                ),
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return const Center(
                            child: Text("Failed to load movie details"));
                      } else {
                        return Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: MediaQuery.of(context).size.width * 0.28,
                            height: MediaQuery.of(context).size.height * 0.18,
                            child: const Center(
                                child: CircularProgressIndicator()));
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
