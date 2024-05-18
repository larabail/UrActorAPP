import 'package:flutter/material.dart';
import 'package:uractor/common/utils.dart';
import 'package:uractor/main.dart';

class ProfileSectionsDialogue extends StatefulWidget {
  const ProfileSectionsDialogue({Key? key}) : super(key: key);

  @override
  _ProfileSectionsDialogueState createState() =>
      _ProfileSectionsDialogueState();
}

class _ProfileSectionsDialogueState extends State<ProfileSectionsDialogue> {
  late List<MapEntry<String, dynamic>> sectionsList;

  @override
  void initState() {
    super.initState();
    sectionsList = currentUser.settings["profileSections"].entries.toList();
    sectionsList.sort((a, b) => a.value["weight"].compareTo(b.value["weight"]));
  }

  void _updateWeights() {
    for (int i = 0; i < sectionsList.length; i++) {
      sectionsList[i].value["weight"] = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 0,
      child: Container(
        height: 450,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Modify Profile Sections",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ReorderableListView(
                onReorder: (int oldIndex, int newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  setState(() {
                    final item = sectionsList.removeAt(oldIndex);
                    sectionsList.insert(newIndex, item);
                    _updateWeights();
                  });
                },
                children: List.generate(sectionsList.length, (index) {
                  final section = sectionsList[index];
                  return ListTile(
                    key: ValueKey(section.key),
                    title: Text(
                      section.key == "MostSeenMovies"
                          ? "Most Seen Movies"
                          : section.key == "MostSeenTVShows"
                              ? "Most Seen TV Shows"
                              : section.key,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Switch(
                      value: section.value["show"],
                      onChanged: (bool value) {
                        setState(() {
                          section.value["show"] = value;
                        });
                      },
                    ),
                    leading: const Icon(Icons.drag_handle, color: Colors.white),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Map newSections =
                    Map.fromEntries(sectionsList);
                await FirebaseUtils.updateProfileSections(newSections);

                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
