// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/cast_and_crew.dart';
import 'package:uractor/common/firebase/calendar_service.dart';
import 'package:uractor/common/firebase/favorites_service.dart';
import 'package:uractor/common/firebase/playlist_service.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/common/firebase/watched_service.dart';
import 'package:uractor/common/firebase/watchlist_service.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/mediaitembuilder.dart';
import 'package:uractor/season_guide.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'common/utils.dart';
import 'package:uractor/common/firebase/firebaseutils.dart';
import 'friends.dart';
import 'friends_profile.dart';
import 'package:intl/intl.dart' as intl;
import 'main.dart';
import 'objects/Person.dart';
import 'objects/TVShow.dart';
import 'person_result.dart';

import 'popups/add_to_calendar_pop_up.dart';

String _imageProviderSeen = 'assets/seen_before.png';
String _imageProviderWatchlist = 'assets/watchlist_before.png';
String _imageProviderList = 'assets/playlists_before.png';
String _imageProviderFav = 'assets/fav_before.png';
bool _isTappedSeen = false;
bool _isTappedWatchlist = false;
bool _isTappedFav = false;
bool _isTappedList = false;

class TVShowResult extends StatefulWidget {
  final TVShow tvshow;
  const TVShowResult({Key? key, required this.tvshow}) : super(key: key);

  @override
  _TVShowResultState createState() => _TVShowResultState();
}

class _TVShowResultState extends State<TVShowResult> {
  final myController = TextEditingController(text: "");
  bool isExpanded = false;

  void check() {
    if (widget.tvshow.isSeen()) {
      _isTappedSeen = true;
      _imageProviderSeen = 'assets/seen_after.png';
    } else {
      _isTappedSeen = false;
      _imageProviderSeen = 'assets/seen_before.png';
    }
    if (widget.tvshow.isBookmarked()) {
      _isTappedWatchlist = true;
      _imageProviderWatchlist = 'assets/watchlist_after.png';
    } else {
      _isTappedWatchlist = false;
      _imageProviderWatchlist = 'assets/watchlist_before.png';
    }
    if (widget.tvshow.isFavorite()) {
      _isTappedFav = true;
      _imageProviderFav = 'assets/fav_after.png';
    } else {
      _isTappedFav = false;
      _imageProviderFav = 'assets/fav_before.png';
    }
    if (currentUser.tvShowReviews.keys.toList().contains(widget.tvshow.id)) {
      reviewed = true;
    }
  }

