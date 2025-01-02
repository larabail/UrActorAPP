// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:convert';
import 'dart:io';

import 'package:uractor/common/item_container.dart';
import 'package:uractor/notifications.dart';
import 'package:uractor/objects/Playlist.dart';
import 'package:uractor/objects/User.dart';
import 'package:uractor/tvshow_result.dart';

import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'calendar.dart';
import 'favorites.dart';
import 'list_result.dart';
import 'login.dart';
import 'movie_result.dart';
import 'objects/Media.dart';
import 'objects/Movie.dart';
import 'objects/TVShow.dart';
import 'playlists.dart';
import 'reviews.dart';
import 'seen.dart';
import 'watchlist.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

List idsExplorePage = [];
bool gotData = false;
Map oscars = {};
late AppUser currentUser;

String reviewId = "";
String reviewType = "";
Map reviewInfo = {};

bool reviewed = false;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UrActor',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color.fromARGB(250, 224, 190, 78),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF121212),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all<Color>(
              const Color.fromARGB(248, 241, 105, 56)),
          trackColor: WidgetStateProperty.all<Color>(
              const Color.fromARGB(250, 224, 190, 78)),
        ),
        indicatorColor: const Color.fromARGB(250, 224, 190, 78),
        tabBarTheme: const TabBarTheme(
          labelColor: Color.fromARGB(250, 224, 190, 78),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color.fromARGB(250, 224, 190, 78),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color.fromARGB(250, 224, 190, 78),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color.fromARGB(250, 224, 190, 78),
          backgroundColor: Color(0xFF121212),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[900],
            textStyle: const TextStyle(color: Colors.white),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color.fromARGB(250, 224, 190, 78);
            }
            return const Color.fromARGB(0, 158, 158, 158);
          }),
          checkColor: WidgetStateProperty.all<Color>(Colors.white),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> _refreshMain() async {
    User? user = FirebaseAuth.instance.currentUser;
    currentUser = AppUser(uid: user!.uid);
    await currentUser.getFirebaseData();
    setState(() {
      gotData = true;
    });
  }

  Future<void> loadPage() async {
    HttpClient client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    await currentUser.getFirebaseData();
    setState(() {
      gotData = true;
    });
    try {
      var request = await client.getUrl(Uri.parse('https://example.com'));
      var response = await request.close();

      response.transform(const Utf8Decoder()).listen((data) {
        print(data);
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      currentUser = AppUser(uid: "");
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
        );
      });
    } else {
      currentUser = AppUser(uid: user.uid);
      loadPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;
    if (gotData) {
      return Scaffold(
        appBar: const CustomAppBar(),
        body: RefreshIndicator(
          onRefresh: _refreshMain,
          child: SingleChildScrollView(
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Calendar()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(5.0),
                      padding: const EdgeInsets.all(10),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_month),
                          SizedBox(width: 10),
                          Text(
                            'Your Calendar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Notifications()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(5.0),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Icon(
                                currentUser.notifications.values
                                        .where((element) =>
                                            element["read"] == false)
                                        .isNotEmpty
                                    ? Icons.notifications
                                    : Icons.notifications_none,
                              ),
                              if (currentUser.notifications.values
                                  .where((element) => element["read"] == false)
                                  .isNotEmpty)
                                Positioned(
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 12,
                                      minHeight: 12,
                                    ),
                                    child: Text(
                                      '${currentUser.notifications.values.where((element) => element["read"] == false).length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Notifications',
                            style: TextStyle(
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
              buildPlaylistsSection(),
              buildMainPageContainer(
                  "Watchlist",
                  currentUser.watchlistTVShows + currentUser.watchlist,
                  Icons.bookmark,
                  Watchlist()),
              buildMainPageContainer(
                  "Favorites",
                  currentUser.favTVShows + currentUser.favMovies,
                  Icons.favorite,
                  Favorites()),
              buildMainPageContainer(
                  "Seen",
                  currentUser.seenTVShows + currentUser.seenMovies,
                  Icons.remove_red_eye,
                  Seen()),
              Container(
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
                        const Icon(Icons.reviews),
                        const SizedBox(width: 10),
                        const Text(
                          'Your Reviews',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Reviews()),
                            );
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Text(
                                'See All (${currentUser.allReviews.length} items)',
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
                    if (currentUser.allReviews.isEmpty)
                      const Text("Haven't reviewed any movies yet"),
                    if (currentUser.allReviews.isEmpty)
                      const SizedBox(height: 10),
                    if (currentUser.allReviews.isNotEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.22,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: currentUser.allReviews.length > 10
                              ? 10
                              : currentUser.allReviews.length,
                          itemBuilder: (context, index) {
                            final review = currentUser.allReviews[index][2];
                            final type = currentUser.allReviews[index][0];
                            MediaItem tempMedia;
                            if (type == "Movies") {
                              tempMedia = Movie(
                                  id: currentUser.allReviews[index][1],
                                  title: "title",
                                  coverPhoto: "coverPhoto");
                            } else {
                              tempMedia = TVShow(
                                  id: currentUser.allReviews[index][1],
                                  title: "title",
                                  coverPhoto: "coverPhoto");
                            }
                            return FutureBuilder<Map>(
                              future: tempMedia.getData(),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map> snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => type ==
                                                    "Movies"
                                                ? MovieResult(
                                                    movie: tempMedia as Movie)
                                                : TVShowResult(
                                                    tvshow:
                                                        tempMedia as TVShow)),
                                      );
                                    },
                                    child: Column(children: [
                                      getItemContainer(context, snapshot.data, type),
                                      Text(
                                        '${review["Rating"]}/10',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          wordSpacing: 2,
                                          height: 1.5,
                                        ),
                                      ),
                                    ]),
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
                                              0.125,
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
              ),
            ]),
          ),
        ),
        bottomNavigationBar: CommonBottomAppBar(selectedIndex),
      );
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo_character.png', height: 100),
              const SizedBox(height: 20),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget buildPlaylistsSection() {
    List filteredKeys = currentUser.playlists.keys
        .where((key) => key != "recommendations")
        .toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      padding: const EdgeInsets.all(10),
      itemCount: filteredKeys.length < 6 ? filteredKeys.length : 6,
      itemBuilder: (context, index) {
        String key = filteredKeys[index];
        dynamic value = currentUser.playlists[key]['Name'];
        dynamic image = currentUser.playlists[key]['CoverPhoto'];
        dynamic movies = currentUser.playlists[key]['Movies'];
        dynamic tvshows = currentUser.playlists[key]['TV Shows'];
        dynamic accessCode = currentUser.playlists[key]['AccessCode'];

        int totalContent = (movies?.length ?? 0) + (tvshows?.length ?? 0);

        // "See All" button logic
        if (index == 5 && currentUser.playlists.length > 6) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Playlists()),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.library_books,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text(
                        'See All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${currentUser.playlists.length} playlists',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            Playlist listResult = Playlist(
              id: key.toString(),
              name: value.toString(),
              backdrop: image.toString(),
              movies: movies,
              tvshows: tvshows,
              accesscode: accessCode.toString(),
              users: currentUser.playlists[key]["Users"],
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListResult(
                  list_result: listResult,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final text = TextSpan(
                                    text: value,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                  final textPainter = TextPainter(
                                    text: text,
                                    textDirection: TextDirection.ltr,
                                    maxLines: 1,
                                  )..layout(maxWidth: constraints.maxWidth);

                                  if (textPainter.didExceedMaxLines) {
                                    return SizedBox(
                                      height: 20,
                                      child: Marquee(
                                        text: value,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        scrollAxis: Axis.horizontal,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        blankSpace: 20.0,
                                        velocity: 25.0,
                                        pauseAfterRound:
                                            const Duration(seconds: 1),
                                        startPadding: 0.0,
                                        accelerationDuration:
                                            const Duration(seconds: 1),
                                        accelerationCurve: Curves.linear,
                                        decelerationDuration:
                                            const Duration(milliseconds: 500),
                                        decelerationCurve: Curves.easeOut,
                                      ),
                                    );
                                  } else {
                                    return Text(
                                      value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                },
                              ),
                              Text(
                                '$totalContent items',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                'Your $title',
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
                      'See All (${content.length} items)',
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
          if (content.isEmpty) const Text("Nothing here yet"),
          if (content.isEmpty) const SizedBox(height: 10),
          if (content.isNotEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.18,
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
                          child: getItemContainer(context, snapshot.data, "media")
                        );
                      } else if (snapshot.hasError) {
                        return const Center(
                            child: Text("Failed to load movie details"));
                      } else {
                        return Container(
                          margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                          width: MediaQuery.of(context).size.width * 0.28,
                          height: MediaQuery.of(context).size.height * 0.18,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
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
