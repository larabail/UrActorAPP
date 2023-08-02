// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'playlists.dart';
import 'search.dart';
import 'main.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class Country {
  final String isoCode;
  final String englishName;
  final String nativeName;

  Country(
      {required this.isoCode,
      required this.englishName,
      required this.nativeName});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      isoCode: json['iso_3166_1'],
      englishName: json['english_name'],
      nativeName: json['native_name'],
    );
  }
}

class InfoButtonDialog extends StatefulWidget {
  InfoButtonDialog();

  @override
  _InfoButtonDialogState createState() => _InfoButtonDialogState();
}

class _InfoButtonDialogState extends State<InfoButtonDialog> {
  String selectedCountry = country;
  List<Country> countries = [];
  Country? selectedCountryObject;
  @override
  @override
  void initState() {
    super.initState();
    fetchCountries();
  }

  Future<void> fetchCountries() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.themoviedb.org/3/configuration/countries?api_key=700cd4fab994df56eb41b34d38c4762a'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // print(data);
        setState(() {
          countries = List<Country>.from(
              data.map((country) => Country.fromJson(country)));
        });
        selectedCountryObject = findCountryByIsoCode(selectedCountry);
      } else {
        print('Failed to fetch countries');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Helper function to find the Country object with the matching ISO code
  Country? findCountryByIsoCode(String isoCode) {
    return countries.firstWhere(
      (country) => country.isoCode == isoCode,
      orElse: () => countries[0],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Find the default selected Country based on the selectedCountry variable
    // selectedCountryObject = findCountryByIsoCode(selectedCountry);
  }

  Future<void> updateCountry(Country element) async {
    var userDoc = FirebaseFirestore.instance.collection(uid).doc("Country");
    await userDoc.update({'Country': element.isoCode});
    country = element.isoCode;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
          // change the color of dialog window here
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.all(25.0),
        child: SizedBox(
          width: 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              "Country You're Viewing in",
              style: TextStyle(fontSize: 18),
            ),
            DropdownButton<Country>(
              value: selectedCountryObject,
              onChanged: (Country? newValue) async {
                await updateCountry(newValue as Country);
                setState(() {
                  selectedCountry = newValue.isoCode;
                  selectedCountryObject = newValue;
                });
              },
              items:
                  countries.map<DropdownMenuItem<Country>>((Country country) {
                return DropdownMenuItem<Country>(
                  value: country,
                  child: Text(country.englishName),
                );
              }).toList(),

              isExpanded: true, // Make the dropdown list take full width
              underline: Container(), // Remove the default underline
            ),
            Center(
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.yellow),
                      const SizedBox(width: 16),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleDarkMode();
                        },
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      const Icon(Icons.nightlight_round,
                          color: Colors.blueAccent),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            const Text(
              '"Did you watch this movie today?" reminders',
              style: TextStyle(fontSize: 18),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_box, color: Colors.yellow),
                const SizedBox(width: 16),
                Switch(
                  value: dontAskCalendar,
                  onChanged: (value) {
                    setState(() {
                      dontAskCalendar = !dontAskCalendar;
                    });
                  },
                ),
                const SizedBox(
                  width: 16,
                ),
                const Icon(Icons.disabled_by_default, color: Colors.redAccent),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              color: const Color.fromARGB(255, 232, 85, 75),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                email = "";
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              },
            ),
            ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                      const Color.fromARGB(255, 242, 111, 102)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertButtonDialogue(),
                  );
                },
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: Color.fromARGB(255, 130, 9, 0)),
                )),
          ]),
        ),
      ),
    );
  }
}

const String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
const String imgLink = 'https://image.tmdb.org/t/p/w500/';
String link = "https://api.themoviedb.org/3/movie/";
int weekOffset = 0; // This will be used to go to previous or next weeks

final months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
];

