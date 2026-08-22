// ignore_for_file: use_build_context_synchronously, constant_identifier_names, no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/api/tmdb_titles.dart';
import 'common/async_action.dart';
import 'common/firebase/friends_service.dart';
import 'common/firebase/progress_service.dart';
import 'common/navigation/appbar.dart';
import 'common/reorder_toggle.dart';
import 'common/watching_together.dart';
import 'common/widgets/scrolling_line.dart';
import 'friends_profile.dart';
import 'inbox.dart';
import 'main.dart';
import 'common/firebase/firestore_core.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

String friendUid = "";

/// The room the "Watching together" line under a friend's name is given.
///
/// Fixed, and the same whether the line scrolls or sits still, so that a row
/// does not change height when TMDB answers and shove the rest of the list
/// down under the reader's finger.
const double _kWatchingLineHeight = 18;

class Friends extends StatefulWidget {
  const Friends();

  @override
  State<Friends> createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  final TextEditingController _usernameController = TextEditingController();

  /// Reordering is a mode rather than always-on, because a long press to drag
  /// would otherwise fight with the tap that opens a friend's profile.
  bool _isReordering = false;

  late Future<List<FriendProfileSummary>> _profiles;

  /// Friend uid to the titles of the shows in progress with them.
  ///
  /// Loaded once for the whole page rather than per row. Several friends
  /// usually share the same show, and a lookup per row would ask TMDB for the
  /// same name once for each of them.
  late Future<Map<String, List<String>>> _watchingTogether;

  /// The friend list as plain strings.
  List<String> get _friendUids =>
      currentUser.friends.map((uid) => uid.toString()).toList();

  @override
  void initState() {
    super.initState();
    _profiles = FriendsService.loadProfiles(currentUser.friends);
    _watchingTogether = _loadWatchingTogether();
  }

