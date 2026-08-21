// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/common/calendar_episode.dart';
import 'package:uractor/common/firebase/calendar_progress_service.dart';
import 'package:uractor/common/firebase/calendar_service.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/firebase/social_service.dart';
import 'package:uractor/common/firebase/watched_service.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/watch_progress_view.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/tv_show.dart';
import 'dart:convert';

import '../common/constants.dart';
import '../common/utils.dart';
import '../main.dart';
import '../objects/media.dart';
import '../common/firebase/firestore_core.dart';
import '../common/api/http_client.dart';
import '../common/layout/responsive.dart';

class CalendarAddDialogue extends StatefulWidget {
  final String dateForMap;
  final String dateRange;
  final String type;
  const CalendarAddDialogue(
      {super.key,
      required this.dateForMap,
      required this.dateRange,
      required this.type});

  @override
  State<CalendarAddDialogue> createState() => _CalendarAddDialogueState();
}

class _CalendarAddDialogueState extends State<CalendarAddDialogue> {
  FirebaseFirestore db = FirestoreCore.db;
  final myController = TextEditingController(text: "");
  final _seasonController = TextEditingController();
  final _episodeController = TextEditingController();

  /// What the season/episode boxes currently amount to, or null when they are
  /// empty or hold something that is not a part number. Both boxes are
  /// optional, so null is an ordinary answer and not an error.
  CalendarEpisode? get _episode => CalendarEpisode.from(
        season: _seasonController.text,
        episode: _episodeController.text,
      );

