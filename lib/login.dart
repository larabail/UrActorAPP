// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'signup.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    uid = '';
    country = '';
    calendar = {};
    allMovies = [];
    favActors = [];
    favDirectors = [];
    favMovies = [];
    favTVShows = [];
    seenMovies = [];
    idsExplorePage = [];
    seenTVShows = [];
    watchlist = [];
    watchlistTVShows = [];
    movieResult = [];
    tvShowResult = [];
    reviews = {};
    rewatchedMovies = {};
    playlists = {};
    personResult = {};
    oscars = {};
    favsPage = [];
    favsPageTVShows = [];
    seenPage = [];
    seenPageTVShows = [];
    watchPageTVShows = [];
    watchPage = [];
    oscarsPage = [];
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    late String email, password;

    void resetPassword(String email) async {
      if (email == "") {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Email Address Needed'),
              content: const Text('Please type an email address'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Okay'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );
      } else {
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          // Show a confirmation message to the user
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Password'),
                content: const Text('Rest Password Email has been sent'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Okay'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );
        } catch (e) {
          // An error happened.
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Password'),
                content: Text("Failed to send password reset email: $e"),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Okay'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    }

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
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    child: const Text('Login'),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        try {
                          await FirebaseAuth.instance
                              .signInWithEmailAndPassword(
                                  email: email, password: password)
                              .then((_) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => MyApp()),
                            );
                          });
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
                  const SizedBox(height: 16.0),
                  GestureDetector(
                    child: const Text(
                      'Don\'t have an account? Sign up',
                    ),
                    onTap: () {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => SignUp()));
                    },
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    child: const Text(
                      'Forgot Password?',
                    ),
                    onTap: () {
                      resetPassword(email);
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
