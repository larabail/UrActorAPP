// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uractor/common/async_action.dart';
import 'package:uractor/l10n/l10n.dart';
import 'signup.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    currentUser.clearUser();
    currentUser.clearUserData();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final GlobalKey<_PasswordFieldState> passwordFieldKey =
        GlobalKey<_PasswordFieldState>();
    String email = "";

    Future<void> resetPassword(
        BuildContext context, String emailAddress) async {
      if (emailAddress == "") {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(S.of(context)!.needEmail),
              content: Text(S.of(context)!.typeEmail),
              actions: <Widget>[
                TextButton(
                  child: Text(S.of(context)!.okay),
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
          await FirebaseAuth.instance
              .sendPasswordResetEmail(email: emailAddress);
          if (!context.mounted) return;
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(S.of(context)!.password),
                content: Text(S.of(context)!.resetEmail),
                actions: <Widget>[
                  TextButton(
                    child: Text(S.of(context)!.okay),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );
        } catch (e) {
          if (!context.mounted) return;
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(S.of(context)!.password),
                content: Text(S.of(context)!.failedResetEmail(e.toString())),
                actions: <Widget>[
                  TextButton(
                    child: Text(S.of(context)!.okay),
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
      appBar: AppBar(),
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
                        decoration: InputDecoration(
                          labelText: S.of(context)!.email,
                          hintText: S.of(context)!.yourEmail,
                          hintStyle: const TextStyle(
                              color: Color.fromARGB(130, 255, 255, 255)),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(width: 1.0),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(width: 2.0),
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return S.of(context)!.enterEmail;
                          }
                          return null;
                        },
                        onChanged: (String? value) {
                          email = value!;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      PasswordField(key: passwordFieldKey),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        child: Text(S.of(context)!.login),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            final String password =
                                passwordFieldKey.currentState!.password;
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
                                    content:
                                        Text(S.of(context)!.wrongPasswordError),
                                  ),
                                );
                              }
                            } finally {
                              passwordFieldKey.currentState?.clear();
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16.0),
                      GestureDetector(
                        child: Text(
                          S.of(context)!.noAccountSignUp,
                        ),
                        onTap: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignUp()));
                        },
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        child: Text(
                          S.of(context)!.forgotPassword,
                        ),
                        onTap: () async {
                          await runVisibleAsyncAction(
                            context,
                            () => resetPassword(context, email),
                            S.of(context)!.genericAuthError,
                          );
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

class PasswordField extends StatefulWidget {
  const PasswordField({super.key});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;
  String _password = "";
  final TextEditingController _controller = TextEditingController();

  String get password => _password;

  /// Clears the stored plaintext password and the visible field contents.
  void clear() {
    _password = "";
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: S.of(context)!.password,
        hintText: S.of(context)!.yourPassword,
        hintStyle: const TextStyle(color: Color.fromARGB(130, 255, 255, 255)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(width: 1.0),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(width: 2.0),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return S.of(context)!.enterPassword;
        }
        return null;
      },
      onSaved: (String? value) {
        _password = value!;
      },
    );
  }
}
