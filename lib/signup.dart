// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/l10n/l10n.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';

/// Writes the eighteen documents that make up a brand-new user's profile in
/// a single atomic [WriteBatch]. A batch is all-or-nothing: either every
/// document is created, or (if the commit throws) none of them are, so an
/// account can no longer end up half set up the way it could when each
/// document was written with its own unawaited `.set()` call.
///
/// The document names and initial values must stay exactly as they are.
/// `Friends` in particular must keep its `{"friends": []}` shape, because
/// `AppUser` reads `f["friends"]` and calls `.add()` on the result -- an
/// empty map there would leave that null and crash at runtime.
///
/// Not private (despite only being called from within this file) so tests
/// can exercise it directly against a `FakeFirebaseFirestore` installed
/// through `FirestoreCore.db`.
@visibleForTesting
Future<void> writeInitialProfile(String uid) async {
  final firestore = FirestoreCore.db;
  final users = firestore.collection(uid);
  final batch = firestore.batch();

  batch.set(users.doc("Movies"), const <String, dynamic>{"Seen": []});
  batch.set(users.doc("TVShows"), const <String, dynamic>{"Seen": []});
  batch.set(
      users.doc("Seen"), const <String, dynamic>{"Movies": [], "TVShows": []});
  batch.set(users.doc("SeenWith"),
      const <String, dynamic>{"Movies": {}, "TVShows": {}});
  batch.set(users.doc("Reviews"),
      const <String, dynamic>{"Movies": [], "TVShows": []});
  batch.set(users.doc("Favorites"),
      const <String, dynamic>{"Movies": [], "TVShows": []});
  batch.set(users.doc("Watchlist"),
      const <String, dynamic>{"Movies": [], "TVShows": []});
  batch.set(users.doc("Country"), const <String, dynamic>{"Country": "US"});
  batch.set(users.doc("Calendar"), const <String, dynamic>{});
  batch.set(users.doc("FavDirectors"), const <String, dynamic>{});
  batch.set(users.doc("FavWriters"), const <String, dynamic>{});
  batch.set(users.doc("FavActors"), const <String, dynamic>{});
  batch.set(users.doc("Rewatched"), const <String, dynamic>{});
  batch.set(users.doc("RewatchedTV"), const <String, dynamic>{});
  batch.set(users.doc("Settings"), const <String, dynamic>{
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
  });
  batch.set(users.doc("Friends"), const <String, dynamic>{"friends": []});
  batch.set(users.doc("Notifications"), const <String, dynamic>{});
  batch.set(users.doc("Recommendations"),
      const <String, dynamic>{"Movies": [], "TVShows": []});

  await batch.commit();
}

@visibleForTesting
enum CreatedAuthAccountRollbackResult { deleted, failed, unavailable }

/// Deletes the Firebase Auth account that was just created when the profile
/// batch fails, so a retry can reuse the same email address.
@visibleForTesting
Future<CreatedAuthAccountRollbackResult>
    rollbackCreatedAuthAccountAfterProfileFailure({
  required Future<void> Function()? deleteAccount,
  required Object profileError,
  StackTrace? profileStackTrace,
  void Function(FlutterErrorDetails details) reportError =
      FlutterError.reportError,
}) async {
  if (deleteAccount == null) {
    reportError(
      FlutterErrorDetails(
        exception: profileError,
        stack: profileStackTrace,
        context: ErrorDescription('while writing profile for a new signup'),
        informationCollector: () sync* {
          yield ErrorDescription(
            'The auth user was unavailable, so account rollback could not run.',
          );
        },
      ),
    );
    return CreatedAuthAccountRollbackResult.unavailable;
  }

  try {
    await deleteAccount();
    return CreatedAuthAccountRollbackResult.deleted;
  } catch (rollbackError, rollbackStackTrace) {
    reportError(
      FlutterErrorDetails(
        exception: profileError,
        stack: profileStackTrace,
        context: ErrorDescription('while writing profile for a new signup'),
        informationCollector: () sync* {
          yield ErrorDescription(
            'Deleting the just-created auth account also failed.',
          );
          yield DiagnosticsProperty<Object>('rollback error', rollbackError);
        },
      ),
    );
    reportError(
      FlutterErrorDetails(
        exception: rollbackError,
        stack: rollbackStackTrace,
        context: ErrorDescription(
          'while deleting a just-created auth account after profile setup failed',
        ),
      ),
    );
    return CreatedAuthAccountRollbackResult.failed;
  }
}

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
            // The form's column stretches its children, so without a ceiling
            // every field is as wide as the window -- across a desktop monitor
            // an email box the width of the screen reads as a mistake.
            child: ReadableWidth(
              maxWidth: kMaxFormWidth,
              alignment: Alignment.center,
              child: AutofillGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username
                        ],
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Your Email',
                          hintStyle: TextStyle(
                              color: Color.fromARGB(130, 255, 255, 255)),
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
                          hintStyle: TextStyle(
                              color: Color.fromARGB(130, 255, 255, 255)),
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
                          hintStyle: TextStyle(
                              color: Color.fromARGB(130, 255, 255, 255)),
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
                              final credential = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                      email: email, password: password);

                              try {
                                await writeInitialProfile(credential.user!.uid);
                              } catch (e, stackTrace) {
                                final rollbackResult =
                                    await rollbackCreatedAuthAccountAfterProfileFailure(
                                  deleteAccount: credential.user == null
                                      ? null
                                      : () => credential.user!.delete(),
                                  profileError: e,
                                  profileStackTrace: stackTrace,
                                );
                                if (!context.mounted) return;
                                final errorMessage = rollbackResult ==
                                        CreatedAuthAccountRollbackResult.deleted
                                    ? S.of(context)!.profileSetupFailedError
                                    : S
                                        .of(context)!
                                        .profileSetupRollbackFailedError;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage)),
                                );
                                return;
                              }

                              try {
                                await FirebaseAuth.instance
                                    .signInWithEmailAndPassword(
                                        email: email, password: password);
                                if (!context.mounted) return;
                                TextInput.finishAutofillContext();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const MyApp()),
                                );
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
                                    content:
                                        Text(S.of(context)!.weakPasswordError),
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
                                    content:
                                        Text(S.of(context)!.invalidEmailError),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(S.of(context)!.genericAuthError),
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
      ),
    );
  }
}
