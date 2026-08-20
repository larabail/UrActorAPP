// ignore_for_file: use_build_context_synchronously, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names, no_leading_underscores_for_local_identifiers

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/common/firebase/recommendation_service.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/popups/grant_access_dialogue.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'common/utils.dart';
import 'objects/media.dart';
import 'objects/movie.dart';
import 'objects/playlist.dart';
import 'playlists.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'dart:convert';

import 'popups/list_edit_popup.dart';
import 'popups/movie_add_popup.dart';
import 'popups/tv_add_popup.dart';
import 'common/firebase/firestore_core.dart';
import 'common/api/http_client.dart';

class ListInfoDialog extends StatefulWidget {
  final Playlist listResult;
  const ListInfoDialog({super.key, required this.listResult});
  @override
  State<ListInfoDialog> createState() => _ListInfoDialogState();
}

class _ListInfoDialogState extends State<ListInfoDialog> {
  Future<Map<String, dynamic>> getUserData(String uid) async {
    DocumentSnapshot doc =
        await FirestoreCore.db.collection(uid).doc("Settings").get();
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data["uid"] = uid;
    return data;
  }

  Map<String, bool> selectedFriends = {};

  @override
  Widget build(BuildContext context) {
    Map userCurrent = widget.listResult.users.firstWhere(
        (item) => item.containsKey(currentUser.uid) as bool,
        orElse: () => null);
    String role = userCurrent[currentUser.uid];
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.of(context)!.accessCode(widget.listResult.accesscode),
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context)!.usersAccess,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder(
              future: Future.wait((widget.listResult.users)
                  .map((user) => getUserData(user.keys.toList()[0]))),
              builder: (context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(S.of(context)!.noUsersAccess);
                } else {
                  return Column(
                    children: snapshot.data!.map((userData) {
                      return Row(
                        children: [
                          ClipOval(
                            child: userData["profile_photo"] != ""
                                ? Image.network(
                                    userData["profile_photo"],
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/main_profile.png',
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            userData['username'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (role == "Owner")
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () async {
                                Map itemToRemove = widget.listResult.users
                                    .firstWhere(
                                        (item) =>
                                            item.containsKey(userData["uid"])
                                                as bool,
                                        orElse: () => null);
                                FirestoreCore.db
                                    .collection('Watchlists')
                                    .doc(widget.listResult.id)
                                    .update({
                                  'Users':
                                      FieldValue.arrayRemove([itemToRemove])
                                });
                                await FirestoreCore.db
                                    .collection("Watchlists")
                                    .get()
                                    .then((QuerySnapshot querySnapshot) {
                                  for (var doc in querySnapshot.docs) {
                                    Map keysOfDoc = doc.data() as Map;
                                    List users = keysOfDoc['Users'] as List;
                                    for (var element in users) {
                                      Map el = element as Map;
                                      if (el.keys.contains(currentUser.uid)) {
                                        Map docData = doc.data() as Map;
                                        docData["id"] = doc.id;
                                        currentUser.playlists[doc.id] = docData;
                                      }
                                    }
                                  }
                                });
                                setState(() {
                                  widget.listResult.users = currentUser
                                          .playlists[widget.listResult.id]
                                      ["Users"];
                                });
                              },
                            ),
                        ],
                      );
                    }).toList(),
                  );
                }
              },
            ),
            if (role == "Owner")
              ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<Playlist>(
                    context: context,
                    builder: (context) =>
                        GrantAccessDialog(listResult: widget.listResult),
                  );
                  if (result != null) {
                    setState(() {
                      widget.listResult.users = result.users;
                    });
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      S.of(context)!.grantAccess,
                      style: TextStyle(color: Colors.white),
                    )
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (role == "Owner")
                  GestureDetector(
                    onTap: () {
                      cover = widget.listResult.backdrop;
                      originalListName = widget.listResult.name;
                      originalAccessCode = widget.listResult.accesscode;
                      listName = widget.listResult.name;
                      accessCode = widget.listResult.accesscode;
                      showDialog(
                        context: context,
                        builder: (context) => ListEditDialogue(
                          list_result: widget.listResult,
                        ),
                      ).then((_) {
                        Navigator.pop(context);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            S.of(context)!.edit,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () async {
                    if (role == "Owner") {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertButtonDialogue(
                          listResult: widget.listResult,
                        ),
                      );
                    } else {
                      Map itemToRemove = widget.listResult.users.firstWhere(
                          (item) => item.containsKey(currentUser.uid) as bool,
                          orElse: () => null);
                      FirestoreCore.db
                          .collection('Watchlists')
                          .doc(widget.listResult.id)
                          .update({
                        'Users': FieldValue.arrayRemove([itemToRemove])
                      });
                      currentUser.playlists = {};
                      await FirestoreCore.db
                          .collection("Watchlists")
                          .get()
                          .then((QuerySnapshot querySnapshot) {
                        for (var doc in querySnapshot.docs) {
                          Map keysOfDoc = doc.data() as Map;
                          List users = keysOfDoc['Users'] as List;
                          for (var element in users) {
                            Map el = element as Map;
                            if (el.keys.contains(currentUser.uid)) {
                              Map docData = doc.data() as Map;
                              docData["id"] = doc.id;
                              currentUser.playlists[doc.id] = docData;
                            }
                          }
                        }
                      });
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Playlists()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(role == "Owner" ? Icons.delete : Icons.exit_to_app,
                            color: Colors.red),
                        const SizedBox(width: 10),
                        Text(
                          role == "Owner"
                              ? S.of(context)!.delete
                              : S.of(context)!.leave,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
    );
  }
}

class AlertButtonDialogue extends StatelessWidget {
  final Playlist listResult;
  const AlertButtonDialogue({super.key, required this.listResult});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context)!.deleteList),
      content: Text(
        S.of(context)!.deleteListConfirmation,
        style: TextStyle(color: Colors.red),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            // Perform the delete operation here
            currentUser.playlists = {};
            await FirestoreCore.db
                .collection("Watchlists")
                .doc(listResult.id)
                .delete();
            await FirestoreCore.db
                .collection("Watchlists")
                .get()
                .then((QuerySnapshot querySnapshot) {
              for (var doc in querySnapshot.docs) {
                Map keysOfDoc = doc.data() as Map;
                List users = keysOfDoc['Users'] as List;
                for (var element in users) {
                  Map el = element as Map;
                  if (el.keys.contains(currentUser.uid)) {
                    currentUser.playlists[doc.id] = doc.data();
                  }
                }
              }
            });
            Navigator.pop(context);
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const Playlists()));
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.red),
          ),
          child: Text(S.of(context)!.delete),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: Text(S.of(context)!.cancel),
        ),
      ],
    );
  }
}

