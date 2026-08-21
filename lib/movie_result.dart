// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'package:uractor/common/api/apiutils.dart';
import 'package:uractor/common/firebase/calendar_service.dart';
import 'package:uractor/common/firebase/favorites_service.dart';
import 'package:uractor/common/firebase/progress_service.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/common/firebase/watched_service.dart';
import 'package:uractor/common/firebase/watchlist_service.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/media_result_widgets.dart';
import 'package:uractor/common/mediaitembuilder.dart';
import 'package:uractor/common/viewing_history_range.dart';
import 'package:uractor/common/viewing_history_widgets.dart';
import 'package:uractor/common/watch_progress_widgets.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/popups/add_friends_seen_with_popup.dart';
import 'package:uractor/popups/add_to_calendar_pop_up.dart';

import 'cast_and_crew.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'common/navigation/appbar.dart';
import 'friends.dart';
import 'friends_profile.dart';
import 'main.dart';
import 'objects/movie.dart';
import 'objects/person.dart';
import 'person_result.dart';
import 'dart:async';
import 'common/firebase/firestore_core.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

class MovieResult extends StatefulWidget {
  final Movie movie;
  const MovieResult({super.key, required this.movie});

  @override
  State<MovieResult> createState() => _MovieResultState();
}

class _MovieResultState extends State<MovieResult> {
  final myController = TextEditingController(text: "");
  String _imageProviderSeen = 'assets/seen_before.png';
  String _imageProviderWatchlist = 'assets/watchlist_before.png';
  String _imageProviderList = 'assets/playlists_before.png';
  String _imageProviderFav = 'assets/fav_before.png';
  bool _isTappedSeen = false;
  bool _isTappedWatchlist = false;
  bool _isTappedFav = false;
  bool _isTappedList = false;

  /// Bumped whenever something outside the progress control could have changed
  /// the movie's state. Marking a movie seen finishes it, and the control has
  /// no way of noticing that on its own.
  int _progressToken = 0;

  void check() {
    if (widget.movie.isSeen()) {
      _isTappedSeen = true;
      _imageProviderSeen = 'assets/seen_after.png';
    } else {
      _isTappedSeen = false;
      _imageProviderSeen = 'assets/seen_before.png';
    }
    if (widget.movie.isBookmarked()) {
      _isTappedWatchlist = true;
      _imageProviderWatchlist = 'assets/watchlist_after.png';
    } else {
      _isTappedWatchlist = false;
      _imageProviderWatchlist = 'assets/watchlist_before.png';
    }
    if (widget.movie.isFavorite()) {
      _isTappedFav = true;
      _imageProviderFav = 'assets/fav_after.png';
    } else {
      _isTappedFav = false;
      _imageProviderFav = 'assets/fav_before.png';
    }
    if (currentUser.reviews.keys.toList().contains(widget.movie.id)) {
      reviewed = true;
    }
  }

