// ignore_for_file: must_be_immutable

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
import '../common/widgets/app_dialog.dart';

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

  /// Held in state rather than read on every build, so the switch follows the
  /// tap immediately instead of waiting on the write that records it.
  bool _fillEpisodesBefore = true;
  @override
  @override
  void initState() {
    super.initState();
    _selectedLocale = currentUser.settings["language"] != null
        ? Locale(currentUser.settings["language"])
        : const Locale('en');
    _fillEpisodesBefore =
        SettingsService.read<bool>(settingFillEpisodesBefore, true);
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
    return AppDialog(
      actions: [
        AppDialogAction(
          label: 'Logout',
          icon: Icons.logout_outlined,
          onPressed: () async {
            final navigator = Navigator.of(context);
            await AuthSession.signOut();
            if (!context.mounted) return;
            navigator.pop();
            navigator.popUntil((route) => route.isFirst);
            navigator.push(
              MaterialPageRoute(builder: (context) => const Login()),
            );
          },
        ),
        AppDialogAction(
          label: 'Delete',
          icon: Icons.delete,
          tone: AppDialogTone.destructive,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertButtonDialogue(),
            );
          },
        ),
      ],
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
              final label = locale.languageCode == 'en' ? 'English' : 'Español';
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
            items: countries.map<DropdownMenuItem<Country>>((Country country) {
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
                key: const ValueKey('settings-dontAskCalendar'),
                value: currentUser.dontAskCalendar,
                onChanged: (value) {
                  setState(() {
                    currentUser.dontAskCalendar = !currentUser.dontAskCalendar;
                    updateSettings(
                        "dontAskCalendar", currentUser.dontAskCalendar);
                  });
                },
                activeThumbColor: Colors.green,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.disabled_by_default, color: Colors.redAccent),
            ],
          ),
          Text(
            S.of(context)!.fillEarlierEpisodes,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              S.of(context)!.fillEarlierEpisodesHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_box, color: Colors.yellow),
              const SizedBox(width: 16),
              Switch(
                key: const ValueKey('settings-fillEpisodesBefore'),
                value: _fillEpisodesBefore,
                onChanged: (value) {
                  setState(() {
                    _fillEpisodesBefore = value;
                  });
                  updateSettings(settingFillEpisodesBefore, value);
                },
                activeThumbColor: Colors.green,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.disabled_by_default, color: Colors.redAccent),
            ],
          ),
          const Text(
            'Your Providers',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: GridView.builder(
              // The grid used to sit in a box 18% of the screen tall with a
              // fixed four columns, which made every tile 46.5pt square on a
              // phone and hid half the rows behind a scroll nested inside the
              // dialogue's own. Shrink-wrapping shows all of them and lets the
              // one scroll view above deal with the length.
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 96.0,
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
                  // The logo used to be pinned to 150pt however tall the tile
                  // was, so it spilled out of its own cell and a tap landed on
                  // the neighbour it had painted over.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          IMG_LINK + provider.image,
                          fit: BoxFit.cover,
                        ),
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
        ],
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

            // The order of the four steps this runs is load bearing, and the
            // reasoning lives with them in AuthSession.deleteAccount.
            await AuthSession.deleteAccount(
              uid: currentUser.uid,
              password: passwordController.text,
            );

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