  /// Crosses what is started and unfinished with who it was watched alongside,
  /// then names the result.
  ///
  /// Anything unreadable is treated as nothing shared. The friends list is
  /// about friends; a progress document that will not load should cost the
  /// subtitles, not the page.
  Future<Map<String, List<String>>> _loadWatchingTogether() async {
    final friends = _friendUids;
    if (friends.isEmpty) return const <String, List<String>>{};
    try {
      final shows = watchingTogetherShows(
        await ProgressService.inProgressItems(),
        currentUser.seenWith,
        friends: friends,
        limit: kWatchingTogetherLineLimit,
      );
      if (shows.isEmpty) return const <String, List<String>>{};

      final byFriend = watchingTogetherByFriend(shows);
      final titles = await TmdbTitles.forShows(shows.map((show) => show.id));
      final lines = <String, List<String>>{};
      for (final entry in byFriend.entries) {
        final line = watchingTogetherTitles(entry.value, titles);
        if (line.isNotEmpty) lines[entry.key] = line;
      }
      return lines;
    } catch (_) {
      return const <String, List<String>>{};
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final List<String> next =
        FriendsService.reorder(currentUser.friends, oldIndex, newIndex);
    setState(() {
      currentUser.friends = next;
      _profiles = FriendsService.loadProfiles(next);
    });
    await FriendsService.saveOrder(next);
  }

  Widget _buildFriendRequestsTile(BuildContext context) {
    return ListTile(
      leading: const Padding(
        padding: EdgeInsets.only(left: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail),
          ],
        ),
      ),
      title: Text(S.of(context)!.friendRequests),
      subtitle: Text(S.of(context)!.viewRequests),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FriendRequestsPage(currentUserUID: currentUser.uid),
          ),
        );
      },
    );
  }

  Widget _buildReorderToggle(BuildContext context) {
    return ReorderToggle(
      isReordering: _isReordering,
      onPressed: () => setState(() => _isReordering = !_isReordering),
      enterTooltip: S.of(context)!.reorderFriends,
      exitTooltip: S.of(context)!.finishReordering,
    );
  }

  Widget _buildFriendRow(
    BuildContext context,
    FriendProfileSummary friend,
    int index,
    List<String> watchingTogether,
  ) {
    final avatar = ClipOval(
      child: friend.profilePhoto != ""
          ? Image.network(
              friend.profilePhoto,
              height: 50,
              width: 50,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/main_profile.png',
              height: 50,
              width: 50,
              fit: BoxFit.cover,
            ),
    );

    return GestureDetector(
      key: ValueKey(friend.uid),
      onTap: _isReordering
          ? null
          : () {
              friendUid = friend.uid;
              openDetail(context, FriendProfile(friendUid: friendUid));
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        margin: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friend.userName,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  // A friend with nothing running gets no line at all, rather
                  // than an empty one holding a gap open under their name.
                  if (watchingTogether.isNotEmpty)
                    ScrollingLine(
                      key: ValueKey('watchingTogether-${friend.uid}'),
                      text: S.of(context)!.watchingTogetherTitles(
                            watchingTogether.join(' • '),
                          ),
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey,
                      ),
                      height: _kWatchingLineHeight,
                    ),
                ],
              ),
            ),
            if (_isReordering)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context) {
    return FutureBuilder<List<FriendProfileSummary>>(
      future: _profiles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<FriendProfileSummary> friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(child: Text(S.of(context)!.noFriendsYet)),
              ),
            ],
          );
        }
        // The friends are drawn as soon as they are known and the lines appear
        // underneath when TMDB answers. Waiting for the titles before drawing
        // anything would hold the whole list behind a network call for a
        // subtitle.
        return FutureBuilder<Map<String, List<String>>>(
          future: _watchingTogether,
          builder: (context, watchingSnapshot) {
            final watching =
                watchingSnapshot.data ?? const <String, List<String>>{};
            List<String> linesFor(FriendProfileSummary friend) =>
                watching[friend.uid] ?? const <String>[];

            if (_isReordering) {
              return ReorderableListView.builder(
                itemCount: friends.length,
                // Deliberately still onReorder. onReorderItem pre-adjusts
                // newIndex, so migrating means removing the compensation inside
                // FriendsService.reorder and rewriting the tests that pin it.
                // That changes drag behaviour, which nothing here covers at the
                // widget level, so it belongs in its own change rather than in
                // a toolchain upgrade.
                // ignore: deprecated_member_use
                onReorder: _onReorder,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) => _buildFriendRow(
                  context,
                  friends[index],
                  index,
                  linesFor(friends[index]),
                ),
              );
            }
            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) => _buildFriendRow(
                context,
                friends[index],
                index,
                linesFor(friends[index]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshFriends() async {
    var friendsDoc =
        await FirestoreCore.db.collection(currentUser.uid).doc("Friends").get();
    Map<String, dynamic> data = friendsDoc.data() as Map<String, dynamic>;
    currentUser.friends = data["friends"];
    FriendsService.clearCache();
    setState(() {
      currentUser.friends = currentUser.friends;
      _profiles = FriendsService.loadProfiles(currentUser.friends);
      // Refreshed alongside the friends, so that a friend who has just been
      // removed takes their line with them and one newly added gets theirs.
      // Titles stay cached, so this costs a progress read rather than a
      // request per show.
      _watchingTogether = _loadWatchingTogether();
    });
  }

  @override
  Widget build(BuildContext context) {
    friendUid = "";

    Future<void> sendFriendRequest(String recipientUID) async {
      await FirestoreCore.db
          .collection(recipientUID)
          .doc('Friends')
          .collection('FriendRequests')
          .doc(currentUser.uid)
          .set({
        'senderUID': currentUser.uid,
        'status': 'pending',
      });
    }

    void addFriend() {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text(
                S.of(context)!.addFriend,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: S.of(context)!.username,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      String inputUsername = _usernameController.text.trim();
                      if (inputUsername.isNotEmpty) {
                        QuerySnapshot query = await FirestoreCore.db
                            .collection('usernames')
                            .where('username', isEqualTo: inputUsername)
                            .get();

                        if (query.docs.isNotEmpty) {
                          String friendUid = query.docs[0].get("uid");

                          final sent = await runVisibleAsyncAction(
                            context,
                            () => sendFriendRequest(friendUid),
                            S.of(context)!.friendRequestActionFailedError,
                          );
                          if (!sent || !context.mounted) return;
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(S.of(context)!.noSuchUser),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    S.of(context)!.cancel,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          });
    }

    return AppScaffold(
      detailPlaceholder: DetailPanePlaceholder(
        message: S.of(context)!.detailPanePlaceholder,
      ),
      appBar: CustomAppBar(
        actions: [
          if (currentUser.friends.length > 1) ...[
            _buildReorderToggle(context),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildFriendRequestsTile(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFriends,
              child: _buildFriendsList(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addFriend,
        backgroundColor: Colors.grey[900],
        child: const Icon(
          Icons.add,
          color: Colors.green,
          size: 30,
        ),
      ),
      selectedIndex: 2,
    );
  }
}
