// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uractor/l10n/l10n.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/firebase/firestore_core.dart';

class SignUp extends StatelessWidget {
  const SignUp({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    late String email, password;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
            child: Image.asset(
          'assets/logo_character.png',
          height: 54,
        )),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AutofillGroup(
              child: Form(
                key: formKey,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Your Email',
                      hintStyle:
                          TextStyle(color: Color.fromARGB(130, 255, 255, 255)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 2.0),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                    onSaved: (String? value) {
                      email = value!;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Your Password',
                      hintStyle:
                          TextStyle(color: Color.fromARGB(130, 255, 255, 255)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 2.0),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    onSaved: (String? value) {
                      password = value!;
                    },
                    onChanged: (String? value) {
                      password = value!;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Repeat Password',
                      hintText: 'Your Password',
                      hintStyle:
                          TextStyle(color: Color.fromARGB(130, 255, 255, 255)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 2.0),
                      ),
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please reenter your password';
                      }
                      if (value != password) {
                        return 'The passwords do not match.';
                      }
                      return null;
                    },
                    onSaved: (String? value) {},
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    child: const Text('SignUp'),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        try {
                          await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                                  email: email, password: password)
                              .then((credential) {
                            const Map<String, dynamic> data = {"Seen": []};
                            const Map<String, dynamic> tvshows = {"Seen": []};
                            const Map<String, dynamic> seenDoc = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> review = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> favorites = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> watchlist = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> country = {
                              "Country": "US"
                            };
                            const Map<String, dynamic> favDirectors = {};
                            const Map<String, dynamic> favWriters = {};
                            const Map<String, dynamic> favActors = {};
                            const Map<String, dynamic> calendar = {};
                            const Map<String, dynamic> rewatched = {};
                            const Map<String, dynamic> rewatchedTV = {};
                            const Map<String, dynamic> notifications = {};
                            const Map<String, dynamic> friends = {
                              "friends": []
                            };
                            const Map<String, dynamic> seenWith = {
                              "Movies": {},
                              "TVShows": {}
                            };
                            const Map<String, dynamic> recommendations = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> settings = {
                              "darkMode": true,
                              "dontAskCalendar": false,
                              "providers": [],
                              "profile_photo": "",
                              "username": "",
                              "profileSections": {
                                "Actors": {"show": true, "weight": 1},
                                "Directors": {"show": true, "weight": 3},
                                "MostSeenMovies": {"show": true, "weight": 0},
                                "Writers": {"show": false, "weight": 4},
                                "MostSeenTVShows": {"show": false, "weight": 2}
                              },
                            };
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Movies")
                                .set(data);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("TVShows")
                                .set(tvshows);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Seen")
                                .set(seenDoc);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("SeenWith")
                                .set(seenWith);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Reviews")
                                .set(review);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Favorites")
                                .set(favorites);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Watchlist")
                                .set(watchlist);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Country")
                                .set(country);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Calendar")
                                .set(calendar);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("FavDirectors")
                                .set(favDirectors);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("FavWriters")
                                .set(favWriters);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("FavActors")
                                .set(favActors);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Rewatched")
                                .set(rewatched);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("RewatchedTV")
                                .set(rewatchedTV);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Settings")
                                .set(settings);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Friends")
                                .set(friends);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Notifications")
                                .set(notifications);
                            FirestoreCore.db
                                .collection(credential.user!.uid)
                                .doc("Recommendations")
                                .set(recommendations);
                          });
                          try {
                            await FirebaseAuth.instance
                                .signInWithEmailAndPassword(
                                    email: email, password: password)
                                .then((_) {
                              TextInput.finishAutofillContext();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const MyApp()),
                              );
                            });
                          } on FirebaseAuthException catch (e) {
                            if (!context.mounted) return;
                            if (e.code == 'user-not-found') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(S.of(context)!.noUserFoundError),
                                ),
                              );
                            } else if (e.code == 'wrong-password') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      S.of(context)!.wrongPasswordError),
                                ),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (!context.mounted) return;
                          if (e.code == 'weak-password') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context)!.weakPasswordError),
                              ),
                            );
                          } else if (e.code == 'email-already-in-use') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    S.of(context)!.emailAlreadyInUseError),
                              ),
                            );
                          } else if (e.code == 'invalid-email') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context)!.invalidEmailError),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context)!.genericAuthError),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