  @override
  void dispose() {
    myController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

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
      final response = await AppHttp.client.get(Uri.parse(searchLink));
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

  Widget buildItem(BuildContext context, Map item, int index, bool isSelected) {
    if (item.containsKey("poster_path") &&
        (item.containsKey("title") || item.containsKey("name"))) {
      item['poster_path'] = item['poster_path'];
    } else {
      item['poster_path'] = item['profile_path'];
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
          getItemSelectableContainer(context, item, "media", isSelected),
          SizedBox(
            width: context.posterWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                item['title'] ?? (item["name"] ?? 'Unkown'),
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> addMovieSubmit(String id, String title, int runtime,
      double rating, Map friendsWatchedWith, CalendarEpisode? episode,
      [List<SeasonEpisodeCount> seasons = const <SeasonEpisodeCount>[]]) async {
    String key = widget.type == "movie" ? "Movies" : "TVShows";
    // What this entry means for tracking, decided before anything is written.
    // An entry naming an episode records progress instead of claiming the
    // whole show was finished, which is what it used to do.
    final intent = await CalendarProgressService.apply(
      type: widget.type,
      id: id.toString(),
      episode: episode,
      seasons: seasons,
    );
    Map myObject = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating,
      'friends': friendsWatchedWith.keys
          .where((key) => friendsWatchedWith[key] == true)
          .toList(),
      'type': widget.type,
      // Absent unless the user filled the boxes in, which is what keeps an
      // untagged entry identical to what every installed client writes.
      ...CalendarEpisode.fieldsFor(episode),
    };
    CalendarService.updateCurrentUserCalendar(
        widget.dateRange, myObject, widget.dateForMap);
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
        await CalendarService.updateCalendar(
            widget.dateRange, friend, myObject, widget.dateForMap);
        // A friend's progress cannot be written from here -- the rules let a
        // client write its own Progress document and nobody else's -- so an
        // entry naming one episode says nothing about their state rather than
        // claiming they finished the show.
        if (intent.marksFriendsSeen) {
          await WatchedService.updateSeen(key, friend, id);
        }
        await SocialService.updateSeenWith(friend, friendsWatchedWith, id, key);
        if (widget.type == "movie") {
          await WatchedService.updateRewatched(friend, id, "movie");
        }
      }
    }
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    await SocialService.updateCurrentUserSeenWith(
        currentUser.uid, id, key, friendsWatchedWith, watchedWithList);
    myObject["friends"] = watchedWithList;
    await CalendarService.updateCurrentUserCalendarDocument();
    if (widget.type == "movie") {
      if (currentUser.rewatchedMovies.keys.toList().contains(id)) {
        currentUser.rewatchedMovies[id] += 1;
      } else {
        currentUser.rewatchedMovies[id] = 1;
      }
      await WatchedService.updateCurrentUserRewatched();
      if (intent.marksSelfSeen &&
          !Utils.containsList(currentUser.seenMovies, ["Movies", id])) {
        id = id.toString();
        await WatchedService.updateSeen(key, currentUser.uid, id);
        currentUser.seenMovies += [
          ["Movies", id]
        ];
        currentUser.seen += [
          ["Movies", id]
        ];
      }
    } else {
      if (intent.marksSelfSeen &&
          !Utils.containsList(currentUser.seenTVShows, ["TVShows", id])) {
        id = id.toString();
        await WatchedService.updateSeen(key, currentUser.uid, id);
        currentUser.seenTVShows += [
          ["TVShows", id]
        ];
        currentUser.seen += [
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
              if (!isMovie)
                _EpisodeFields(
                  seasonController: _seasonController,
                  episodeController: _episodeController,
                  onChanged: () => setState(() {}),
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
                    height: 125,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentUser.friends.length,
                      itemBuilder: (context, friendIndex) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirestoreCore.db
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
                      final saved = await runVisibleAsyncAction(
                        context,
                        () async {
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

                          await addMovieSubmit(
                              tempMovie.id,
                              tempMovie.title,
                              movieData["runtime"] ?? 0,
                              double.parse(movieData["imdb_rating"]),
                              selectedFriends,
                              _episode,
                              WatchProgressView.seasonCounts(
                                  movieData["seasons"] as List?));
                        },
                        S.of(context)!.genericAuthError,
                      );
                      if (saved && context.mounted) {
                        Navigator.pop(context, true);
                      }
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
  final MediaItem media;
  final bool modifying;
  final List friends;
  final String type;
  const AddToCalendar(
      {super.key,
      required this.media,
      required this.dateForMap,
      required this.modifying,
      required this.friends,
      required this.type});

  @override
  State<AddToCalendar> createState() => _AddToCalendarState();
}

class _AddToCalendarState extends State<AddToCalendar> {
  FirebaseFirestore db = FirestoreCore.db;
  Map<String, bool> selectedFriends = {};
  final _seasonController = TextEditingController();
  final _episodeController = TextEditingController();

  CalendarEpisode? get _episode => CalendarEpisode.from(
        season: _seasonController.text,
        episode: _episodeController.text,
      );

  @override
  void initState() {
    super.initState();
    for (String friendUid in widget.friends) {
      selectedFriends[friendUid] =
          widget.modifying && widget.friends.contains(friendUid);
    }
    _prefillEpisode();
  }

  /// Editing an existing entry has to start from what that entry already
  /// records, or reopening the dialogue to change who you watched with would
  /// silently drop the season and episode.
  void _prefillEpisode() {
    if (!widget.modifying) return;
    final day = currentUser.calendar[widget.dateForMap];
    if (day is! List) return;
    for (final entry in day) {
      if (entry is Map && entry['id'].toString() == widget.media.id) {
        final episode = CalendarEpisode.fromEntry(entry);
        if (episode == null) return;
        _seasonController.text = episode.season.toString();
        _episodeController.text = episode.episode?.toString() ?? '';
        return;
      }
    }
  }

  @override
  void dispose() {
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
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
            if (widget.type != "movie")
              _EpisodeFields(
                seasonController: _seasonController,
                episodeController: _episodeController,
                onChanged: () => setState(() {}),
              ),
            if (currentUser.friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  height: 125,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentUser.friends.length,
                    itemBuilder: (context, friendIndex) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirestoreCore.db
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
                    final saved = await runVisibleAsyncAction(
                      context,
                      () async {
                        Map data = await widget.media.getExtendedData();
                        if (!widget.modifying) {
                          await addMovieSubmit(
                              widget.media.id,
                              widget.media.title,
                              data["runtime"] ?? 0,
                              double.parse(data["imdb_rating"]),
                              selectedFriends);
                        } else {
                          await modifyCalendarEntry(
                              widget.media.id,
                              widget.media.title,
                              data["runtime"] ?? 0,
                              double.parse(data["imdb_rating"]),
                              selectedFriends,
                              widget.type,
                              WatchProgressView.seasonCounts(
                                  data["seasons"] as List?));
                        }
                      },
                      S.of(context)!.genericAuthError,
                    );
                    if (saved && context.mounted) {
                      Navigator.pop(context, true);
                    }
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

  Future<bool> modifyCalendarEntry(String id, String title, int runtime,
      double rating, Map friendsMap, String type,
      [List<SeasonEpisodeCount> seasons = const <SeasonEpisodeCount>[]]) async {
    // Adding an episode to an entry that never had one is the same statement
    // as recording it in the first place, so it drives tracking the same way.
    await CalendarProgressService.apply(
      type: type,
      id: id.toString(),
      episode: _episode,
      seasons: seasons,
    );
    List watchedWithList =
        friendsMap.keys.where((key) => friendsMap[key] == true).toList();
    List oldFriends = [];
    for (Map movieInfo in currentUser.calendar[widget.dateForMap]) {
      if (movieInfo["id"] == id) {
        oldFriends = List.from(movieInfo["friends"]);
        movieInfo["friends"] = watchedWithList;
        break;
      }
    }
    Map newData = {
      'id': id,
      'title': title,
      'runtime': runtime,
      'rating': rating,
      'friends': watchedWithList,
      'type': type,
      ...CalendarEpisode.fieldsFor(_episode),
    };
    await CalendarService.updateCalendar(
        "", currentUser.uid, newData, widget.dateForMap);
    await CalendarService.deleteFromCalendar(
        currentUser.uid, id, title, widget.dateForMap, context);

    List allFriends = [];
    for (String friend in oldFriends) {
      if (!allFriends.contains(friend)) {
        allFriends.add(friend);
      }
    }
    for (String friend in watchedWithList) {
      if (!allFriends.contains(friend)) {
        allFriends.add(friend);
      }
    }

    for (String friend in allFriends) {
      List finalFriends = [];

      finalFriends = List.from(watchedWithList);
      finalFriends.remove(friend);
      if (watchedWithList.contains(friend)) {
        finalFriends.add(currentUser.uid);
      } else {
        finalFriends = [];
      }

      Map friendNewData = {
        'id': id,
        'title': title,
        'runtime': runtime,
        'rating': rating,
        'friends': finalFriends,
        'type': type,
        ...CalendarEpisode.fieldsFor(_episode),
      };
      await CalendarService.deleteFromCalendar(
          friend, id, title, widget.dateForMap, context);
      await CalendarService.updateCalendar(
          "", friend, friendNewData, widget.dateForMap);
      continue;
    }
    return true;
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
        await CalendarService.updateCalendar(
            "", friend, myObject, widget.dateForMap);
        await WatchedService.updateSeen("Movies", friend, id);
        await SocialService.updateSeenWith(
            friend, friendsWatchedWith, id, "Movies");
        await WatchedService.updateRewatched(friend, id, "movie");
      }
    }
    List<dynamic> watchedWithList = friendsWatchedWith.keys
        .where((key) => friendsWatchedWith[key] == true)
        .toList();
    myObject["friends"] = watchedWithList;
    await SocialService.updateCurrentUserSeenWith(
        currentUser.uid, id, "Movies", friendsWatchedWith, watchedWithList);

    await CalendarService.updateCurrentUserCalendarDocument();
    if (currentUser.rewatchedMovies.keys.toList().contains(id)) {
      currentUser.rewatchedMovies[id] += 1;
    } else {
      currentUser.rewatchedMovies[id] = 1;
    }
    await WatchedService.updateCurrentUserRewatched();
    if (!Utils.containsList(currentUser.seenMovies, ["Movies", id])) {
      await WatchedService.updateSeen("Movies", currentUser.uid, id);
      currentUser.seenMovies += [
        ["Movies", id]
      ];
      currentUser.seen += [
        ["Movies", id]
      ];
    }
    return true;
  }
}

/// The optional season and episode boxes shown when the entry being recorded
/// is a show.
///
/// Deliberately two loose numbers rather than a picker over TMDB's season
/// list: the calendar is a log of what you watched, entries for shows whose
/// metadata TMDB does not have still have to be recordable, and leaving both
/// boxes empty has to keep producing exactly the entry earlier clients wrote.
class _EpisodeFields extends StatelessWidget {
  const _EpisodeFields({
    required this.seasonController,
    required this.episodeController,
    required this.onChanged,
  });

  final TextEditingController seasonController;
  final TextEditingController episodeController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // An episode with no season cannot be stored, so say so rather than
    // dropping what was typed on save without explanation.
    final bool needsSeason =
        CalendarEpisode.parsePositiveInt(episodeController.text) != null &&
            CalendarEpisode.parsePositiveInt(seasonController.text) == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.calendarEpisodeSectionTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // The answer ticks everything before it, which is right far more
          // often than not but is not something to spring on someone.
          Text(
            S.of(context)!.calendarEpisodeBackfillNote,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: seasonController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: S.of(context)!.calendarSeasonFieldLabel,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: episodeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: S.of(context)!.calendarEpisodeFieldLabel,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          if (needsSeason)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                S.of(context)!.calendarEpisodeNeedsSeason,
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
