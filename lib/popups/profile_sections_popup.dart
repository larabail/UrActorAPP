import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firebaseutils.dart';
import 'package:uractor/common/widgets/app_dialog.dart';
import 'package:uractor/main.dart';

class ProfileSectionsDialogue extends StatefulWidget {
  final VoidCallback onDialogClosed;

  const ProfileSectionsDialogue({super.key, required this.onDialogClosed});

  @override
  State<ProfileSectionsDialogue> createState() =>
      _ProfileSectionsDialogueState();
}

class _ProfileSectionsDialogueState extends State<ProfileSectionsDialogue> {
  late List<MapEntry<dynamic, dynamic>> sectionsList;

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
    return AppDialog(
      title: "Modify Profile Sections",
      actions: [
        AppDialogAction(
          label: "Save",
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: () async {
            Map newSections = Map.fromEntries(sectionsList);
            await FirebaseUtils.updateProfileSections(newSections);
            widget.onDialogClosed();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ],
      child: ReorderableListView(
        // The dialogue used to be pinned to 450pt whatever the screen was,
        // which wasted 416 of them on a tall phone and clipped on a short one.
        // Shrink-wrapping lets the shell size itself to the sections there
        // actually are, and scroll only once there are more than fit.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Still onReorder; onReorderItem would pre-adjust newIndex and
        // make the compensation below wrong. Deferred out of this
        // upgrade along with the other two call sites.
        // ignore: deprecated_member_use
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
    );
  }
}
