// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/media_pair_membership.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/media.dart';
import 'package:uractor/objects/tv_show.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'common/utils.dart';
import 'friends.dart';
import 'friends_calendar.dart';
import 'objects/movie.dart';
import 'main.dart';
import 'objects/person.dart';
import 'person_result.dart';
import 'movie_result.dart';

import 'seen_together.dart';
import 'tvshow_result.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';

int weekOffset = 0; // This will be used to go to previous or next weeks

class FriendProfile extends StatefulWidget {
  final String friendUid;
  const FriendProfile({super.key, required this.friendUid});

  @override
  State<FriendProfile> createState() => _FriendProfileState();
}

class _FriendProfileState extends State<FriendProfile> {
  List friendFavActors = [];
  Map friendSettings = {};
  Map friendRewatchedMovies = {};
  Map friendRewatchedTV = {};
  List friendFavDirectors = [];
  List friendFavWriters = [];
  Map friendCalendar = {};
  bool gotData = false;

  List<Map<String, dynamic>> movies = [];
  Future<Map<String, dynamic>> getData(dynamic id, String type) async {
    return Utils.fetchMediaData(id, type, movies);
  }

  Future<void> getFirebaseData() async {
    await FirestoreCore.db
        .collection(widget.friendUid)
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
        } else if (doc.id == "FavWriters" && friendFavWriters.isEmpty) {
          Map tempFavWriters = doc.data() as Map;
          friendFavWriters = tempFavWriters.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          friendFavWriters.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "Settings" &&
            friendSettings.keys.toList().isEmpty) {
          friendSettings = doc.data() as Map;
        } else if (doc.id == "Rewatched" &&
            friendRewatchedMovies.keys.isEmpty) {
          friendRewatchedMovies = doc.data() as Map;
        } else if (doc.id == "RewatchedTV" && friendRewatchedTV.keys.isEmpty) {
          friendRewatchedTV = doc.data() as Map;
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
      List seenTogetherTotal = [];
      if (currentUser.seenWith.keys.toList().contains(friendUid)) {
        for (String item in currentUser.seenWith[friendUid]["TVShows"]) {
          seenTogetherTotal.add(["TVShows", item]);
        }
        for (String item in currentUser.seenWith[friendUid]["Movies"]) {
          seenTogetherTotal.add(["Movies", item]);
        }
      }

      List tvTemp = [];
      friendRewatchedTV.forEach((key, value) {
        tvTemp.add([value, key]);
      });

      tvTemp.sort((a, b) => b[0].compareTo(a[0]));

      List tempActors = [];
      for (List item in friendFavActors) {
        if (item[0] != 0) tempActors.add(item);
      }

      List tempWriters = [];
      for (List item in friendFavWriters) {
        if (item[0] != 0) tempWriters.add(item);
      }

      List tempDirectors = [];
      for (List item in friendFavDirectors) {
        if (item[0] != 0) tempDirectors.add(item);
      }

      List<Widget> buildProfileSections() {
        List<Widget> sections = [];
        var profileSections = friendSettings["profileSections"];
        List<MapEntry<dynamic, dynamic>> sectionsList =
            friendSettings["profileSections"].entries.toList();
        sectionsList
            .sort((a, b) => a.value["weight"].compareTo(b.value["weight"]));

        var sectionKeys = Map.fromEntries(sectionsList).keys.toList();
        for (var key in sectionKeys) {
          if (profileSections[key]["show"]) {
            switch (key) {
              case "Actors":
                sections.add(buildProfileContainer(S.of(context)!.favActors,
                    tempActors, Icons.theater_comedy, "Person"));
                break;
              case "Directors":
                sections.add(buildProfileContainer(S.of(context)!.favDirectors,
                    tempDirectors, Icons.chair, "Person"));
                break;
              case "MostSeenMovies":
                sections.add(buildProfileContainer(S.of(context)!.favMovies,
                    moviesTemp, Icons.movie, "Movie"));
                break;
              case "Writers":
                sections.add(buildProfileContainer(S.of(context)!.favWriters,
                    tempWriters, Icons.edit, "Person"));
                break;
              case "MostSeenTVShows":
                sections.add(buildProfileContainer(
                    S.of(context)!.favTVShows, tvTemp, Icons.tv, "TVShow"));
                break;
            }
          }
        }

        return sections;
      }

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
                            title: Text((S.of(context)!.confirmation)),
                            content:
                                Text(S.of(context)!.removeFriendConfirmation),
                            actions: <Widget>[
                              TextButton(
                                child: Text(S.of(context)!.no),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: Text(S.of(context)!.yes),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed) {
                        // Remove friend from current user's friend list
                        await FirestoreCore.updateDocument(
                            friendUid, "Friends", {
                          'friends': FieldValue.arrayRemove([currentUser.uid])
                        });

                        // Remove current user from friend's friend list
                        await FirestoreCore.updateDocument(
                            currentUser.uid, "Friends", {
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
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          S.of(context)!.calendar,
                          style: const TextStyle(
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
              if (currentUser.seenWith.containsKey(friendUid))
                buildMainPageContainer(
                  "Seen Together",
                  seenTogetherTotal,
                  Icons.group,
                  SeenTogether(
                    friendSettings: friendSettings,
                  ),
                ),
              if (!currentUser.seenWith.containsKey(friendUid))
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
                      Text(S.of(context)!.noMoviesTogether),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              ...buildProfileSections(),
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
                S.of(context)!.friendSections(title),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content.isEmpty) Text(S.of(context)!.emptySection),
          if (content.isEmpty) const SizedBox(height: 10),
          if (content.isNotEmpty)
            SizedBox(
              height: posterRowHeight(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: content.length > 10 ? 10 : content.length,
                itemBuilder: (context, index) {
                  dynamic item;
                  if (type == "Person") {
                    item = Person(id: content[index][1], name: "", data: {});
                  } else if (type == "Movie") {
                    item =
                        Movie(id: content[index][1], title: "", coverPhoto: "");
                  } else {
                    item = TVShow(
                        id: content[index][1], title: "", coverPhoto: "");
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
                                      : type == "Movie"
                                          ? MovieResult(movie: item as Movie)
                                          : TVShowResult(
                                              tvshow: item as TVShow),
                                ),
                              );
                            },
                            child: getItemContainer(context, snapshot.data,
                                type == "Person" ? "person" : "media",
                                mediaPair: type == "Person"
                                    ? null
                                    : mediaPairForData(snapshot.data)));
                      } else if (snapshot.hasError) {
                        return Center(
                            child:
                                Text(S.of(context)!.errorFailedToLoadDetails));
                      } else {
                        return Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: context.posterWidth,
                            height: posterHeightFor(context.posterWidth),
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

  Widget buildMainPageContainer(String title, List content, icon, page) {
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
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => page,
                    ),
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      S.of(context)!.seeAll(content.length),
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
          if (content.isEmpty) Text(S.of(context)!.emptySection),
          if (content.isEmpty) const SizedBox(height: 10),
          if (content.isNotEmpty)
            SizedBox(
              height: posterRowHeight(context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: content.length > 10 ? 10 : content.length,
                itemBuilder: (context, index) {
                  MediaItem tempMedia;
                  if (content.reversed.toList()[index][0] == "Movies") {
                    tempMedia = Movie(
                        id: content.reversed.toList()[index][1],
                        title: "title",
                        coverPhoto: "coverPhoto");
                  } else {
                    tempMedia = TVShow(
                        id: content.reversed.toList()[index][1],
                        title: "title",
                        coverPhoto: "coverPhoto");
                  }
                  return FutureBuilder<Map>(
                    future: tempMedia.getData(),
                    builder:
                        (BuildContext context, AsyncSnapshot<Map> snapshot) {
                      if (snapshot.hasData) {
                        return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => content.reversed
                                                .toList()[index][0] ==
                                            "Movies"
                                        ? MovieResult(movie: tempMedia as Movie)
                                        : TVShowResult(
                                            tvshow: tempMedia as TVShow)),
                              );
                            },
                            child: getItemContainer(
                                context, snapshot.data, "media",
                                mediaPair: mediaPairForData(snapshot.data)));
                      } else if (snapshot.hasError) {
                        return Center(
                            child:
                                Text(S.of(context)!.errorFailedToLoadDetails));
                      } else {
                        return Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: context.posterWidth,
                            height: posterHeightFor(context.posterWidth),
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