Future<List<Map>> topMovies() async {
  int i = 0;
  List<Map> movies = [];

  List moviesTemp = [];
  rewatchedMovies.forEach((key, value) {
    moviesTemp.add([value, key]);
  });

  moviesTemp.sort((a, b) => b[0].compareTo(a[0]));

  while (i < 18 && i < moviesTemp.length) {
    String completeLinkMovie =
        link + moviesTemp[i][1].toString() + api_key_actor;

    final response = await http.get(Uri.parse(completeLinkMovie));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      movies.add(json);
    } else {
      throw Exception('Failed to load movie details');
    }
    i++;
  }
  return movies;
}

class AlertButtonDialogue extends StatelessWidget {
  TextEditingController passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Are you sure you want to delete your account? This action will delete all your information.',
            style: TextStyle(color: Colors.red),
          ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "Enter your password",
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            CollectionReference collectionRef =
                FirebaseFirestore.instance.collection(uid);
            QuerySnapshot snapshot = await collectionRef.get();
            for (DocumentSnapshot docSnapshot in snapshot.docs) {
              await docSnapshot.reference.delete();
            }
            User? user = FirebaseAuth.instance.currentUser;
            AuthCredential credential = EmailAuthProvider.credential(
              email: user!.email as String,
              password: passwordController
                  .text, // Replace 'user_password' with the user's password
            );
            await user.reauthenticateWithCredential(credential);

            await user.delete();