  Future<void> onTap(
      String type, String id, String title, int runtime, double rating) async {
    bool success = false;
    switch (type) {
      case 'seen':
        _isTappedSeen = !_isTappedSeen;
        if (_isTappedSeen) {
          success = await WatchedService.markWatched(
              id, title, runtime, rating, context, "TVShows");
        } else {
          success = await WatchedService.deleteFromWatchedConfirmation(
              id, context, "TVShows");
        }
        break;
      case 'watchlist':
        _isTappedWatchlist = !_isTappedWatchlist;
        if (_isTappedWatchlist) {
          success = await WatchlistService.bookmark(id, context, "TVShows");
        } else {
          success = await WatchlistService.unbookmark(id, context, "TVShows");
        }
        break;
      case 'fav':
        _isTappedFav = !_isTappedFav;
        if (_isTappedFav) {
          success = await FavoritesService.favorite(id, context, "TVShows");
        } else {
          success = await FavoritesService.unfavorite(id, context, "TVShows");
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
          ).then(
            (value) => {
              setState(() {
                _imageProviderList = 'assets/playlists_before.png';
                _isTappedList = !_isTappedList;
              })
            },
          );
        } else {
          _imageProviderList = 'assets/playlists_before.png';
        }
        break;
      default:
        break;
    }
    if (success) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    reviewed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUser.rewatchedTVShows.keys
          .toList()
          .contains(widget.tvshow.id)) {
        myController.text =
            (currentUser.rewatchedTVShows[widget.tvshow.id]).toString();
      } else if (widget.tvshow.isSeen()) {
        myController.text = "1";
      } else {
        myController.text = "0";
      }
    });
    check();

    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: widget.tvshow.getExtendedData(),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  getCover(snapshot.data!, context, widget.tvshow, "tvshow"),
                  if (snapshot.data!['overview'] != null &&
                      snapshot.data!['overview'] != "")
                    getOverview(snapshot.data!),
                  getGenres(snapshot.data!),
                  getSeasonsAndRating(snapshot.data!),
                  getStatus(snapshot.data!),
                  if (reviewed &&
                      snapshot.data!.keys.contains("review") &&
                      snapshot.data!["review"] != null)
                    getReview(snapshot.data!),
                  if (!reviewed && widget.tvshow.isSeen())
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            bool success = await ReviewService.writeReview(
                                snapshot.data!["id"], "TVShows", context);
                            if (success) {
                              setState(() {});
                            }
                          },
                          child: const Row(
                            children: [
                              Icon(
                                Icons.reviews,
                                color: Colors.white,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Write A Review',
                                style: TextStyle(color: Colors.white),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  getProviders(snapshot.data!),
                  getTimesSeen(snapshot.data!),
                  const SizedBox(height: 10),
                  if (Utils.contains_non_type(
                      currentUser.seenTVShows, ['TVShows', widget.tvshow.id]))
                    getViewingHistory(snapshot.data!),
                  getCastandCrew(snapshot.data!),
                  getTrailer(snapshot.data!),
                ],
              ),
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
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }

  Widget getOverview(data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            constraints: BoxConstraints(
              maxHeight: isExpanded ? double.infinity : 85,
            ),
            child: Text(
              data['overview'],
              textAlign: TextAlign.justify,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                fontSize: 15,
                wordSpacing: 2,
                height: 1.5,
              ),
            ),
          ),
          if (!isExpanded && data['overview'].length > 100)
            InkWell(
              onTap: () {
                setState(() {
                  isExpanded = true;
                });
              },
              child: const SizedBox(
                width: double.infinity,
                child: Text(
                  "Read All",
                  textAlign: TextAlign.right,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget getSeasonsAndRating(data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 30,
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[900],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, color: Colors.white),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeasonGuide(
                        tvShowData: data,
                        show: widget.tvshow,
                      ),
                    ),
                  );
                },
                child: Text(
                  data['number_of_seasons'] > 0
                      ? data['number_of_seasons'] > 1
                          ? '${data['number_of_seasons']} seasons →'
                          : '${data['number_of_seasons']} season →'
                      : '${data['number_of_seasons']} season →',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 30,
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 0.0),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[900],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                'IMDB: ${data["imdb_rating"]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget getStatus(data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => onTap('seen', data["id"].toString(), data["name"], 0, 0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
            child: Image.asset(
              _imageProviderSeen,
              height: 40,
            ),
          ),
        ),
        GestureDetector(
          onTap: () =>
              onTap('watchlist', data["id"].toString(), data["name"], 0, 0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
            child: Image.asset(
              _imageProviderWatchlist,
              height: 40,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onTap('fav', data["id"].toString(), data["name"], 0, 0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
            child: Image.asset(
              _imageProviderFav,
              height: 40,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onTap('list', data["id"].toString(), data["name"], 0, 0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(0.0, 10.0, 10.0, 10.0),
            child: Image.asset(
              _imageProviderList,
              height: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget getReview(data) {
    return ExpansionTile(
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reviews),
          SizedBox(width: 8),
          Text(
            "Your Review",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              wordSpacing: 2,
              height: 1.5,
            ),
          ),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Align(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 26, 25, 25),
                borderRadius: BorderRadius.circular(27),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Text(
                    'Opinion: ${data["review"]["Opinion"]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      wordSpacing: 2,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'Rating: ${data["review"]["Rating"]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      wordSpacing: 2,
                      height: 1.5,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          bool success = await ReviewService.editReview(
                              data["id"], "TVShows", context);
                          if (success) {
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 10),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () async {
                          bool success = await ReviewService.deleteReview(
                              data["id"], "TVShows", context);
                          if (success) {
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget getTimesSeen(data) {
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
              data["id"].toString(), "series");
        },
      ),
    );
  }

  Widget getViewingHistory(data) {
    return ExpansionTile(
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history),
          SizedBox(width: 8),
          Text(
            "Viewing History",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              wordSpacing: 2,
              height: 1.5,
            ),
          ),
        ],
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
                        child: FutureBuilder<List<String>>(
                          future:
                              FirebaseUtils.getProfilePhotos(friendsWhoWatched),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 32.0,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            } else if (snapshot.hasError) {
                              return const SizedBox(
                                height: 32.0,
                                child:
                                    Center(child: Text('Error loading images')),
                              );
                            } else if (snapshot.hasData) {
                              var images = snapshot.data!;
                              return SizedBox(
                                height: 32.0,
                                child: Stack(
                                  children:
                                      List.generate(images.length, (index) {
                                    double offset = index * 10.0;
                                    return Positioned(
                                      left: offset,
                                      child: ClipOval(
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
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AddToCalendar(
                                  media: widget.tvshow,
                                  dateForMap: date[0],
                                  modifying: true,
                                  friends: friendsWhoWatched,
                                  type: "series");
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
                              widget.tvshow.id,
                              widget.tvshow.title,
                              date[0],
                              context);

                          setState(() {
                            List movies = currentUser.calendar[date[0]];
                            movies.removeWhere((element) =>
                                element["id"] == widget.tvshow.id &&
                                element["type"] == "series");
                            currentUser.calendar[date[0]] = movies;
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
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "No viewing history available.",
              style: TextStyle(
                  fontSize: 16, fontStyle: FontStyle.italic, color: Colors.red),
            ),
          ),
        if (currentUser.seenWith.entries
            .where((entry) =>
                entry.value["Movies"]?.contains(widget.tvshow.id) ?? false)
            .isNotEmpty)
          const Text("People watched with",
              style: TextStyle(
                fontSize: 16,
              )),
        FutureBuilder(
          future: Future.wait(
            currentUser.seenWith.entries
                .where((entry) =>
                    entry.value["TVShows"]
                        ?.contains(widget.tvshow.id.toString()) ??
                    false)
                .map((entry) => FirebaseFirestore.instance
                    .collection(entry.key)
                    .doc("Settings")
                    .get()),
          ),
          builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "Failed to load friends' profiles.",
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
                        var querySnapshot = await FirebaseFirestore.instance
                            .collection('usernames')
                            .where('username', isEqualTo: username)
                            .limit(1)
                            .get();

                        friendUid = querySnapshot.docs.first.data()['uid'];

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FriendProfile(friendUid: friendUid),
                          ),
                        );
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
                              ClipOval(
                                child: profilePhoto != ""
                                    ? Image.network(
                                        profilePhoto,
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
                                          ?.contains(widget.tvshow.id))
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
                                  await widget.tvshow.removeFriend(
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
                      ));
                },
              );
            } else {
              return const SizedBox();
            }
          },
        ),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                Map<String, bool> selectedFriends = {};
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      title: const Text('Add Friends Who Watched'),
                      content: SizedBox(
                        height: 250,
                        child: SingleChildScrollView(
                          child: Column(
                            children: List.generate(
                              currentUser.friends.length,
                              (friendIndex) {
                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection(
                                          currentUser.friends[friendIndex])
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
                                      var data = snapshot.data!.data()
                                          as Map<String, dynamic>;
                                      String userName = data['username'] ?? '';
                                      String profilePath =
                                          data['profile_photo'] ?? '';
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
                                                    fontSize: 16.0),
                                              ),
                                            ),
                                          ],
                                        ),
                                        value: selectedFriends.keys
                                                .toList()
                                                .contains(currentUser
                                                    .friends[friendIndex])
                                            ? selectedFriends[currentUser
                                                .friends[friendIndex]]
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
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Apply'),
                          onPressed: () async {
                            String id = widget.tvshow.id.toString();
                            FirebaseFirestore firestore =
                                FirebaseFirestore.instance;
                            for (String friend
                                in selectedFriends.keys.toList()) {
                              var userDoc = FirebaseFirestore.instance
                                  .collection(friend)
                                  .doc("TVShows");
                              await userDoc.update({
                                'Seen': FieldValue.arrayUnion([id])
                              });
                              userDoc = FirebaseFirestore.instance
                                  .collection(friend)
                                  .doc("Seen");
                              await userDoc.update({
                                'TVShows': FieldValue.arrayUnion([id])
                              });
                              if (currentUser.seenWith.containsKey(friend) &&
                                  !currentUser.seenWith[friend]["TVShows"]
                                      .contains(id.toString())) {
                                currentUser.seenWith[friend]["TVShows"]
                                    .add(id.toString());
                              } else if (!currentUser.seenWith
                                  .containsKey(friend)) {
                                currentUser.seenWith[friend] = {
                                  "Movies": [],
                                  "TVShows": []
                                };
                                currentUser.seenWith[friend]["TVShows"]
                                    .add(id.toString());
                              }
                              DocumentReference userDoc2 =
                                  firestore.collection(friend).doc("SeenWith");
                              Map<String, dynamic> item = {};
                              List<dynamic> watchedWithList = [currentUser.uid];
                              item[id] = watchedWithList;
                              await firestore
                                  .runTransaction((transaction) async {
                                DocumentSnapshot snapshot =
                                    await transaction.get(userDoc2);

                                if (!snapshot.exists) {
                                  throw Exception("Document does not exist!");
                                }

                                Map<String, dynamic> data =
                                    snapshot.data() as Map<String, dynamic>;

                                if (data.containsKey('TVShows') &&
                                    data['TVShows'] is Map<String, dynamic>) {
                                  Map<String, dynamic> moviesMap =
                                      data['TVShows'];

                                  if (moviesMap.containsKey(id)) {
                                    List existingList =
                                        moviesMap[id]["friends"];
                                    for (String person in watchedWithList) {
                                      if (!existingList.contains(person)) {
                                        existingList.add(person);
                                      }
                                    }
                                    moviesMap[id] = {"friends": existingList};
                                    transaction.update(
                                        userDoc2, {"TVShows": moviesMap});
                                  } else {
                                    moviesMap[id] = {
                                      "friends": watchedWithList
                                    };
                                    transaction.update(
                                        userDoc2, {"TVShows": moviesMap});
                                  }
                                } else {
                                  transaction.set(
                                      userDoc2,
                                      {
                                        'TVShows': {
                                          id: {"friends": watchedWithList}
                                        }
                                      },
                                      SetOptions(merge: true));
                                }
                              }).catchError((error) {
                                print("Failed to update document: $error");
                              });
                            }
                            DocumentReference userDoc2 = firestore
                                .collection(currentUser.uid)
                                .doc("SeenWith");

                            Map<String, dynamic> item = {};
                            List<dynamic> watchedWithList = selectedFriends.keys
                                .where((key) => selectedFriends[key] == true)
                                .toList();
                            item[id] = watchedWithList;
                            firestore.runTransaction((transaction) async {
                              DocumentSnapshot snapshot =
                                  await transaction.get(userDoc2);

                              if (!snapshot.exists) {
                                throw Exception("Document does not exist!");
                              }

                              Map<String, dynamic> data =
                                  snapshot.data() as Map<String, dynamic>;

                              if (data.containsKey('TVShows') &&
                                  data['TVShows'] is Map<String, dynamic>) {
                                Map<String, dynamic> moviesMap =
                                    data['TVShows'];

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
                                transaction
                                    .update(userDoc2, {'TVShows': moviesMap});
                              } else {
                                transaction.set(
                                    userDoc2,
                                    {
                                      'TVShows': {
                                        id: {"friends": watchedWithList}
                                      }
                                    },
                                    SetOptions(merge: true));
                              }
                            }).catchError((error) {
                              print("Failed to update document: $error");
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ).then((_) {
              setState(() {});
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: 145,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add, color: Colors.green),
                SizedBox(width: 10),
                Text(
                  'Add Friends',
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
          height: 10,
        ),
      ],
    );
  }

  Widget getCastandCrew(data) {
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
            child: const Text(
              "Cast and Crew: (See All)",
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

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PersonResult(
                                personResult: personResult,
                              )),
                    );
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
                        'as ${person["character"]}',
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
          height: data['created_by'].length * 25.0,
          margin: const EdgeInsets.fromLTRB(30.0, 5.0, 0, 5.0),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                data['created_by'].length < 5 ? data['created_by'].length : 5,
            itemBuilder: (BuildContext context, int index) {
              var creator = data['created_by'][index]["name"];
              if (creator != null) {
                return GestureDetector(
                    onTap: () {
                      Person personResult = Person(
                          id: data['created_by'][index]["id"].toString(),
                          name: data['created_by'][index]["name"].toString(),
                          data: data['created_by'][index]);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PersonResult(
                                  personResult: personResult,
                                )),
                      );
                    },
                    child: Text(
                      "Created by ${data['created_by'][index]['name']}",
                      style: const TextStyle(fontSize: 15),
                    ));
              }
              return Container();
            },
          ),
        ),
      ],
    );
  }

  Widget watchlistsModal(String id) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: (currentUser.playlists.length / 2).ceil(),
        itemBuilder: (context, index) {
          final leftMovieIndex = index * 2;
          final rightMovieIndex = index * 2 + 1;
          final keyLeft = (leftMovieIndex < currentUser.playlists.length)
              ? currentUser.playlists.keys.elementAt(leftMovieIndex)
              : null;
          final keyRight = (rightMovieIndex < currentUser.playlists.length)
              ? currentUser.playlists.keys.elementAt(rightMovieIndex)
              : null;
          dynamic valueLeft,
              imageLeft,
              moviesLeft,
              valueRight,
              imageRight,
              moviesRight;
          if (keyLeft != null) {
            valueLeft = currentUser.playlists[keyLeft]['Name'];
            imageLeft = currentUser.playlists[keyLeft]['CoverPhoto'];
            moviesLeft = currentUser.playlists[keyLeft]['TV Shows'];
          }
          if (keyRight != null) {
            valueRight = currentUser.playlists[keyRight]['Name'];
            imageRight = currentUser.playlists[keyRight]['CoverPhoto'];
            moviesRight = currentUser.playlists[keyRight]['TV Shows'];
          }
          return Row(
            children: [
              if (keyLeft != null)
                GestureDetector(
                  onTap: () {
                    PlaylistService.updateList(id, keyLeft, moviesLeft, context,
                        "TVShows", !moviesLeft.contains(id));
                  },
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: MediaQuery.of(context).size.height * 0.18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(imageLeft),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(27),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(1),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: MediaQuery.of(context).size.height * 0.18,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              valueLeft,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.25,
                                wordSpacing: 1.75,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (moviesLeft.contains(id))
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              if (keyRight != null)
                GestureDetector(
                  onTap: () {
                    PlaylistService.updateList(id, keyRight, moviesRight, context,
                        "TVShows", !moviesRight.contains(id));
                  },
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: MediaQuery.of(context).size.height * 0.18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(imageRight),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(27),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(1),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: MediaQuery.of(context).size.height * 0.18,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              valueRight,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.25,
                                wordSpacing: 1.75,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (moviesRight.contains(id))
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
