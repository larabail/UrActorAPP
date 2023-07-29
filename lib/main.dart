// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/calendar.dart';
import 'package:uractor/favorites.dart';
import 'package:uractor/login.dart';
import 'package:uractor/oscars.dart';
import 'package:uractor/playlists.dart';
import 'package:uractor/profile.dart';
import 'package:uractor/recommendations.dart';
import 'package:uractor/search.dart';
import 'package:uractor/seen.dart';
import 'package:uractor/watchlist.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

String uid = '';
String email = '';
String country = '';
Map calendar = {};
List favActors = [];
List favDirectors = [];
List favMovies = [];
List favTVShows = [];
List seenMovies = [];
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrActor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Home'),
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
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;

    final List<Widget> pages = [
      const MyApp(),
      Search(),
      Playlists(),
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

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        // Redirect to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      } else {
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
            } else if (doc.id == "Reviews" && reviews.keys.isEmpty) {
              reviews = doc.data() as Map;
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
                playlists[doc.id] = doc.data();
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
      }
    });

    var myDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFFF8D440),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    var myDecoration2 = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFFEC1D27),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    var myDecoration6 = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFFCC6E00),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    var myDecoration3 = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFF2196F3),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    var myDecoration4 = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFF008037),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    var myDecoration5 = BoxDecoration(
      borderRadius: BorderRadius.circular(27.0),
      color: const Color(0xFFB0008A),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 72, 72, 72).withOpacity(0.5),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(4, 4), // changes position of shadow
        ),
      ],
    );
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Center(
            child: Image.asset(
          'assets/logo.png',
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
                  // Handle the click event here
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Watchlist()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.width * 0.5,
                  decoration: myDecoration3,
                  child: Column(
                    children: [
                      Image.asset('assets/main_bookmark.png'),
                      const Text(
                        'Your Watchlist',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Handle the click event here
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Favorites()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.width * 0.5,
                  decoration: myDecoration2,
                  child: Column(
                    children: [
                      Image.asset('assets/main_favorites.png'),
                      const Text(
                        'Your Favorites',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // Handle the click event here
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Seen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.width * 0.5,
                  decoration: myDecoration5,
                  child: Column(
                    children: [
                      Image.asset('assets/seen.png'),
                      const Text(
                        'Seen',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Handle the click event here
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Calendar()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.width * 0.5,
                  decoration: myDecoration6,
                  child: Column(
                    children: [
                      Image.asset('assets/calendar.png'),
                      const Text(
                        'Your Calendar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          //   Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       GestureDetector(
          //         onTap: () {
          //           // Handle the click event here
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(builder: (context) => Recommendations()),
          //           );
          //         },
          //         child: Container(
          //           margin: const EdgeInsets.all(10.0),
          //           width: MediaQuery.of(context).size.width * 0.4,
          //           height: MediaQuery.of(context).size.width * 0.5,
          //           decoration: myDecoration,
          //           child: Column(
          //             children: [
          //               Image.asset('assets/main_recommendation.png'),
          //               const Text(
          //                 'Your Reviews',
          //                 style: TextStyle(
          //                   fontSize: 15,
          //                   fontWeight: FontWeight.bold,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //       GestureDetector(
          //         onTap: () {
          //           // Handle the click event here
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(builder: (context) => Oscars()),
          //           );
          //         },
          //         child: Container(
          //           margin: const EdgeInsets.all(10.0),
          //           width: MediaQuery.of(context).size.width * 0.4,
          //           height: MediaQuery.of(context).size.width * 0.5,
          //           decoration: myDecoration4,
          //           child: Column(
          //             children: [
          //               Image.asset('assets/main_oscars.png'),
          //               const Text(
          //                 'Oscar Winners',
          //                 style: TextStyle(
          //                   fontSize: 15,
          //                   fontWeight: FontWeight.bold,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121212),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            label: 'Profile',
            backgroundColor: Color(0xFF121212),
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