String cover = "";
String listName = "";
String accessCode = "";
String originalListName = "";
String originalAccessCode = "";

class ListResult extends StatefulWidget {
  final Playlist listResult;
  const ListResult({super.key, required this.listResult});

  @override
  State<ListResult> createState() => _ListResultState();
}

class _ListResultState extends State<ListResult> {
  List<Map<String, dynamic>> moviesList = [];

  Future<Map<String, dynamic>> getData(dynamic id, String type) async {
    return Utils.fetchMediaData(id, type, moviesList);
  }

  // Shipping an OpenAI key inside a client binary is inherently extractable
  // (it can be pulled from the compiled app or intercepted in network traffic);
  // this call should ultimately be proxied through a backend service instead.
  static const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  Future<String> fetchMovieName(String movieId, String type) async {
    final url =
        '${type == "Movies" ? MOVIE_LINK : TV_SHOW_LINK}$movieId$API_KEY';
    final response = await AppHttp.client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return type == "Movies" ? data['title'] : data['name'];
    } else {
      return url;
    }
  }

  Future<List<String>> getMovieNames(List movieIds, String type) async {
    List<String> movieNames = [];
    const int maxConcurrentRequests = 20;
    List<Future<String>> requestBatch = [];
    for (var i = 0; i < movieIds.length; i++) {
      requestBatch.add(fetchMovieName(movieIds[i], type));
      if (requestBatch.length == maxConcurrentRequests ||
          i == movieIds.length - 1) {
        final responses = await Future.wait(requestBatch);
        movieNames.addAll(responses);
        requestBatch.clear();
      }
    }
    return movieNames;
  }

  Future<int?> fetchId(String movieTitle, String type) async {
    movieTitle = movieTitle.split('. ').length > 1
        ? movieTitle.split('. ')[1].trim()
        : movieTitle;

    final url =
        'https://api.themoviedb.org/3/search/${type == "Movies" ? "movie" : "tv"}$API_KEY&query=${Uri.encodeComponent(movieTitle)}';

    final response = await AppHttp.client.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].length > 0) {
        return data['results'][0]['id'];
      } else {
        return null;
      }
    } else {
      throw Exception('Failed to search movie');
    }
  }

  Future<List<int>> getIds(List<String> movieTitles, String type) async {
    List<int> movieIds = [];
    for (var title in movieTitles) {
      int? movieId = await fetchId(title, type);
      if (movieId != null) {
        movieIds.add(movieId);
      }
    }

    return movieIds;
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(S.of(context)!.fetchingRecommendations),
            ],
          ),
        );
      },
    );
  }

  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Regenerates recommendations for [type], keeping the loading dialog and
  /// the failure path together.
  ///
  /// [sendMessage] throws on any non-200 response, so without the `finally`
  /// the dialog is never dismissed and the app looks frozen behind a spinner
  /// that cannot be tapped away. That is reachable in normal use: an expired
  /// OpenAI quota answers 429, not 200.
  Future<void> _regenerateRecommendations(String type) async {
    showLoadingDialog(context);
    var succeeded = false;
    try {
      await sendMessage(type);
      succeeded = true;
    } catch (e) {
      debugPrint('Failed to generate $type recommendations: $e');
    } finally {
      if (mounted) hideLoadingDialog(context);
    }

    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.recommendationsFailed)),
      );
      return;
    }

    setState(() {
      widget.listResult.movies = currentUser.recommendations["Movies"];
      widget.listResult.tvshows = currentUser.recommendations["TVShows"];
    });
  }

  Future<void> sendMessage(String type) async {
    if (_openAiApiKey.isEmpty) {
      // Recommendations are unavailable without a configured OpenAI key;
      // degrade gracefully instead of firing a request that would fail.
      await RecommendationService.updateRecommendations([], type);
      return;
    }
    const apiUrl = 'https://api.openai.com/v1/chat/completions';
    List seenIds = [];
    List seenNames = [];
    String prompt = "";
    if (type == "Movies") {
      seenIds = currentUser.seenMovies.map((m) => m[1].toString()).toList();
      seenNames = await getMovieNames(seenIds, type);
      String moviesList = seenNames.join(", ");
      prompt =
          "Given these movies I've seen: $moviesList, recommend sixty movies I should watch next. Do not recommend any movies I've already seen."
          "Please return the list as a semicolon-separated CSV, like this: title1;title2;title3.";
    } else {
      seenIds = currentUser.seenTVShows.map((m) => m[1].toString()).toList();
      seenNames = await getMovieNames(seenIds, type);
      String moviesList = seenNames.join(", ");
      prompt =
          "Given these tv shows I've seen: $moviesList, recommend sixty tv shows I should watch next. Do not recommend any shows I've already seen."
          "Please return the list as a semicolon-separated CSV, like this: title1;title2;title3.";
    }

    final response = await AppHttp.client.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'max_tokens': 150,
        'temperature': 0.7,
        'messages': [
          {"role": "user", "content": prompt}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List ids = await getIds(
          data['choices'][0]['message']['content'].split(";"), type);
      List unseenRecommendations = type == "Movies"
          ? ids
              .where((id) => !currentUser.seenMovies
                  .map((m) => m[1].toString())
                  .contains(id.toString()))
              .toList()
          : ids
              .where((id) => !currentUser.seenTVShows
                  .map((m) => m[1].toString())
                  .contains(id.toString()))
              .toList();

      if (unseenRecommendations.length >= 30) {
        List finalRecommendations = unseenRecommendations.take(30).toList();
        await RecommendationService.updateRecommendations(
            finalRecommendations, type);
      } else {
        await RecommendationService.updateRecommendations(
            unseenRecommendations, type);
      }
    } else {
      throw Exception(response.body);
    }
  }

  Widget buildMediaItem(
      String mediaId, String mediaType, BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getData(mediaId, mediaType),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
              onTap: () {
                MediaItem tempItem = mediaType == "Movies"
                    ? Movie(
                        id: snapshot.data!['id'].toString(),
                        title: snapshot.data!['title'].toString(),
                        coverPhoto: snapshot.data!['poster_path'] ?? "",
                      )
                    : TVShow(
                        id: snapshot.data!['id'].toString(),
                        title: snapshot.data!['title'].toString(),
                        coverPhoto: snapshot.data!['poster_path'] ?? "",
                      );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => mediaType == "Movies"
                        ? MovieResult(movie: tempItem as Movie)
                        : TVShowResult(tvshow: tempItem as TVShow),
                  ),
                );
              },
              child: getItemContainer(context, snapshot.data, "media"));
        } else if (snapshot.hasError) {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              child:
                  Center(child: Text(S.of(context)!.errorFailedToLoadDetails)));
        } else {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              child: const Center(child: CircularProgressIndicator()));
        }
      },
    );
  }

  Widget buildMediaList(
      List mediaList, String mediaType, BuildContext context) {
    return ListView.builder(
      itemCount: (mediaList.length / 3).ceil(),
      itemBuilder: (context, index) {
        final leftIndex = index * 3;
        final middleIndex = index * 3 + 1;
        final rightIndex = index * 3 + 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (leftIndex < mediaList.length)
              buildMediaItem(
                  mediaList[leftIndex].toString(), mediaType, context),
            if (middleIndex < mediaList.length)
              buildMediaItem(
                  mediaList[middleIndex].toString(), mediaType, context),
            if (rightIndex < mediaList.length)
              buildMediaItem(
                  mediaList[rightIndex].toString(), mediaType, context),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        widget.listResult.backdrop,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 1),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.listResult.name,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          S.of(context)!.listElements(
                              widget.listResult.movies.length.toString(),
                              widget.listResult.tvshows.length.toString()),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (widget.listResult.id != "recommendations")
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => ListInfoDialog(
                                  listResult: widget.listResult,
                                ),
                              ).then((_) {
                                setState(() {});
                              });
                            },
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                          ),
                      ])),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          if (widget.listResult.id == "recommendations")
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _regenerateRecommendations("Movies"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.newMovies,
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
                  onTap: () => _regenerateRecommendations("TVShows"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.newShows,
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
          if (widget.listResult.id != "recommendations")
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return MovieAddDialogue(
                          list_result: widget.listResult,
                        );
                      },
                    ).then((value) => setState(() {}));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.movie, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.addMovie,
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
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return TvAddDialogue(
                          list_result: widget.listResult,
                        );
                      },
                    ).then((value) => setState(() {}));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tv, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          S.of(context)!.addShow,
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
          if (widget.listResult.movies.isNotEmpty &&
              widget.listResult.tvshows.isNotEmpty)
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: S.of(context)!.movies),
                        Tab(text: S.of(context)!.tvShows),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          buildMediaList(
                              widget.listResult.movies, "Movies", context),
                          buildMediaList(
                              widget.listResult.tvshows, "TVShows", context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.listResult.movies.isNotEmpty &&
              widget.listResult.tvshows.isEmpty)
            Expanded(
              child:
                  buildMediaList(widget.listResult.movies, "Movies", context),
            ),
          if (widget.listResult.tvshows.isNotEmpty &&
              widget.listResult.movies.isEmpty)
            Expanded(
              child: buildMediaList(
                  widget.listResult.tvshows, "TVShows", context),
            ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
