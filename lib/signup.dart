// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    late String email, password;

    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Image.asset(
          'assets/logo.png',
          height: 54,
        )),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Your Email',
                      hintStyle:
                          TextStyle(color: Color.fromARGB(130, 255, 255, 255)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide( width: 1.0),
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
                        borderSide: BorderSide( width: 2.0),
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
                    onSaved: (String? value) {
                    },
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
                            const Map<String, dynamic> Review = {"Seen": []};
                            const Map<String, dynamic> Favorites = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> Watchlist = {
                              "Movies": [],
                              "TVShows": []
                            };
                            const Map<String, dynamic> Country = {
                              "Country": "US"
                            };
                            const Map<String, dynamic> FavDirectors = {};
                            const Map<String, dynamic> FavActors = {};
                            const Map<String, dynamic> Calendar = {};
                            const Map<String, dynamic> Rewatched = {};
                            const Map<String, dynamic> Settings = {"darkMode": true, "dontAskCalendar": false};
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Movies")
                                .set(data);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("TVShows")
                                .set(tvshows);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Reviews")
                                .set(Review);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Favorites")
                                .set(Favorites);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Watchlist")
                                .set(Watchlist);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Country")
                                .set(Country);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Calendar")
                                .set(Calendar);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("FavDirectors")
                                .set(FavDirectors);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("FavActors")
                                .set(FavActors);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Rewatched")
                                .set(Rewatched);
                            FirebaseFirestore.instance
                                .collection(credential.user!.uid)
                                .doc("Settings")
                                .set(Settings);
                          });
                          try {
                            await FirebaseAuth.instance
                                .signInWithEmailAndPassword(
                                    email: email, password: password)
                                .then((_) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MyApp()),
                              );
                            });
                          } on FirebaseAuthException catch (e) {
                            if (e.code == 'user-not-found') {
                              print('No user found for that email.');
                            } else if (e.code == 'wrong-password') {
                              print('Wrong password provided for that user.');
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (e.code == 'user-not-found') {
                            print('No user found for that email.');
                          } else if (e.code == 'wrong-password') {
                            print('Wrong password provided for that user.');
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
    );
  }
}
