// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/l10n/l10n.dart';
import '../main.dart';
import '../playlists.dart';

String cover = "";
String _listName = "";
String _accessCode = "";

final myController = TextEditingController(text: "");

class ListJoinDialogue extends StatefulWidget {
  const ListJoinDialogue({super.key});

  @override
  State<ListJoinDialogue> createState() => _ListJoinDialogueState();
}

class _ListJoinDialogueState extends State<ListJoinDialogue> {
  void joinList() async {
    bool joined = false;
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
            newUser[currentUser.uid] = "Approved";
            await userDoc.update({
              "Users": FieldValue.arrayUnion([newUser])
            });
            joined = true;
            if (!context.mounted) return;
            Navigator.pop(context);
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const Playlists()));
          }
        }
      }
      if (!joined) {
        debugPrint("WRONG ACCESS CODE OR LIST NAME");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context)!.joinListFailed)),
          );
        }
      }
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

  Widget contentBox(BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 5),
                  child: Text(
                    S.of(context)!.joinListTitle,
                    style: const TextStyle(
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
                        return S.of(context)!.enterListName;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: S.of(context)!.listName,
                    ),
                    onChanged: (value) {
                      _listName = value;
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: S.of(context)!.accessCodeLabel,
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
                          child: Row(
                            children: [
                              const Icon(Icons.cancel, color: Colors.red),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context)!.cancel,
                                style: const TextStyle(
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
                          child: Row(
                            children: [
                              const Icon(Icons.check, color: Colors.green),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context)!.add,
                                style: const TextStyle(
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
