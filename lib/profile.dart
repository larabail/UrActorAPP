// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'objects/Movie.dart';
import 'main.dart';
import 'objects/Person.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'common/theme_provider.dart';

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

class Provider {
  final String image;
  final String name;
  final String id;
  bool isSelected;

  Provider(
      {required this.image,
      required this.name,
      required this.id,
      required this.isSelected});

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      image: json['logo_path'],
      name: json['provider_name'],
      id: json['provider_id'].toString(),
      isSelected: currentUser.settings["providers"]
          .contains(json['provider_id'].toString()),
    );
  }
}

class InfoButtonDialog extends StatefulWidget {
  const InfoButtonDialog();

  @override
  _InfoButtonDialogState createState() => _InfoButtonDialogState();
}

class _InfoButtonDialogState extends State<InfoButtonDialog> {
  String selectedCountry = currentUser.country;
  List<Country> countries = [];
  List<Provider> allProviders = [];
  Country? selectedCountryObject;
  @override
  @override
  void initState() {
    super.initState();
    fetchCountries();
    fetchProviders();
  }

  Future<void> fetchCountries() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.themoviedb.org/3/configuration/countries?api_key=700cd4fab994df56eb41b34d38c4762a'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          countries = List<Country>.from(
              data.map((country) => Country.fromJson(country)));
        });
        selectedCountryObject = findCountryByIsoCode(selectedCountry);
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchProviders() async {
    final response = await http.get(Uri.parse(
        "https://api.themoviedb.org/3/watch/providers/movie?api_key=700cd4fab994df56eb41b34d38c4762a&watch_region=${currentUser.country}"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        allProviders = List<Provider>.from(
            data["results"].map((country) => Provider.fromJson(country)));
      });
    } else {
      print('Failed to fetch providers');
    }
  }

  // Helper function to find the Country object with the matching ISO code
  Country? findCountryByIsoCode(String isoCode) {
    return countries.firstWhere(
      (country) => country.isoCode == isoCode,
      orElse: () => countries[0],
    );
  }

  Future<void> updateCountry(Country element) async {
    var userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Country");
    await userDoc.update({'Country': element.isoCode});
    currentUser.country = element.isoCode;
  }

  Future<void> updateSettings(element, newValue) async {
    var userDoc =
        FirebaseFirestore.instance.collection(currentUser.uid).doc("Settings");
    currentUser.settings[element] = newValue;
    await userDoc.set(currentUser.settings as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
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
        child: SizedBox(
          width: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Country You're Viewing in",
                style: TextStyle(fontSize: 18, color: Colors.white),
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
                isExpanded: true,
                underline: Container(
                  height: 2,
                  color: Colors.white,
                ),
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
                            updateSettings(
                                "darkMode", themeProvider.isDarkMode);
                          },
                          activeColor: Colors.green,
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.nightlight_round,
                            color: Colors.blueAccent),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                '"Did you watch this movie today?" reminders',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_box, color: Colors.yellow),
                  const SizedBox(width: 16),
                  Switch(
                    value: currentUser.dontAskCalendar,
                    onChanged: (value) {
                      setState(() {
                        currentUser.dontAskCalendar =
                            !currentUser.dontAskCalendar;
                        updateSettings(
                            "dontAskCalendar", currentUser.dontAskCalendar);
                      });
                    },
                    activeColor: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.disabled_by_default,
                      color: Colors.redAccent),
                ],
              ),
              const Text(
                'Your Providers',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.18,
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: allProviders.length,
                    itemBuilder: (BuildContext context, int index) {
                      Provider provider = allProviders[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            provider.isSelected = !provider.isSelected;
                            if (provider.isSelected) {
                              currentUser.settings["providers"]
                                  .add(provider.id.toString());
                            } else {
                              currentUser.settings["providers"]
                                  .remove(provider.id.toString());
                            }
                            updateSettings(
                                "providers", currentUser.settings["providers"]);
                          });
                        },
                        child: Stack(
                          children: [
                            Image.network(
                              IMG_LINK + provider.image,
                              width: double.infinity,
                              height: 150.0,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 0.0,
                              left: 4.0,
                              child: Text(
                                provider.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (provider.isSelected)
                              const Positioned(
                                bottom: 4.0,
                                right: 4.0,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24.0,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Logout Button
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pop(context);
                      Navigator.popUntil(context, (route) => route.isFirst);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Login()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout_outlined, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Delete Button
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertButtonDialogue(),
                      );
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
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

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
                FirebaseFirestore.instance.collection(currentUser.uid);
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

            Navigator.pop(context);
            Navigator.popUntil(context, (route) => route.isFirst);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
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
  const Profile();

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
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

    Future<List<Map<String, dynamic>>> actorData() async {
      List<Map<String, dynamic>> favActsData = [];
      int i = 0;
      for (List item in currentUser.favActors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('$PERSON_LINK${item[1]}$API_KEY'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = IMG_LINK + json['profile_path'];
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

    Future<List<Map<String, dynamic>>> topMovies() async {
      int i = 0;
      List<Map<String, dynamic>> movies = [];

      List moviesTemp = [];
      currentUser.rewatchedMovies.forEach((key, value) {
        moviesTemp.add([value, key]);
      });

      moviesTemp.sort((a, b) => b[0].compareTo(a[0]));

      while (i < 18 && i < moviesTemp.length) {
        String completeLinkMovie =
            MOVIE_LINK + moviesTemp[i][1].toString() + API_KEY;

        final response = await http.get(Uri.parse(completeLinkMovie));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          movies.add(json);
        } else {
          throw Exception('Failed to load actor details');
        }
        i++;
      }
      return movies;
    }

    Future<String> uploadImage() async {
      final ImagePicker _picker = ImagePicker();
      XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) return "";

      // Crop the image
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
        ],
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

    Future<List<Map<String, dynamic>>> dirData() async {
      List<Map<String, dynamic>> favActsData = [];
      int i = 0;
      for (List item in currentUser.favDirectors) {
        if (i < 9) {
          final response =
              await http.get(Uri.parse('$PERSON_LINK${item[1]}$API_KEY'));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['profile_path'] == null) {
              json['profile_path'] =
                  'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
            } else {
              json['profile_path'] = IMG_LINK + json['profile_path'];
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
      final moviesCount = entry.value.length;
      return BarChartGroupData(x: day, barRods: [
        BarChartRodData(
            y: moviesCount.toDouble(),
            colors: [Colors.blue],
            width: 7 // Adjust this value to change the bar thickness
            )
      ]);
    }).toList();

    int maxMovies = 0;
    for (var movies in currentUser.calendar.values) {
      if (movies.length > maxMovies) {
        maxMovies = movies.length;
      }
    }
    Widget buildItem(
        BuildContext context, Map<String, dynamic> item, String type) {
      String imagePath =
          type == "Movies" ? item['poster_path'] : item['profile_path'];
      // String navigateTo = type == "Movies" ? 'MovieResult' : 'PersonResult';

      return GestureDetector(
        onTap: () {
          Movie tempMovie = Movie(id: "", title: "", coverPhoto: "");
          if (type == "Movies") {
            tempMovie = Movie(
                id: item['id'].toString(),
                title: item['title'],
                coverPhoto: item["poster_path"] ?? "");
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => MovieResult(movie: tempMovie)),
            );
          } else {
            Person personResult = Person(
                id: item["id"].toString(),
                name: item["name"].toString(),
                data: item);

            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PersonResult(
                        personResult: personResult,
                      )),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
          width: MediaQuery.of(context).size.width * 0.28,
          height: MediaQuery.of(context).size.height * 0.18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: NetworkImage(IMG_LINK + imagePath),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      );
    }

    Widget buildTabContent(BuildContext context,
        Future<List<Map<String, dynamic>>> futureData, String type) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: futureData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final items = snapshot.data!;
            return ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 3, // adjust based on your requirements
              itemBuilder: (context, index) {
                final leftItemIndex = index * 3;
                final middleItemIndex = index * 3 + 1;
                final rightItemIndex = index * 3 + 2;
                final leftItem = (leftItemIndex < items.length)
                    ? items[leftItemIndex]
                    : null;
                final middleItem = (middleItemIndex < items.length)
                    ? items[middleItemIndex]
                    : null;
                final rightItem = (rightItemIndex < items.length)
                    ? items[rightItemIndex]
                    : null;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (leftItem != null) buildItem(context, leftItem, type),
                    if (middleItem != null)
                      buildItem(context, middleItem, type),
                    if (rightItem != null) buildItem(context, rightItem, type),
                  ],
                );
              },
            );
          } else if (snapshot.hasError) {
            return const Center(child: Text("Failed to load data"));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      );
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
                    ClipOval(
                      child: currentUser.settings["profile_photo"] != ""
                          ? Image.network(
                              currentUser.settings["profile_photo"],
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/main_profile.png',
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
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
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: _updateUsername,
                                ),
                              ],
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
                                      child: Column(
                                        children: [
                                          Consumer<ThemeProvider>(builder:
                                              (context, themeProvider, child) {
                                            return Row(
                                              children: [
                                                const Icon(
                                                    Icons.record_voice_over,
                                                    size: 30,
                                                    color: Colors.blue),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    "Record: $maxMovies movies in a day",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                              .isDarkMode
                                                          ? Colors.yellow
                                                          : Colors.green,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
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
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
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
                                buildTabContent(
                                    context, actorData(), 'PersonResult'),
                                buildTabContent(
                                    context, dirData(), 'PersonResult'),
                                buildTabContent(context, topMovies(), 'Movies'),
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
                  builder: (context) => const InfoButtonDialog(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(3),
    );
  }
}
