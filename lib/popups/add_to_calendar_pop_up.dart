// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/TVShow.dart';
import 'dart:convert';

import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart';
import '../objects/Media.dart';

class CalendarAddDialogue extends StatefulWidget {
  final String dateForMap;
  final String dateRange;
  final String type;
  const CalendarAddDialogue(
      {Key? key,
      required this.dateForMap,
      required this.dateRange,
      required this.type})
      : super(key: key);

  @override
  _CalendarAddDialogueState createState() => _CalendarAddDialogueState();
}

class _CalendarAddDialogueState extends State<CalendarAddDialogue> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  final myController = TextEditingController(text: "");

  String _searchTermMovie = '';
  Map _movie = {};
  Future<List> searchData(String searchTerm) async {
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = widget.type == "movie"
          ? '$SEARCH_BY_NAME_MOVIE_LINK$name'
          : '$SEARCH_BY_NAME_TV_SHOW_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json["results"];
      } else {
        throw Exception('Failed to load movie details');
      }
    } else {
      return [];
    }
  }

  String getDefaultImagePath(String? imagePath) {
    const defaultPath =
        'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
    return imagePath == null ||
            imagePath ==
                "https://cdn-icons-png.flaticon.com/512/3088/3088765.png"
        ? defaultPath
        : IMG_LINK + imagePath;
  }

  Widget buildItem(BuildContext context, Map item, int index, bool isSelected) {
    if (item.containsKey("poster_path") && item.containsKey("title")) {
      // movieResult = [item['id'], item['title'], "Movies"];
      item['profile_path'] = getDefaultImagePath(item['poster_path']);
    } else if (item.containsKey("poster_path") && item.containsKey("name")) {
      item['profile_path'] = getDefaultImagePath(item['poster_path']);
    } else {
      item['profile_path'] = getDefaultImagePath(item['profile_path']);
    }
    return GestureDetector(
      onTap: () => {
        setState(() {
          _selectedIndex = index;
          _movie = item;
        })
      },
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(item['profile_path']),
                fit: BoxFit.fitWidth,
              ),
              border: isSelected
                  ? Border.all(
                      color: const Color.fromARGB(250, 224, 190, 78), width: 3)
                  : null,
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.28,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                item['title'] ??
                    (item["name"] ??
                        'Unkown'), // Replace 'title' with the appropriate key
                style: const TextStyle(
                  fontSize: 14, // Adjust the font size as needed
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void addMovieSubmit(String id, String title, int runtime, double rating,
      Map friendsWatchedWith) async {
    String key = widget.type == "movie" ? "Movies" : "TVShows";
    Map myObject = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating,
      'friends': friendsWatchedWith.keys
          .where((key) => friendsWatchedWith[key] == true)
          .toList(),
      'type': widget.type,
    };
    if (widget.dateRange != "") {
      DateTime startDate = DateTime.parse(widget.dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(widget.dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        if (currentUser.calendar.keys.toList().contains(dateStr)) {
          currentUser.calendar[dateStr].add(myObject);
        } else {
          currentUser.calendar[dateStr] = [
            myObject,
          ];
        }
      }
    } else {
      if (currentUser.calendar.keys.toList().contains(widget.dateForMap)) {
        currentUser.calendar[widget.dateForMap].add(myObject);
      } else {
        currentUser.calendar[widget.dateForMap] = [
          myObject,
        ];
      }
    }
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    for (var friend in friendsWatchedWith.keys) {
      myObject["friends"] = [
        currentUser.uid,
      ];
      for (var friend2 in friendsWatchedWith.keys) {
        if (friendsWatchedWith[friend] == true) {
          if (!myObject["friends"].contains(friend2) && friend != friend2) {
            myObject["friends"].add(friend2);
          }
        }
      }
      if (friendsWatchedWith[friend] == true) {
        if (currentUser.seenWith.containsKey(friend) &&
            !currentUser.seenWith[friend][key].contains(id.toString())) {
          currentUser.seenWith[friend][key].add(id.toString());
        } else if (!currentUser.seenWith.containsKey(friend)) {
          currentUser.seenWith[friend] = {"Movies": [], "TVShows": []};
          currentUser.seenWith[friend][key].add(id.toString());
        }
        var userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Calendar");
        if (widget.dateRange != "") {
          DateTime startDate = DateTime.parse(widget.dateRange.split("T")[0]);
          DateTime endDate = DateTime.parse(widget.dateRange.split("T")[1]);

          for (DateTime date = startDate;
              date.isBefore(endDate.add(const Duration(days: 1)));
              date = date.add(const Duration(days: 1))) {
            String dateStr = date.toIso8601String().split("T")[0];
            await userDoc.update({
              dateStr: FieldValue.arrayUnion([myObject])
            });
          }
        } else {
          await userDoc.update({
            widget.dateForMap: FieldValue.arrayUnion([myObject])
          });
        }

        userDoc = FirebaseFirestore.instance.collection(friend).doc(key);
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

        await firestore.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(userDoc2);

          if (!snapshot.exists) {
            throw Exception("Document does not exist!");
          }

          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          if (data.containsKey(key) && data[key] is Map<String, dynamic>) {
            Map<String, dynamic> moviesMap = data[key];

            if (moviesMap.containsKey(id)) {
              List existingList = moviesMap[id]["friends"];
              for (String person in watchedWithList) {
                if (!existingList.contains(person) && person != friend) {
                  existingList.add(person);
                }
              }
              if (!existingList.contains(currentUser.uid)) {
                existingList.add(currentUser.uid);
              }
              moviesMap[id] = {"friends": existingList};
              transaction.update(userDoc2, {key: moviesMap});
            } else {
              watchedWithList.remove(friend);
              watchedWithList.add(currentUser.uid);
              moviesMap[id] = {"friends": watchedWithList};
              transaction.update(userDoc2, {key: moviesMap});
            }
          } else {
            transaction.set(
                userDoc2,
                {
                  key: {
                    id: {"friends": watchedWithList}
                  }
                },
                SetOptions(merge: true));
          }
        }).catchError((error) {
          print("Failed to update document: $error");
        });
        if (widget.type == "movie") {
          userDoc =
              FirebaseFirestore.instance.collection(friend).doc("Rewatched");
          DocumentSnapshot doc = await userDoc.get();
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            if (data.containsKey(id)) {
              await userDoc.update({id: FieldValue.increment(1)});
            } else {
              await userDoc.update({id: 1});
            }
          }
        }
      }
    }

    DocumentReference userDoc2 =
        firestore.collection(currentUser.uid).doc("SeenWith");
    Map<String, dynamic> item = {};
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    item[id] = watchedWithList;
    myObject["friends"] = watchedWithList;

    firestore.runTransaction((transaction) async {
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
        } else {
          moviesMap[id] = {"friends": watchedWithList};
        }
        transaction.update(userDoc2, {'Movies': moviesMap});
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
    var userDoc = db.collection(currentUser.uid).doc("Calendar");
    Map<Object, Object> updatedCalendar = {};
    for (String key in currentUser.calendar.keys) {
      updatedCalendar[key] = currentUser.calendar[key];
    }
    await userDoc.update(updatedCalendar);

    if (currentUser.rewatchedMovies.keys.toList().contains(id)) {
      currentUser.rewatchedMovies[id] += 1;
    } else {
      currentUser.rewatchedMovies[id] = 1;
    }

    userDoc = db.collection(currentUser.uid).doc("Rewatched");
    Map<Object, Object> updatedRewatched = {};
    for (String key in currentUser.rewatchedMovies.keys) {
      updatedRewatched[key] = currentUser.rewatchedMovies[key];
    }
    await userDoc.update(updatedRewatched);

    if (widget.type == "movie") {
      if (!Utils.containsList(currentUser.seenMovies, ["Movies", id])) {
        final userDoc = FirebaseFirestore.instance
            .collection(currentUser.uid)
            .doc('Movies');
        id = id.toString();
        await userDoc.update({
          'Seen': FieldValue.arrayUnion([id])
        });
        currentUser.seenMovies += [
          ["Movies", id]
        ];
      }
    } else {
      if (!Utils.containsList(currentUser.seenTVShows, ["TVShows", id])) {
        final userDoc = FirebaseFirestore.instance
            .collection(currentUser.uid)
            .doc('TVShows');
        id = id.toString();
        await userDoc.update({
          'Seen': FieldValue.arrayUnion([id])
        });
        currentUser.seenTVShows += [
          ["TVShows", id]
        ];
      }
    }
  }

  Map<String, bool> selectedFriends = {};

  @override
  void initState() {
    super.initState();
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isMovie = widget.type == "movie";
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Container(
        padding:
            const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
                child: Text(
                  isMovie ? 'Add a Movie' : "Add a Show",
                  style: const TextStyle(
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
                    if (value == null || value.isEmpty || _movie == {}) {
                      return isMovie
                          ? 'Please select a movie'
                          : 'Please select a show';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: isMovie
                        ? 'Name of The Movie You\'d Like to Add'
                        : 'Name of The Show You\'d Like to Add',
                    labelStyle: const TextStyle(color: Colors.white),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchTermMovie = value;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  height: 190,
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
                            bool isSelected = index == _selectedIndex;
                            if (isSelected) {
                              _movie = item;
                            }
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              child: GridTile(
                                child: buildItem(context, snapshot.data![index],
                                    index, isSelected),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
              if (currentUser.friends.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 5),
                  child: Text(
                    'Did you watch it with anyone?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (currentUser.friends.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SizedBox(
                    height: 125, // Set your desired height here
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentUser.friends.length,
                      itemBuilder: (context, friendIndex) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection(currentUser.friends[friendIndex])
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
                                        style: const TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                value: selectedFriends.keys.toList().contains(
                                        currentUser.friends[friendIndex])
                                    ? selectedFriends[
                                        currentUser.friends[friendIndex]]
                                    : false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedFriends[currentUser
                                        .friends[friendIndex]] = value!;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
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
                            width: 5,
                          ),
                          Text(
                            "Cancel",
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          )
                        ],
                      )),
                  const SizedBox(
                    width: 5,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context, true);
                      MediaItem tempMovie = widget.type == "movie"
                          ? Movie(
                              id: _movie["id"].toString(),
                              title: _movie["title"].toString(),
                              coverPhoto: _movie["poster_path"].toString())
                          : TVShow(
                              id: _movie["id"].toString(),
                              title: _movie["name"].toString(),
                              coverPhoto: _movie["poster_path"].toString());
                      Map movieData = await tempMovie.getExtendedData();

                      addMovieSubmit(
                          tempMovie.id,
                          tempMovie.title,
                          movieData["runtime"] ?? 0,
                          double.parse(movieData["imdb_rating"]),
                          selectedFriends);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: Colors.green,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          "Accept",
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddToCalendar extends StatefulWidget {
  final String dateForMap;
  final Movie movie;
  const AddToCalendar({Key? key, required this.movie, required this.dateForMap})
      : super(key: key);

  @override
  _AddToCalendarState createState() => _AddToCalendarState();
}

class _AddToCalendarState extends State<AddToCalendar> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  Map<String, bool> selectedFriends = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Add rounded corners
      ),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Did you watch it with anyone?",
              style: TextStyle(fontSize: 20),
            ),
            if (currentUser.friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  height: 125, // Set your desired height here
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentUser.friends.length,
                    itemBuilder: (context, friendIndex) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection(currentUser.friends[friendIndex])
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
                              value: selectedFriends.keys.toList().contains(
                                      currentUser.friends[friendIndex])
                                  ? selectedFriends[
                                      currentUser.friends[friendIndex]]
                                  : false,
                              onChanged: (bool? value) {
                                setState(() {
                                  selectedFriends[currentUser
                                      .friends[friendIndex]] = value!;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
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
                          width: 5,
                        ),
                        Text(
                          "Cancel",
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        )
                      ],
                    )),
                const SizedBox(
                  width: 5,
                ),
                ElevatedButton(
                  onPressed: () async {
                    Map data = await widget.movie.getExtendedData();
                    addMovieSubmit(
                        widget.movie.id,
                        widget.movie.title,
                        data["runtime"] ?? 0,
                        double.parse(data["imdb_rating"]),
                        selectedFriends);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: Colors.green,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        "Accept",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> addMovieSubmit(String id, String title, int runtime,
      double rating, Map friendsWatchedWith) async {
    Map myObject = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating,
      'friends': friendsWatchedWith.keys
          .where((key) => friendsWatchedWith[key] == true)
          .toList(),
    };

    if (currentUser.calendar.keys.toList().contains(widget.dateForMap)) {
      currentUser.calendar[widget.dateForMap].add(myObject);
    } else {
      currentUser.calendar[widget.dateForMap] = [
        myObject,
      ];
    }

    FirebaseFirestore firestore = FirebaseFirestore.instance;
    for (var friend in friendsWatchedWith.keys) {
      myObject["friends"] = [
        currentUser.uid,
      ];
      for (var friend2 in friendsWatchedWith.keys) {
        if (friendsWatchedWith[friend] == true) {
          if (!myObject["friends"].contains(friend2) && friend != friend2) {
            myObject["friends"].add(friend2);
          }
        }
      }
      if (friendsWatchedWith[friend] == true) {
        if (currentUser.seenWith.containsKey(friend) &&
            !currentUser.seenWith[friend]["Movies"].contains(id.toString())) {
          currentUser.seenWith[friend]["Movies"].add(id.toString());
        } else if (!currentUser.seenWith.containsKey(friend)) {
          currentUser.seenWith[friend] = {"Movies": [], "TVShows": []};
          currentUser.seenWith[friend]["Movies"].add(id.toString());
        }
        var userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Calendar");
        await userDoc.update({
          widget.dateForMap: FieldValue.arrayUnion([myObject])
        });

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

        await firestore.runTransaction((transaction) async {
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
                if (!existingList.contains(person) && person != friend) {
                  existingList.add(person);
                }
              }
              if (!existingList.contains(currentUser.uid)) {
                existingList.add(currentUser.uid);
              }
              moviesMap[id] = {"friends": existingList};
              transaction.update(userDoc2, {"Movies": moviesMap});
            } else {
              watchedWithList.remove(friend);
              watchedWithList.add(currentUser.uid);
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

        userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Rewatched");
        DocumentSnapshot doc = await userDoc.get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data.containsKey(id)) {
            await userDoc.update({id: FieldValue.increment(1)});
          } else {
            await userDoc.update({id: 1});
          }
        }
      }
    }

    DocumentReference userDoc2 =
        firestore.collection(currentUser.uid).doc("SeenWith");
    Map<String, dynamic> item = {};
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    item[id] = watchedWithList;
    myObject["friends"] = watchedWithList;

    firestore.runTransaction((transaction) async {
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
        } else {
          moviesMap[id] = {"friends": watchedWithList};
        }
        transaction.update(userDoc2, {'Movies': moviesMap});
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
    var userDoc = db.collection(currentUser.uid).doc("Calendar");
    Map<Object, Object> updatedCalendar = {};
    for (String key in currentUser.calendar.keys) {
      updatedCalendar[key] = currentUser.calendar[key];
    }
    await userDoc.update(updatedCalendar);

    if (currentUser.rewatchedMovies.keys.toList().contains(id)) {
      currentUser.rewatchedMovies[id] += 1;
    } else {
      currentUser.rewatchedMovies[id] = 1;
    }

    userDoc = db.collection(currentUser.uid).doc("Rewatched");
    Map<Object, Object> updatedRewatched = {};
    for (String key in currentUser.rewatchedMovies.keys) {
      updatedRewatched[key] = currentUser.rewatchedMovies[key];
    }
    await userDoc.update(updatedRewatched);

    if (!Utils.containsList(currentUser.seenMovies, ["Movies", id])) {
      final userDoc =
          FirebaseFirestore.instance.collection(currentUser.uid).doc('Movies');
      id = id.toString();
      await userDoc.update({
        'Seen': FieldValue.arrayUnion([id])
      });
      currentUser.seenMovies += [
        ["Movies", id]
      ];
    }
    return true;
  }
}
