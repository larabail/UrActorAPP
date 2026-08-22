// ignore_for_file: must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'dart:convert';

import '../common/auth_session.dart';
import '../common/constants.dart';
import '../common/firebase/firestore_core.dart';
import '../common/firebase/settings_service.dart';
import '../login.dart';
import '../main.dart';
import '../common/api/http_client.dart';

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
  const InfoButtonDialog({super.key});

  @override
  State<InfoButtonDialog> createState() => _InfoButtonDialogState();
}

class _InfoButtonDialogState extends State<InfoButtonDialog> {
  String selectedCountry = currentUser.country;
  List<Country> countries = [];
  List<Provider> allProviders = [];
  Locale _selectedLocale = const Locale('en');
  Country? selectedCountryObject;
  @override
  @override
  void initState() {
    super.initState();
    _selectedLocale = currentUser.settings["language"] != null
        ? Locale(currentUser.settings["language"])
        : const Locale('en');
    fetchCountries();
    fetchProviders();
  }

  Future<void> fetchCountries() async {
    try {
      final response = await AppHttp.client.get(Uri.parse(COUNTRIES_LINK));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          countries = List<Country>.from(
              data.map((country) => Country.fromJson(country)));
        });
        selectedCountryObject = findCountryByIsoCode(selectedCountry);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> fetchProviders() async {
    final response = await AppHttp.client.get(
        Uri.parse("$WATCH_PROVIDERS_BY_REGION_LINK${currentUser.country}"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        allProviders = List<Provider>.from(
            data["results"].map((country) => Provider.fromJson(country)));
      });
    } else {
      debugPrint('Failed to fetch providers');
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
    await FirestoreCore.updateDocument(
        currentUser.uid, "Country", {'Country': element.isoCode});
    currentUser.country = element.isoCode;
  }

  Future<void> updateSettings(String element, dynamic newValue) async {
    await SettingsService.update(element, newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      // `Dialog` only imposes a *minimum* width, so a dialogue whose content
      // never asks for a width sits at that 280pt minimum however much room it
      // was offered -- which is what squeezed the account actions below until
      // they no longer fit. Taking the room on offer and stopping at the width
      // Material stops widening a dialogue at keeps the form readable on a
      // phone without stretching it across a desktop window.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.all(25.0),
          // Every field here is a fixed height, so a short window -- landscape,
          // or a large system font -- runs the column past the bottom of the
          // panel. Without this it overflowed there rather than scrolling.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'App Language',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                DropdownButton<Locale>(
                  value: _selectedLocale,
                  onChanged: (Locale? newLocale) async {
                    if (newLocale != null) {
                      setState(() {
                        _selectedLocale = newLocale;
                      });
                      currentUser.settings["language"] = newLocale.languageCode;
                      await updateSettings("language", newLocale.languageCode);
                      if (!context.mounted) return;
                      MyApp.setLocale(context, newLocale);
                    }
                  },
                  items: S.supportedLocales.map((locale) {
                    final label =
                        locale.languageCode == 'en' ? 'English' : 'Español';
                    return DropdownMenuItem<Locale>(
                      value: locale,
                      child: Text(label),
                    );
                  }).toList(),
                  isExpanded: true,
                  underline: Container(
                    height: 2,
                    color: Colors.white,
                  ),
                ),
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
                  items: countries
                      .map<DropdownMenuItem<Country>>((Country country) {
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
                      activeThumbColor: Colors.green,
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
                              updateSettings("providers",
                                  currentUser.settings["providers"]);
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
                // An `OverflowBar` rather than a `Row`, because these two
                // labels grow with the system font size while the icons and
                // paddings beside them do not. A row could only overflow, and
                // a release build clips instead of complaining, so the buttons
                // were being silently cut in half. This stacks them when they
                // stop fitting, which no text scale or translation can defeat.
                OverflowBar(
                  alignment: MainAxisAlignment.spaceEvenly,
                  overflowAlignment: OverflowBarAlignment.center,
                  overflowSpacing: 8,
                  children: [
                    // Logout Button
                    GestureDetector(
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await AuthSession.signOut();
                        if (!context.mounted) return;
                        navigator.pop();
                        navigator.popUntil((route) => route.isFirst);
                        navigator.push(
                          MaterialPageRoute(
                              builder: (context) => const Login()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // `MainAxisSize.min` is load bearing: `OverflowBar`
                        // measures its children against the full width it
                        // has, so a row left to its default would claim all
                        // of it and force the stacked layout every time.
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_outlined, color: Colors.white),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
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
      ),
    );
  }
}

class AlertButtonDialogue extends StatefulWidget {
  const AlertButtonDialogue({super.key});

  @override
  State<AlertButtonDialogue> createState() => _AlertButtonDialogueState();
}

class _AlertButtonDialogueState extends State<AlertButtonDialogue> {
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context)!.deleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.deleteAccountConfirmation,
            style: const TextStyle(color: Colors.red),
          ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: S.of(context)!.yourPassword,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            CollectionReference collectionRef =
                FirestoreCore.db.collection(currentUser.uid);
            QuerySnapshot snapshot = await collectionRef.get();
            for (DocumentSnapshot docSnapshot in snapshot.docs) {
              await docSnapshot.reference.delete();
            }
            User? user = FirebaseAuth.instance.currentUser;
            AuthCredential credential = EmailAuthProvider.credential(
              email: user!.email as String,
              password: passwordController.text,
            );
            await user.reauthenticateWithCredential(credential);

            await user.delete();
            AuthSession.clearPerUserCaches();

            if (!context.mounted) return;
            navigator.pop();
            navigator.popUntil((route) => route.isFirst);
            navigator.push(
              MaterialPageRoute(builder: (context) => const Login()),
            );
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.red),
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
