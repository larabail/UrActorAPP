// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'playlists.dart';

String cover = "";
String _listName = "";
String _accessCode = "";

final myController = TextEditingController(text: "");

class ListJoinDialogue extends StatefulWidget {
  const ListJoinDialogue({super.key});

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
                context, MaterialPageRoute(builder: (context) => const Playlists()));
          }
        }
      }
      print("WRONG ACCESS CODE OR LIST NAME");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Add rounded corners
      ),
      elevation: 0,
      child: contentBox(context),
    );
  }

  contentBox(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          padding:
              const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Contents of the Add List panel
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 40, 20, 5),
                  child: Text(
                    'Join List',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                    decoration: const InputDecoration(
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
                    decoration: const InputDecoration(
                      labelText: 'Access Code',
                    ),
                    onChanged: (value) {
                      _accessCode = value;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          joinList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, color: Colors.green),
                              SizedBox(width: 10),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