            email = "";
            Navigator.pop(context);
            Navigator.popUntil(context, (route) => route.isFirst);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Login()),
            );
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.red),
          ),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class Profile extends StatefulWidget {
  Profile();

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;
    DateTime now = DateTime.now();
    DateTime startOfWeek =
        now.subtract(Duration(days: now.weekday - 1 + (7 * weekOffset)));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    Future<List<Map<String, dynamic>>> actorData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favActors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load actor details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

    Future<List<Map<String, dynamic>>> dirData() async {
      List<Map<String, dynamic>> favActsData = [];
      const link = 'https://api.themoviedb.org/3/person/';
      int i = 0;
      for (List item in favDirectors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('${link}${item[1]}${api_key_actor}'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = imgLink + json['profile_path'];
            }
            favActsData.add(json);
          } else {
            throw Exception('Failed to load director details');
          }
        } else {
          return favActsData;
        }
        i++;
      }
      return favActsData;
    }

    final List<Widget> pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    Map filteredData = {};

    Map tempData = Map.fromEntries(calendar.entries.where((entry) {
      DateTime entryDate = DateTime.parse(entry.key);
      return entryDate.isAfter(startOfWeek.add(const Duration(days: -1))) &&
          entryDate.isBefore(endOfWeek);
    }));

    // print(tempData);
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
    List<BarChartGroupData> chartData = filteredData.entries.map((entry) {
      final day = DateTime.parse(entry.key).day;
      final moviesCount = entry.value.length;
      return BarChartGroupData(x: day, barRods: [
        BarChartRodData(
            y: moviesCount.toDouble(),
            colors: [Colors.blue],
            width: 7 // Adjust this value to change the bar thickness
            )
      ]);
    }).toList();

    void _onItemTapped(int index) {
      selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[selectedIndex]),
      );
    }

    int maxMovies = 0;
    for (var movies in calendar.values) {
      if (movies.length > maxMovies) {
        maxMovies = movies.length;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Image.asset(
            'assets/logo.png',
            height: 54,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/main_profile.png',
                      height: 200,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )),
                    Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(10), // border radius
                        ),
                        child: ExpansionTile(
                            title: const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("Viewing Statistics"),
                            ),
                            children: <Widget>[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 25),
                                child: Column(
                                  children: [
                                    if (startOfWeek.month == endOfWeek.month)
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          "Movies seen the week of ${startOfWeek.toIso8601String().split("-")[2].split("T")[0]}-${endOfWeek.toIso8601String().split("-")[2].split("T")[0]} in ${months[startOfWeek.month - 1]}",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (startOfWeek.month != endOfWeek.month)
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          "Movies seen the week of ${startOfWeek.toIso8601String().split("-")[2].split("T")[0]}-${endOfWeek.toIso8601String().split("-")[2].split("T")[0]} in ${months[startOfWeek.month - 1]}-${months[endOfWeek.month - 1]}",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset +=
                                                  1; // Go to the previous week
                                            });
                                          },
                                          child: const Text('<<'),
                                        ),
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset =
                                                  0; // Go to the previous week
                                            });
                                          },
                                          child: const Text('This Week'),
                                        ),
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all<
                                                    Color>(Colors.transparent),
                                            elevation:
                                                MaterialStateProperty.all(0.0),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              weekOffset -=
                                                  1; // Go to the next week
                                            });
                                          },
                                          child: const Text('>>'),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.2,
                                      width: MediaQuery.of(context).size.width *
                                          0.75,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: chartData,
                                          borderData: FlBorderData(show: false),
                                          titlesData: FlTitlesData(
                                            leftTitles: SideTitles(
                                              showTitles: false,
                                              getTextStyles: (context, value) =>
                                                  const TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 10),
                                            ),
                                            bottomTitles: SideTitles(
                                              showTitles: true,
                                              getTextStyles: (context, value) =>
                                                  const TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Consumer<ThemeProvider>(builder:
                                          (context, themeProvider, child) {
                                        return Text(
                                          "Your record is $maxMovies movies in a day",
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                              fontSize: 18,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.yellow
                                                  : Colors.green),
                                        );
                                      }),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Text(
                                        "Total Movies Ever Seen: ${seenMovies.length}",
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: Text(
                                        "Total TV Shows Ever Seen: ${seenTVShows.length}",
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ])),
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: 'Fav. Actors'),
                              Tab(text: 'Fav. Directors'),
                              Tab(text: 'Most Seen'),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.655,
                            child: TabBarView(
                              children: [
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: actorData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    // Handle the click event here
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
                                                              'profile_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: dirData(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = leftMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            leftMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = middleMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            middleMovie[
                                                                'profile_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    personResult = rightMovie;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              PersonResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          rightMovie[
                                                              'profile_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                                FutureBuilder<List<Map>>(
                                  future: topMovies(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final movies = snapshot.data!;
                                      return ListView.builder(
                                        itemCount: 3,
                                        itemBuilder: (context, index) {
                                          final leftMovieIndex = index * 3;
                                          final middleMovieIndex =
                                              index * 3 + 1;
                                          final rightMovieIndex = index * 3 + 2;
                                          final leftMovie =
                                              (leftMovieIndex < movies.length)
                                                  ? movies[leftMovieIndex]
                                                  : null;
                                          final middleMovie =
                                              (middleMovieIndex < movies.length)
                                                  ? movies[middleMovieIndex]
                                                  : null;
                                          final rightMovie =
                                              (rightMovieIndex < movies.length)
                                                  ? movies[rightMovieIndex]
                                                  : null;
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              if (leftMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    // Handle the click event here
                                                    movieResult = [
                                                      leftMovie['id'],
                                                      leftMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 10.0, 5.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            imgLink +
                                                                leftMovie[
                                                                    'poster_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (middleMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    movieResult = [
                                                      middleMovie['id'],
                                                      middleMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 10.0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            imgLink +
                                                                middleMovie[
                                                                    'poster_path']),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (rightMovie != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    movieResult = [
                                                      rightMovie['id'],
                                                      rightMovie['title'],
                                                      "Movies"
                                                    ];
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              MovieResult()),
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: const EdgeInsets
                                                            .fromLTRB(
                                                        5.0, 10.0, 10.0, 0),
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.28,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.18,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              27),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          imgLink +
                                                              rightMovie[
                                                                  'poster_path'],
                                                        ),
                                                        fit: BoxFit.fitWidth,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    } else if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                            "Failed to load movie details"),
                                      );
                                    } else {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.settings,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => InfoButtonDialog(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.person),
          ),
        ],
        currentIndex: 3,
        onTap: _onItemTapped,
      ),
    );
  }
}
