// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'calendar.dart';
import 'favorites.dart';
import 'friends.dart';
import 'list_result.dart';
import 'login.dart';
import 'explore.dart';
import 'movie_result.dart';
import 'playlists.dart';
import 'profile.dart';
import 'reviews.dart';
import 'search.dart';
import 'seen.dart';
import 'watchlist.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:http/http.dart' as http;

String uid = '';
String email = '';
String country = '';
bool dontAskCalendar = false;
Map calendar = {};
Map settings = {};
List allMovies = [];
List favActors = [];
List friends = [];
List favDirectors = [];
List favMovies = [];
List favTVShows = [];
List seenMovies = [];
List idsExplorePage = [];
List seenTVShows = [];
List watchlist = [];
List watchlistTVShows = [];
List movieResult = [];
List tvShowResult = [];
Map reviews = {};
Map rewatchedMovies = {};
Map playlists = {};
Map personResult = {};
Map oscars = {};
bool gotData = false;
List<Map<String, dynamic>> favsPage = [];
List<Map<String, dynamic>> favsPageTVShows = [];
List<Map<String, dynamic>> seenPage = [];
List<Map<String, dynamic>> seenPageTVShows = [];
List<Map<String, dynamic>> watchPageTVShows = [];
List<Map<String, dynamic>> watchPage = [];
List<Map<String, dynamic>> oscarsPage = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'UrActor',
            theme: themeProvider.isDarkMode
                ? ThemeData.dark().copyWith(
                    scaffoldBackgroundColor: const Color(0xFF121212),
                    appBarTheme: const AppBarTheme(
                      color: Color(0xFF121212),
                    ),
                    switchTheme: SwitchThemeData(
                      thumbColor: MaterialStateProperty.all<Color>(
                          const Color.fromARGB(248, 241, 105, 56)),
                      trackColor: MaterialStateProperty.all<Color>(
                          const Color.fromARGB(250, 224, 190, 78)),
                    ),
                    indicatorColor: const Color.fromARGB(250, 224, 190, 78),
                    tabBarTheme: const TabBarTheme(
                      labelColor: Color.fromARGB(250, 224, 190, 78),
                      unselectedLabelColor: Colors
                          .grey, // Set your desired color for unselected tabs
                      indicatorColor: Color.fromARGB(250, 224, 190, 78),
                    ),
                    bottomNavigationBarTheme:
                        const BottomNavigationBarThemeData(
                      selectedItemColor: Color.fromARGB(250, 224, 190, 78),
                      backgroundColor: Color(0xFF121212),
                    ),
                  )
                : ThemeData.light().copyWith(
                    appBarTheme: const AppBarTheme(
                      color: Colors.white,
                    ),
                    tabBarTheme: const TabBarTheme(
                      labelColor: Color.fromARGB(255, 150, 127, 52),
                      unselectedLabelColor: Colors
                          .grey, // Set your desired color for unselected tabs
                      indicatorColor: Color.fromARGB(255, 150, 127, 52),
                    ),
                    switchTheme: SwitchThemeData(
                      thumbColor: MaterialStateProperty.all<Color>(
                          const Color.fromARGB(248, 241, 105, 56)),
                      trackColor: MaterialStateProperty.all<Color>(
                          const Color.fromARGB(250, 224, 190, 78)),
                    ),
                    indicatorColor: const Color.fromARGB(255, 150, 127, 52),
                    bottomNavigationBarTheme:
                        const BottomNavigationBarThemeData(
                      selectedItemColor: Color.fromARGB(255, 150, 127, 52),
                    ),
                  ),
            home: const MyHomePage(title: 'Home'),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> getFirebaseData(user) async {
    uid = user.uid;
    email = user.email!;
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Country" && country == "") {
          country = (doc['Country']);
        } else if (doc.id == "Calendar" && calendar.keys.isEmpty) {
          calendar = doc.data() as Map;
        } else if (doc.id == "FavActors" && favActors.isEmpty) {
          Map tempFavActors = doc.data() as Map;
          favActors = tempFavActors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          favActors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "FavDirectors" && favDirectors.isEmpty) {
          Map tempFavDirectors = doc.data() as Map;
          favDirectors = tempFavDirectors.entries
              .map((entry) => [entry.value, entry.key])
              .toList();
          favDirectors.sort((a, b) => b[0].compareTo(a[0]));
        } else if (doc.id == "Favorites" && favMovies.isEmpty) {
          Map allFavs = doc.data() as Map;
          allFavs.forEach((key, el) {
            allFavs[key].forEach((element) {
              if (key == "Movies") {
                favMovies += [
                  [key, element]
                ];
              } else {
                favTVShows += [
                  [key, element]
                ];
              }
            });
          });
        } else if (doc.id == "Movies" && seenMovies.isEmpty) {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              seenMovies += [
                ["Movies", element]
              ];
            });
          });
        } else if (doc.id == "Settings" && settings.keys.toList().isEmpty) {
          settings = doc.data() as Map;
          dontAskCalendar = settings["dontAskCalendar"];
          themeProvider.setDarkMode(settings["darkMode"]);
        } else if (doc.id == "Reviews" && reviews.keys.isEmpty) {
          Map reviewsMap = doc.data() as Map;
          List reviewsList = reviewsMap["Seen"];
          reviewsList.forEach((element) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          });
        } else if (doc.id == "Rewatched" && rewatchedMovies.keys.isEmpty) {
          rewatchedMovies = doc.data() as Map;
        } else if (doc.id == "TVShows" && seenTVShows.isEmpty) {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              seenTVShows += [
                ["TVShows", element]
              ];
            });
          });
        } else if (doc.id == "Watchlist" && watchlist.isEmpty) {
          Map w = doc.data() as Map;
          w.forEach((key, el) {
            w[key].forEach((element) {
              if (key == "Movies") {
                watchlist += [
                  [key, element]
                ];
              } else {
                watchlistTVShows += [
                  [key, element]
                ];
              }
            });
          });
        } else if (doc.id == "Friends" && friends.isEmpty) {
          Map f = doc.data() as Map;
          friends = f["friends"];
        }
      }
    });
    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map keysOfDoc = doc.data() as Map;
        List users = keysOfDoc['Users'] as List;
        for (var element in users) {
          Map el = element as Map;
          if (el.keys.contains(uid)) {
            Map docData = doc.data() as Map;
            docData["id"] = doc.id;
            playlists[doc.id] = docData;
          }
        }
      }
    });
    await FirebaseFirestore.instance
        .collection("Oscars")
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        Map d = doc.data() as Map;
        oscars[d["tmdb_id"]] = doc.data();
      }
    });
    setState(() {
      gotData = true;
    });
  }

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Redirect to login page
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      });
    } else {
      getFirebaseData(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool containsMap(
        List<Map<String, dynamic>> list, Map<String, dynamic> map) {
      String jsonString = json.encode(map);
      for (int i = 0; i < list.length; i++) {
        if (json.encode(list[i]) == jsonString) {
          return true;
        }
      }
      return false;
    }

    final String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
    final String imgLink = 'https://image.tmdb.org/t/p/w500/';
    String link = "https://api.themoviedb.org/3/movie/";
    List<Map<String, dynamic>> movies = [];
    int selectedIndex = 0;

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

    final List<Widget> pages = [
      MyApp(),
      Playlists(),
      Search(),
      Friends(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    if (gotData) {
      return Scaffold(
        appBar: AppBar(
          title: Center(
              child: Image.asset(
            'assets/logo_character.png',
            height: 54,
          )),
        ),
        body: SingleChildScrollView(
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Calendar()),
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
                        Text(
                          'Your Calendar',
                          style: TextStyle(
                            fontSize: 16,
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
                      MaterialPageRoute(builder: (context) => Explore()),
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
                        Icon(Icons.explore),
                        Text(
                          'Explore Movies',
                          style: TextStyle(
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
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              padding: const EdgeInsets.all(10),
              itemCount: playlists.length < 6 ? playlists.length : 6,
              itemBuilder: (context, index) {
                String key = playlists.keys.elementAt(index);
                dynamic value = playlists[key]['Name'];
                dynamic image = playlists[key]['CoverPhoto'];
                dynamic movies = playlists[key]['Movies'];
                dynamic tvshows = playlists[key]['TV Shows'];
                dynamic accessCode = playlists[key]['AccessCode'];

                int totalContent =
                    (movies?.length ?? 0) + (tvshows?.length ?? 0);

                if (index == 5 && playlists.length > 6) {
                  // This is the last item, return the "See All" button
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Playlists()),
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
                          // "See All" Text
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
                                '${playlists.length} playlists',
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
                    list_result["Movies"] = movies;
                    list_result["TVShows"] = tvshows;
                    list_result["Backdrop"] = image;
                    list_result["Name"] = value;
                    list_result["AccessCode"] = accessCode;
                    list_result["id"] = key;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ListResult()),
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
                        // Cover Image
                        Container(
                          height: 20,
                          width: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            image: DecorationImage(
                              image: NetworkImage(image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title and Content Count
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
                                    // Text is too long, use Marquee
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
                                    // Text fits, use Text
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
                );
              },
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
                  Row(
                    children: [
                      const Icon(Icons.bookmark),
                      const SizedBox(width: 10),
                      const Text(
                        'Your Watchlist',
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
                                builder: (context) => Watchlist()),
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              'See All (${watchlist.length + watchlistTVShows.length} items)',
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: watchlist.length > 6 ? 6 : watchlist.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<Map<String, dynamic>>(
                          future: getData(
                              watchlist.reversed.toList()[index][1], 'Movies'),
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
                                        builder: (context) => MovieResult()),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      5.0, 10.0, 10.0, 0),
                                  width:
                                      MediaQuery.of(context).size.width * 0.28,
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
                                  child: Text("Failed to load movie details"));
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        );
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
                  Row(
                    children: [
                      const Icon(Icons.favorite),
                      const SizedBox(width: 10),
                      const Text(
                        'Your Favorites',
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
                                builder: (context) => Favorites()),
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              'See All (${favMovies.length + favTVShows.length} items)',
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: favMovies.length > 6 ? 6 : favMovies.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<Map<String, dynamic>>(
                          future: getData(
                              favMovies.reversed.toList()[index][1], 'Movies'),
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
                                        builder: (context) => MovieResult()),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      5.0, 10.0, 10.0, 0),
                                  width:
                                      MediaQuery.of(context).size.width * 0.28,
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
                                  child: Text("Failed to load movie details"));
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        );
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
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye),
                      const SizedBox(width: 10),
                      const Text(
                        'Your Seen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Seen()),
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              'See All (${seenMovies.length + seenTVShows.length} items)',
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: seenMovies.length > 6 ? 6 : seenMovies.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<Map<String, dynamic>>(
                          future: getData(
                              seenMovies.reversed.toList()[index][1], 'Movies'),
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
                                        builder: (context) => MovieResult()),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      5.0, 10.0, 10.0, 0),
                                  width:
                                      MediaQuery.of(context).size.width * 0.28,
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
                                  child: Text("Failed to load movie details"));
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        );
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
                            MaterialPageRoute(builder: (context) => Reviews()),
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              'See All (${reviews.length} items)',
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: reviews.length > 6 ? 6 : reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[
                            reviews.keys.toList().reversed.toList()[index]];
                        return FutureBuilder<Map<String, dynamic>>(
                          future: getData(
                              reviews.keys.toList().reversed.toList()[index],
                              "Movies"),
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
                                        builder: (context) => MovieResult()),
                                  );
                                },
                                child: Column(children: [
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        5.0, 10.0, 10.0, 0),
                                    width: MediaQuery.of(context).size.width *
                                        0.28,
                                    height: MediaQuery.of(context).size.height *
                                        0.125,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(27),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                            snapshot.data!['poster']),
                                        fit: BoxFit.fitWidth,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Your Rating: ${review["Rating"]}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      wordSpacing: 2,
                                      height: 1.5,
                                    ),
                                  ),
                                ]),
                              );
                            } else if (snapshot.hasError) {
                              return const Center(
                                  child: Text("Failed to load movie details"));
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
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
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.library_books_rounded),
              label: 'Library',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              label: 'Friends',
              icon: Icon(Icons.contacts),
            ),
            BottomNavigationBarItem(
              label: 'Profile',
              icon: settings["profile_photo"] != "" &&
                      settings["profile_photo"] != null
                  ? ClipOval(
                      child: Image.network(
                      settings["profile_photo"],
                      height: 27,
                      width: 27,
                      fit: BoxFit.cover,
                    ))
                  : const Icon(Icons.person),
            ),
          ],
          currentIndex: selectedIndex,
          onTap: _onItemTapped,
        ),
      );
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replace with your logo
              Image.asset('assets/logo_character.png', height: 100),
              const SizedBox(
                  height: 20), // Adds some spacing between logo and loading bar
              const SizedBox(
                width: 200, // Adjust the width as needed
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }
  }
}
