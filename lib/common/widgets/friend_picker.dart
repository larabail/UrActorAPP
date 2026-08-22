/// The friend list five popups each grew their own copy of.
///
/// All five did the same thing -- read every friend's `Settings` document,
/// paint an avatar and a username, tick a box -- and four of them wrapped it
/// in `SizedBox(height: 125)`. A `CheckboxListTile` is 56pt tall, so that
/// window showed 2.23 friends at a time inside a dialogue with 604pt to
/// spare, and the user scrolled a list that would have fitted six times over
/// in the room already on screen.
///
/// This takes the room it is given instead. It shrink-wraps and defers
/// scrolling to whatever is above it, so a dialogue has one scroll area rather
/// than a small one nested inside a large one where dragging the inner list
/// does not move the outer.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/firestore_core.dart';

class FriendPicker extends StatefulWidget {
  const FriendPicker({
    super.key,
    required this.friendIds,
    required this.selected,
    required this.onChanged,
  });

  /// The friends to offer, in the order they should appear.
  final List<String> friendIds;

  /// Which of them are ticked. Absent means unticked.
  final Map<String, bool> selected;

  final void Function(String friendId, bool selected) onChanged;

  @override
  State<FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<FriendPicker> {
  /// One read per friend for the life of the picker.
  ///
  /// The copies this replaces built the future inside `build`, so ticking one
  /// box re-fetched every row and flashed a spinner over the whole list. A
  /// dialogue is open for seconds, so there is nothing to gain from noticing
  /// that a friend renamed themselves while it was.
  final Map<String, Future<DocumentSnapshot>> _profiles = {};

  Future<DocumentSnapshot> _profileOf(String friendId) => _profiles.putIfAbsent(
        friendId,
        () => FirestoreCore.db.collection(friendId).doc('Settings').get(),
      );

  @override
  void didUpdateWidget(FriendPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Someone removed from the list should not keep a pending read alive.
    _profiles.removeWhere((id, _) => !widget.friendIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      // The dialogue scrolls; this does not scroll inside it.
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.friendIds.length,
      itemBuilder: (context, index) {
        final friendId = widget.friendIds[index];
        return FutureBuilder<DocumentSnapshot>(
          future: _profileOf(friendId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('No data found');
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final userName = data['username'] ?? '';
            final profilePath = data['profile_photo'] ?? '';
            return CheckboxListTile(
              title: Row(
                children: [
                  ClipOval(
                    child: profilePath != ""
                        ? Image.network(
                            profilePath,
                            height: 25,
                            width: 25,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            'assets/main_profile.png',
                            height: 25,
                            width: 25,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              value: widget.selected[friendId] ?? false,
              onChanged: (value) => widget.onChanged(friendId, value ?? false),
            );
          },
        );
      },
    );
  }
}
