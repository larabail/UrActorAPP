// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/objects/TVShow.dart';
import 'package:uractor/popups/profile_sections_popup.dart';
import 'package:uractor/tvshow_result.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'objects/Movie.dart';
import 'main.dart';
import 'objects/Person.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'package:fl_chart/fl_chart.dart';

class Profile extends StatefulWidget {
  const Profile();

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
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

  final TextEditingController _usernameController = TextEditingController();
  String? currentUsername;
  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
  }

  _loadCurrentUsername() async {
    DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .doc('Settings')
        .get();
    setState(() {
      currentUsername = settingsDoc['username'];
      _usernameController.text = currentUsername ?? '';
    });
  }

  _updateUsername() async {
    String newUsername = _usernameController.text.trim();

    // Check if username is unique
    QuerySnapshot result = await FirebaseFirestore.instance
        .collection('usernames')
        .where('username', isEqualTo: newUsername)
        .get();

    if (result.docs.isNotEmpty) {
      // Username is taken
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')));
    } else {
      // Update username in user's Settings document
      await FirebaseFirestore.instance
          .collection(currentUser.uid)
          .doc('Settings')
          .update({'username': newUsername});

      // Add username to usernames collection
      await FirebaseFirestore.instance
          .collection('usernames')
          .add({'username': newUsername, "uid": currentUser.uid});

      // Optionally, remove old username from usernames collection
      if (currentUsername != null) {
        QuerySnapshot oldUsernameDocs = await FirebaseFirestore.instance
            .collection('usernames')
            .where('username', isEqualTo: currentUsername)
            .get();
        for (var doc in oldUsernameDocs.docs) {
          await doc.reference.delete();
        }
      }

      setState(() {
        currentUsername = newUsername;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfWeek =
        now.subtract(Duration(days: now.weekday - 1 + (7 * weekOffset)));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    Future<String> uploadImage() async {
      final ImagePicker _picker = ImagePicker();
      XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) return "";

      // Crop the image
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Cropper',
          ),
        ],
        aspectRatio:
            CropAspectRatio(ratioX: 1, ratioY: 1), // Use this for aspect ratio
      );

      if (croppedFile == null) return "";
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      File fileToUpload = File(croppedFile.path);

      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child("profile_images").child(fileName);
      UploadTask uploadTask = ref.putFile(fileToUpload);

      await uploadTask.whenComplete(() => null);
      String downloadUrl = await ref.getDownloadURL();

      var userDoc = FirebaseFirestore.instance
          .collection(currentUser.uid)
          .doc("Settings");
      await userDoc.update({'profile_photo': downloadUrl});
      currentUser.settings["profile_photo"] = downloadUrl;

      setState(() {
        currentUser.settings = currentUser.settings;
      });

      return downloadUrl;
    }

    Map filteredData = {};

    Map tempData = Map.fromEntries(currentUser.calendar.entries.where((entry) {
      DateTime entryDate = DateTime.parse(entry.key);
      return entryDate.isAfter(startOfWeek.add(const Duration(days: -1))) &&
          entryDate.isBefore(endOfWeek);
    }));

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
      int moviesCount = 0;
      int seriesCount = 0;
      for (Map item in entry.value) {
        if (item.keys.toList().contains("type")) {
          if (item["type"] == "series") {
            seriesCount += 1;
          } else {
            moviesCount += 1;
          }
        } else {
          moviesCount += 1;
        }
      }
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: moviesCount.toDouble(),
            color: Colors.green,
            width: 7,
          ),
          BarChartRodData(
            toY: seriesCount.toDouble(),
            color: Colors.red,
            width: 7,
          ),
        ],
      );
    }).toList();

    int maxMovies = 0;
    for (var day in currentUser.calendar.values) {
      int count = 0;
      for (Map movie in day) {
        if (movie["type"] != "series") {
          count += 1;
        }
      }
      if (count > maxMovies) {
        maxMovies = count;
      }
    }

    List<Widget> buildProfileSections() {
      List moviesTemp = [];
      currentUser.rewatchedMovies.forEach((key, value) {
        if (value != 0) moviesTemp.add([value, key]);
      });

      moviesTemp.sort((a, b) => b[0].compareTo(a[0]));

      List tvTemp = [];
      currentUser.rewatchedTVShows.forEach((key, value) {
        if (value != 0) tvTemp.add([value, key]);
      });

      tvTemp.sort((a, b) => b[0].compareTo(a[0]));

      List tempActors = [];
      for (List item in currentUser.favActors) {
        if (item[0] != 0) tempActors.add(item);
      }

      List tempWriters = [];
      for (List item in currentUser.favWriters) {
        if (item[0] != 0) tempWriters.add(item);
      }

      List tempDirectors = [];
      for (List item in currentUser.favDirectors) {
        if (item[0] != 0) tempDirectors.add(item);
      }
      List<Widget> sections = [];
      var profileSections = currentUser.settings["profileSections"];
      List<MapEntry<dynamic, dynamic>> sectionsList =
          currentUser.settings["profileSections"].entries.toList();
      sectionsList
          .sort((a, b) => a.value["weight"].compareTo(b.value["weight"]));

      var sectionKeys = Map.fromEntries(sectionsList).keys.toList();
      for (var key in sectionKeys) {
        if (profileSections[key]["show"]) {
          switch (key) {
            case "Actors":
              sections.add(buildProfileContainer("Favorite Actors", tempActors,
                  Icons.theater_comedy, "Person"));
              break;
            case "Directors":
              sections.add(buildProfileContainer(
                  "Favorite Directors", tempDirectors, Icons.chair, "Person"));
              break;
            case "MostSeenMovies":
              sections.add(buildProfileContainer(
                  "Most Seen Movies", moviesTemp, Icons.movie, "Movie"));
              break;
            case "Writers":
              sections.add(buildProfileContainer(
                  "Favorite Writers", tempWriters, Icons.edit, "Person"));
              break;
            case "MostSeenTVShows":
              sections.add(buildProfileContainer(
                  "Most Seen TV Shows", tvTemp, Icons.tv, "TVShow"));
              break;
          }
        }
      }

      return sections;
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 16.0, top: 10),
                          child: Stack(
                            alignment: Alignment
                                .bottomRight, // Aligns the stack's children to the bottom right
                            children: [
                              ClipOval(
                                child: currentUser.settings["profile_photo"] !=
                                        ""
                                    ? Image.network(
                                        currentUser.settings["profile_photo"],
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        'assets/main_profile.png',
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              CircleAvatar(
                                backgroundColor:
                                    const Color.fromARGB(250, 224, 190, 78),
                                child: IconButton(
                                  icon: const Icon(Icons.file_upload),
                                  color: Colors.black, // Icon color
                                  onPressed: () async {
                                    await uploadImage();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              left: 16.0), // Add margin here
                                          child: TextField(
                                            controller: _usernameController,
                                            decoration: const InputDecoration(
                                              labelText: 'Username',
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: _updateUsername,
                                      ),
                                    ],
                                  ),
                                ],
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
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
                                          child: const Text(
                                            '<<',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
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
                                          child: const Text(
                                            'This Week',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
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
                                          child: const Text(
                                            '>>',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
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
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: false,
                                                getTitlesWidget: (value, meta) {
                                                  return Container();
                                                },
                                              ),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.lightBlue,
                                                      fontSize: 14,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.record_voice_over,
                                                  size: 30,
                                                  color: Colors.blue),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  "Current Record: $maxMovies movies in a day",
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.movie,
                                                  size: 30,
                                                  color: Colors.green),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  "Total Movies Ever Seen: ${currentUser.seenMovies.length}",
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.tv,
                                                  size: 30, color: Colors.red),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  "Total TV Shows Ever Seen: ${currentUser.seenTVShows.length}",
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ])),
                    ...buildProfileSections(),
                    const SizedBox(
                      height: 10,
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext ontext) {
                            return ProfileSectionsDialogue(
                              onDialogClosed: () {
                                setState(() {});
                              },
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 225,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                              'Modify Profile Sections',
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
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(3),
    );
  }

  Widget buildProfileContainer(String title, List content, icon, type) {
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
                  var item;
                  if (type == "Person") {
                    item = Person(id: content[index][1], name: "", data: {});
                  } else if (type == "Movie") {
                    item =
                        Movie(id: content[index][1], title: "", coverPhoto: "");
                  } else {
                    item = TVShow(
                        id: content[index][1], title: "", coverPhoto: "");
                  }
                  return FutureBuilder<Map>(
                    future: type == "Person"
                        ? item.getSimpleData()
                        : item.getData(),
                    builder:
                        (BuildContext context, AsyncSnapshot<Map> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                          width: MediaQuery.of(context).size.width * 0.28,
                          height: MediaQuery.of(context).size.height * 0.18,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError) {
                        return const Center(
                            child: Text("Failed to load details"));
                      } else if (!snapshot.hasData) {
                        return const Center(child: Text("No data available"));
                      } else {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => type == "Person"
                                    ? PersonResult(personResult: item as Person)
                                    : type == "Movie"
                                        ? MovieResult(movie: item as Movie)
                                        : TVShowResult(tvshow: item as TVShow),
                              ),
                            );
                          },
                          child: getItemContainer(context, snapshot.data, (type == "Movie" || type == "TVShow") ? "media" : "person")
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