  Future<void> _onTap(
      String type, String id, String title, int runtime, double rating) async {
    bool success = false;
    switch (type) {
      case 'seen':
        _isTappedSeen = !_isTappedSeen;
        if (_isTappedSeen) {
          success = await WatchedService.markWatched(
              id, title, runtime, rating, context, "Movies");
        } else {
          success = await WatchedService.deleteFromWatchedConfirmation(
              id, context, "Movies");
        }
        if (success) {
          setState(() {
            _imageProviderSeen = _isTappedSeen
                ? 'assets/seen_after.png'
                : 'assets/seen_before.png';
          });
        }
        break;
      case 'watchlist':
        _isTappedWatchlist = !_isTappedWatchlist;
        if (_isTappedWatchlist) {
          success = await WatchlistService.bookmark(id, context, "Movies");
          setState(() {
            currentUser.watchlist = currentUser.watchlist;
          });
        } else {
          success = await WatchlistService.unbookmark(id, context, "Movies");
          setState(() {
            currentUser.watchlist = currentUser.watchlist;
          });
        }
        break;
      case 'fav':
        _isTappedFav = !_isTappedFav;
        if (_isTappedFav) {
          success = await FavoritesService.favorite(id, context, "Movies");
          setState(() {
            currentUser.favMovies = currentUser.favMovies;
          });
        } else {
          success = await FavoritesService.unfavorite(id, context, "Movies");
          setState(() {
            currentUser.favMovies = currentUser.favMovies;
          });
        }
        break;
      case 'list':
        _isTappedList = !_isTappedList;
        if (_isTappedList) {
          _imageProviderList = 'assets/playlists_after.png';
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return watchlistsModal(id);
            },
          ).then((value) => {
                setState(() {
                  _imageProviderList = 'assets/playlists_before.png';
                  _isTappedList = !_isTappedList;
                })
              });
        } else {
          _imageProviderList = 'assets/playlists_before.png';
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    reviewed = false;
    check();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser.rewatchedMovies.keys.toList().contains(widget.movie.id)) {
        myController.text =
            (currentUser.rewatchedMovies[widget.movie.id]).toString();
      } else if (widget.movie.isSeen()) {
        myController.text = "1";
      } else {
        myController.text = "0";
      }
    });

    DateTime selectedDate = DateTime.now();
    return AppScaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: widget.movie.getExtendedData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            widget.movie.title = snapshot.data!["title"];
            return SingleChildScrollView(
              child: Column(
                children: [
                  getCover(snapshot.data!, context, widget.movie, "movie"),
                  if (snapshot.data!['overview'] != null &&
                      snapshot.data!['overview'] != "")
                    OverviewSection(overview: snapshot.data!['overview']),
                  getGenres(snapshot.data!),
                  getRuntimeRating(snapshot.data!),
                  getStatus(snapshot.data!),
                  if (reviewed &&
                      snapshot.data!.keys.contains("review") &&
                      snapshot.data!["review"] != null)
                    getReview(snapshot.data!),
                  if (!reviewed && widget.movie.isSeen())
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            bool success = await ReviewService.writeReview(
                                snapshot.data!["id"], "Movies", context);
                            if (success) {
                              setState(() {
                                currentUser.reviews = currentUser.reviews;
                              });
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.reviews,
                                color: Colors.white,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                S.of(context)!.writeAReview,
                                style: const TextStyle(color: Colors.white),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  getProviders(snapshot.data!, context),
                  getTimesSeen(snapshot.data!),
                  const SizedBox(height: 10),
                  if (ViewingHistory.hasAnything(
                    seenDates: snapshot.data!['seen_dates'] as List,
                    seen: widget.movie.isSeen(),
                    hasProgress: ViewingHistory.hasProgressEntry(
                        currentUser.progress,
                        progressMoviesKey,
                        widget.movie.id),
                  ))
                    getViewingHistory(snapshot.data!, selectedDate),
                  getCastandCrew(snapshot.data!),
                  getTrailer(snapshot.data!),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(S.of(context)!.errorFailedToLoadDetails),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      selectedIndex: -1,
    );
  }

  Widget getStatus(Map data) {
    return MediaStatusIconsRow(
      seenImage: _imageProviderSeen,
      watchlistImage: _imageProviderWatchlist,
      favImage: _imageProviderFav,
      listImage: _imageProviderList,
      onIconTap: (type) async {
        await _onTap(type, data["id"].toString(), data["title"],
            data["runtime"], double.parse(data["imdb_rating"]));
        if (!mounted) return;
        setState(() {
          _progressToken++;
        });
      },
      trailing: MediaProgressControl(
        id: data["id"].toString(),
        type: progressMoviesKey,
        refreshToken: _progressToken,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget getReview(Map data) {
    return MediaReviewSection(
      data: data,
      reviewMediaType: "Movies",
      opinionText: S.of(context)!.opinion(data["review"]["Opinion"]),
      ratingText: S.of(context)!.rating(data["review"]["Rating"]),
      onChanged: () {
        setState(() {});
      },
    );
  }

  Widget watchlistsModal(String id) {
    return PlaylistPickerModal(
      id: id,
      playlistMediaKey: "Movies",
      serviceMediaType: "Movies",
    );
  }

  Widget getTimesSeen(Map data) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: myController,
        decoration: const InputDecoration(
          labelText: "Times seen",
          hintStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          labelStyle: TextStyle(color: Colors.grey),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          WatchedService.incrementWatched(currentUser.uid, value.toString(),
              data["id"].toString(), "movie");
        },
      ),
    );
  }

  Widget getViewingHistory(Map data, DateTime selectedDate) {
    return ExpansionTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history),
          SizedBox(width: 8),
          Text(
            S.of(context)!.viewingHistory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              wordSpacing: 2,
              height: 1.5,
            ),
          ),
        ],
      ),
      subtitle: ViewingHistoryRangeLabel(
        type: progressMoviesKey,
        id: widget.movie.id,
        seenDates: data['seen_dates'] as List,
        seen: widget.movie.isSeen(),
        refreshToken: _progressToken,
      ),
      children: [
        if ((data['seen_dates'] as List).isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (data['seen_dates'] as List).map<Widget>((date) {
                List friendsWhoWatched = date[1] ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        intl.DateFormat('dd MMMM, yyyy')
                            .format(DateTime.parse(date[0])),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Expanded(
                        child: WatchedFriendsStack(
                          friendsWhoWatched: friendsWhoWatched,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AddToCalendar(
                                  media: widget.movie,
                                  dateForMap: date[0],
                                  modifying: true,
                                  friends: friendsWhoWatched,
                                  type: "movie");
                            },
                          );
                          if (result != null) {
                            setState(() {});
                          }
                        },
                        child: const Icon(Icons.edit),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await CalendarService.deleteFromCalendar(
                              currentUser.uid,
                              widget.movie.id,
                              widget.movie.title,
                              date[0],
                              context);

                          setState(() {
                            List movies = currentUser.calendar[date[0]];
                            movies.removeWhere((element) =>
                                element["id"] == widget.movie.id &&
                                element["type"] == "movie");
                            currentUser.calendar[date[0]] = movies;
                            if (currentUser.rewatchedMovies.keys
                                .toList()
                                .contains(widget.movie.id)) {
                              currentUser.rewatchedMovies[widget.movie.id] - 1 >
                                      0
                                  ? currentUser
                                      .rewatchedMovies[widget.movie.id] -= 1
                                  : 0;
                              WatchedService.setRewatched(
                                  currentUser.uid,
                                  widget.movie.id,
                                  currentUser.rewatchedMovies[widget.movie.id],
                                  "movie");
                            }
                          });
                        },
                        child: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        if ((data['seen_dates'] as List).isNotEmpty) const SizedBox(height: 15),
        if ((data['seen_dates'] as List).isEmpty)
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              S.of(context)!.noViewingHistory,
              style: TextStyle(
                  fontSize: 16, fontStyle: FontStyle.italic, color: Colors.red),
            ),
          ),
        if (currentUser.seenWith.entries
            .where((entry) =>
                entry.value["Movies"]?.contains(widget.movie.id) ?? false)
            .isNotEmpty)
          Text(S.of(context)!.peopleWatchedwith,
              style: TextStyle(
                fontSize: 16,
              )),
        FutureBuilder(
          future: Future.wait(
            currentUser.seenWith.entries
                .where((entry) =>
                    entry.value["Movies"]?.contains(widget.movie.id) ?? false)
                .map((entry) => FirestoreCore.db
                    .collection(entry.key)
                    .doc("Settings")
                    .get()),
          ),
          builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  S.of(context)!.failedFriends,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.red,
                  ),
                ),
              );
            } else if (snapshot.hasData) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 1,
                ),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data![index];
                  var userData = doc.data() as Map<String, dynamic>;
                  var profilePhoto = userData['profile_photo'];
                  var username = userData['username'] ?? 'Unknown';
                  return GestureDetector(
                    onTap: () async {
                      var querySnapshot = await FirestoreCore.db
                          .collection('usernames')
                          .where('username', isEqualTo: username)
                          .limit(1)
                          .get();

                      friendUid = querySnapshot.docs.first.data()['uid'];
                      openDetail(context, FriendProfile(friendUid: friendUid));
                    },
                    child: Container(
                      margin: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProfileAvatar(photoUrl: profilePhoto),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            GestureDetector(
                              onTap: () async {
                                List friendsWatchedWith = [];
                                currentUser.seenWith.entries
                                    .where((entry) => entry.value["Movies"]
                                        ?.contains(widget.movie.id))
                                    .forEach((element) {
                                  friendsWatchedWith.add(element.key);
                                });
                                var querySnapshot = await FirebaseFirestore
                                    .instance
                                    .collection('usernames')
                                    .where('username', isEqualTo: username)
                                    .limit(1)
                                    .get();
                                friendUid =
                                    querySnapshot.docs.first.data()['uid'];
                                await widget.movie.removeFriend(
                                    friendUid, friendsWatchedWith);
                                setState(() {
                                  currentUser.seenWith = currentUser.seenWith;
                                });
                              },
                              child: const Icon(
                                Icons.remove,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            } else {
              return const SizedBox();
            }
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AddFriendsPopUp(
                      movie: widget.movie,
                    );
                  },
                ).then((_) {
                  setState(() {});
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                width: 145,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      S.of(context)!.addFriends,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            GestureDetector(
              onTap: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                  builder: (BuildContext context, Widget? child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme:
                            const ColorScheme.dark(primary: Colors.lightBlue),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null) {
                  selectedDate = pickedDate;
                  if (currentUser.friends.isNotEmpty) {
                    final result = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AddToCalendar(
                          media: widget.movie,
                          dateForMap:
                              selectedDate.toIso8601String().split("T")[0],
                          modifying: false,
                          friends: const [],
                          type: "movie",
                        );
                      },
                    );
                    if (result != null) {
                      setState(() {});
                    }
                  }
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                width: 145,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      S.of(context)!.addDate,
                      style: TextStyle(
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
        const SizedBox(
          height: 10,
        ),
      ],
    );
  }

  Widget getCastandCrew(Map data) {
    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.fromLTRB(30.0, 20.0, 0.0, 5.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CastCrew(
                    data: {"cast": data['cast'], "crew": data['crew']},
                  ),
                ),
              );
            },
            child: Text(
              "${S.of(context)!.labelCastAndCrew}: (${S.of(context)!.simpleSeeAll})",
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.25,
          margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data['cast'].length < 10 ? data['cast'].length : 10,
            itemBuilder: (BuildContext context, int index) {
              Map person = data['cast'][index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(5.0, 0.0, 5.0, 0.0),
                child: GestureDetector(
                  onTap: () {
                    Person personResult = Person(
                        id: person["id"].toString(),
                        name: person["name"].toString(),
                        data: person);

                    openDetail(
                        context,
                        PersonResult(
                          personResult: personResult,
                        ));
                  },
                  child: Column(
                    children: <Widget>[
                      getItemContainer(context, person, "person"),
                      const SizedBox(height: 10),
                      Text(
                        '${person["name"]}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${S.of(context)!.as} ${person["character"]}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 1,
          height: 50,
          margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
          child: Builder(
            builder: (BuildContext context) {
              final Map? director = ApiUtils.findCrewMember(
                  data['crew'],
                  (job) =>
                      job.split('/').any((role) => role.trim() == "Director"));
              final Map? writer = ApiUtils.findCrewMember(
                  data['crew'],
                  (job) =>
                      job.contains('Writer') || job.contains('Screenplay'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (director != null)
                    _buildCrewCredit(context, director,
                        S.of(context)!.directedBy(director['name'])),
                  if (writer != null)
                    _buildCrewCredit(
                      context,
                      writer,
                      "${(writer['job'] as String?)?.contains("Writer") == true ? S.of(context)!.written : S.of(context)!.screenplay} ${S.of(context)!.by} ${writer['name']}",
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds a tappable credit line linking to the crew member's page.
  static Widget _buildCrewCredit(
      BuildContext context, Map person, String label) {
    return GestureDetector(
      onTap: () {
        Person personResult = Person(
            id: person["id"].toString(),
            name: person["name"].toString(),
            data: person);

        openDetail(
            context,
            PersonResult(
              personResult: personResult,
            ));
      },
      child: Text(
        label,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}
