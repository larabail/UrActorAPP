import 'package:flutter/material.dart';
import 'profile.dart';
import 'search.dart';
import 'main.dart';
import 'playlists.dart';
import 'person_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<String> _loadJSONFile() async {
  return await rootBundle.loadString('assets/oscars_api.json');
}

Future<List<Map<String, dynamic>>> parseJSONFile() async {
  if (oscarsPage.length == 0) {
    List<Map<String, dynamic>> people = [];
    String jsonString = await _loadJSONFile();
    Map items = jsonDecode(jsonString);
    Map peopleOscars = {};
    for (String person_id in items.keys) {
      link = 'https://api.themoviedb.org/3/person/';
      final response = await http.get(
          Uri.parse('${link}${items[person_id]['tmdb_id']}${api_key_actor}'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['profile_path'] != null) {
          items[person_id]['profile_path'] = imgLink + json['profile_path'];
        } else {
          items[person_id]['profile_path'] =
              "https://cdn-icons-png.flaticon.com/512/3088/3088765.png";
        }
        items[person_id]['id'] = items[person_id]['tmdb_id'];
        peopleOscars[items[person_id]['tmdb_id']] = items[person_id];
        if (!containsMap(people, items[person_id])) {
          people.add(items[person_id]);
        }
      } else {
        throw Exception('Failed to load movie details');
      }
    }
    oscars = peopleOscars;
    oscarsPage = people;
    return people;
  } else {
    return oscarsPage;
  }
}

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
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
String link = "https://api.themoviedb.org/3/person/";

class Oscars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;

    final List<Widget> _pages = [
      MyApp(),
      Search(),
      Playlists(),
      Profile(),
      // Add more pages here
    ];

    void _onItemTapped(int index) {
      _selectedIndex = index;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _pages[_selectedIndex]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Center(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                "Oscar Winners",
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: parseJSONFile(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final people = snapshot.data!;
                    return ListView.builder(
                      itemCount: (people.length / 3).ceil(),
                      itemBuilder: (context, index) {
                        final leftPersonIndex = index * 3;
                        final middlePersonIndex = index * 3 + 1;
                        final rightPersonIndex = index * 3 + 2;
                        final leftPerson = (leftPersonIndex < people.length)
                            ? people[leftPersonIndex]
                            : null;
                        final middlePerson = (middlePersonIndex < people.length)
                            ? people[middlePersonIndex]
                            : null;
                        final rightPerson = (rightPersonIndex < people.length)
                            ? people[rightPersonIndex]
                            : null;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (leftPerson != null)
                              GestureDetector(
                                onTap: () {
                                  personResult = leftPerson;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PersonResult()),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5.0, vertical: 10.0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              leftPerson['profile_path']),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.2,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                15, 0, 0, 0),
                                            child: Container(
                                              height: 20.0,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.26,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      "${leftPerson['name']}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (middlePerson != null)
                              GestureDetector(
                                onTap: () {
                                  personResult = middlePerson;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PersonResult()),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5.0, vertical: 10.0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              middlePerson['profile_path']),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.2,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                15, 0, 0, 0),
                                            child: Container(
                                              height: 20.0,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.26,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      "${middlePerson['name']}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (rightPerson != null)
                              GestureDetector(
                                onTap: () {
                                  personResult = rightPerson;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PersonResult()),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5.0, vertical: 10.0),
                                      width: MediaQuery.of(context).size.width *
                                          0.28,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.18,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              rightPerson['profile_path']),
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.2,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                15, 0, 0, 0),
                                            child: Container(
                                              height: 20.0,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.26,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      "${rightPerson['name']}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
