// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/main.dart';
import 'package:uractor/playlists.dart';

String cover = "";
String _listName = "";
String _accessCode = "";

final myController = TextEditingController(text: "");

class ListJoinDialogue extends StatefulWidget {
  @override
  _ListJoinDialogueState createState() => _ListJoinDialogueState();
}

class _ListJoinDialogueState extends State<ListJoinDialogue> {
  void joinList() async {
    await FirebaseFirestore.instance
        .collection("Watchlists")
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        Map docData = doc.data() as Map;
        if (_listName == (docData["Name"])) {
          if (docData["AccessCode"] == _accessCode) {
            var userDoc =
                FirebaseFirestore.instance.collection("Watchlists").doc(doc.id);
            Map newUser = {};
            newUser[uid] = "Approved";
            await userDoc.update({
              "Users": FieldValue.arrayUnion([newUser])
            });
            Navigator.pop(context);
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => Playlists()));
          }
        }
      }
      print("WRONG ACCESS CODE OR LIST NAME");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contents of the Add List panel
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 40, 20, 5),
              child: Text(
                'Join List',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextFormField(
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'List Name',
                ),
                onChanged: (value) {
                  _listName = value;
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelStyle: TextStyle(color: Colors.white),
                  labelText: 'Access Code For Other People',
                ),
                onChanged: (value) {
                  _accessCode = value;
                },
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        joinList();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .green, // Change the background color of the button
                      ),
                      child: const Text('Add'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .red, // Change the background color of the button
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
