import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart'; // ignore_for_file: use_build_context_synchronously, non_constant_identifier_names

class CalendarAddDialogue extends StatefulWidget {
  final String dateForMap;
  const CalendarAddDialogue({Key? key, required this.dateForMap})
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
    // print(searchTerm);
    if (searchTerm != "") {
      String name = searchTerm
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-')
          .replaceAll(" ", "+");
      String searchLink = "";
      searchLink = '$SEARCH_BY_NAME_MOVIE_LINK$name';
      final response = await http.get(Uri.parse(searchLink));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<Map<String, dynamic>> results = [];
        for (final result in json['results']) {
          String resultSearchLink = '';
          resultSearchLink =
              '$MOVIE_LINK${result["id"]}-${result["title"].replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '-').replaceAll(" ", "+")}$API_KEY';
          final response2 = await http.get(Uri.parse(resultSearchLink));
          if (response2.statusCode == 200) {
            final json2 = jsonDecode(response2.body);
            final omdbLink =
                'http://www.omdbapi.com/?i=${json2["imdb_id"]}&apikey=***REMOVED***';
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
        // Update Calendar
        var userDoc =
            FirebaseFirestore.instance.collection(friend).doc("Calendar");
        await userDoc.update({
          widget.dateForMap: FieldValue.arrayUnion([myObject])
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

    DocumentReference userDoc2 =
        firestore.collection(currentUser.uid).doc("SeenWith");
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

    // setState(() {
    //   currentUser.calendar = currentUser.calendar;
    // });
  }

  Map<String, bool> selectedFriends = {};

  @override
  void initState() {
    super.initState();
  }

  int _selectedIndex = 0;

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
                            bool isSelected = index == _selectedIndex;
                            if (isSelected) {
                              _movie = item;
                            }
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              child: GridTile(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                      _movie = item;
                                    });
                                  },
                                  // _movie = item["id"].toString();
                                  // addMovieSubmit(
                                  //     item["id"].toString(),
                                  //     item["title"].toString(),
                                  //     item["runtime"],
                                  //     double.parse(item["imdbRating"]),
                                  //     selectedFriends);
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                            IMG_LINK + item['poster_path']),
                                        fit: BoxFit.cover,
                                      ),
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.blue, width: 3)
                                          : null,
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
              if (currentUser.friends.isNotEmpty)
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
                              width: 10,
                            ),
                            Text("Cancel")
                          ],
                        )),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          addMovieSubmit(
                              _movie["id"].toString(),
                              _movie["title"].toString(),
                              _movie["runtime"],
                              double.parse(_movie["imdbRating"]),
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
                              width: 10,
                            ),
                            Text("Accept")
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
